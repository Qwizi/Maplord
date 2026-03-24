import logging
from datetime import timedelta
from decimal import Decimal, ROUND_HALF_UP
from math import isclose

from celery import shared_task
from django.db import transaction
from django.db.models import Q
from django.utils import timezone

logger = logging.getLogger(__name__)

CLAN_WAR_XP_WIN = 500
CLAN_WAR_XP_LOSS = 100


def _round_elo_delta(value: float) -> int:
    if isclose(value, 0.0, abs_tol=1e-9):
        return 0
    rounded = int(Decimal(str(value)).quantize(Decimal("1"), rounding=ROUND_HALF_UP))
    if rounded == 0:
        return 1 if value > 0 else -1
    return rounded


@shared_task
def expire_clan_invitations():
    """Mark expired pending invitations."""
    from apps.clans.models import ClanInvitation

    expired = ClanInvitation.objects.filter(
        status=ClanInvitation.Status.PENDING,
        expires_at__lt=timezone.now(),
    ).update(status=ClanInvitation.Status.EXPIRED)

    if expired:
        logger.info('Expired %d clan invitations', expired)


@shared_task
def expire_pending_wars(hours: int = 24):
    """Cancel wars pending acceptance for too long and refund wagers to challengers."""
    from apps.clans.models import Clan, ClanWar

    cutoff = timezone.now() - timedelta(hours=hours)
    stale_wars = ClanWar.objects.filter(
        status=ClanWar.Status.PENDING,
        created_at__lt=cutoff,
        wager_gold__gt=0,
    ).select_related('challenger')

    refund_count = 0
    with transaction.atomic():
        for war in stale_wars:
            locked = Clan.objects.select_for_update().get(pk=war.challenger_id)
            locked.treasury_gold += war.wager_gold
            locked.save(update_fields=['treasury_gold'])
            refund_count += 1

    # Cancel all stale wars (including zero-wager ones)
    cancelled = ClanWar.objects.filter(
        status=ClanWar.Status.PENDING,
        created_at__lt=cutoff,
    ).update(status=ClanWar.Status.CANCELLED)

    if cancelled:
        logger.info('Cancelled %d pending clan wars (%d wagers refunded)', cancelled, refund_count)


@shared_task
def start_clan_war(war_id: str):
    """Create a Lobby for an accepted clan war and notify the Rust gateway.

    Steps:
    1. Verify the war is still in accepted status.
    2. Look up the 'clan-war' GameMode.
    3. Create a Lobby with max_players = players_per_side * 2.
    4. Add all ClanWarParticipants as LobbyPlayer entries.
    5. Mark the war as IN_PROGRESS and set started_at.
    6. Publish a lobby:events message so the gateway can wire up connections.
    """
    from apps.clans.models import Clan, ClanWar, ClanWarParticipant
    from apps.matchmaking.models import Lobby, LobbyPlayer
    from apps.matchmaking.events import publish_lobby_event
    from apps.game_config.models import GameMode

    try:
        war = ClanWar.objects.select_related('challenger', 'defender').get(pk=war_id)
    except ClanWar.DoesNotExist:
        logger.error('start_clan_war: ClanWar %s not found', war_id)
        return

    if war.status != ClanWar.Status.ACCEPTED:
        logger.warning(
            'start_clan_war: war %s has status %s, expected accepted — skipping',
            war_id, war.status,
        )
        return

    game_mode = GameMode.objects.filter(slug='clan-war', is_active=True).first()
    if not game_mode:
        logger.error('start_clan_war: GameMode clan-war not found or inactive')
        return

    participants = list(
        ClanWarParticipant.objects.select_related('user').filter(war_id=war_id)
    )
    if not participants:
        logger.warning('start_clan_war: war %s has no participants yet', war_id)
        return

    # Use challenger leader as lobby host
    host = war.challenger.leader
    max_players = war.players_per_side * 2

    with transaction.atomic():
        lobby = Lobby.objects.create(
            game_mode=game_mode,
            host_user=host,
            status=Lobby.Status.WAITING,
            max_players=max_players,
        )

        for p in participants:
            LobbyPlayer.objects.get_or_create(
                lobby=lobby,
                user=p.user,
                defaults={'is_ready': True, 'is_bot': False},
            )

        now = timezone.now()
        war.status = ClanWar.Status.IN_PROGRESS
        war.started_at = now
        war.save(update_fields=['status', 'started_at'])

    participant_ids = [str(p.user_id) for p in participants]
    publish_lobby_event(
        'clan_war_started',
        str(lobby.pk),
        war_id=war_id,
        game_mode='clan-war',
        max_players=max_players,
        participant_user_ids=participant_ids,
        challenger_id=str(war.challenger_id),
        defender_id=str(war.defender_id),
    )

    logger.info(
        'start_clan_war: war %s started, lobby %s created with %d participants',
        war_id, lobby.pk, len(participants),
    )


@shared_task
def award_clan_xp(user_id: str, xp_amount: int):
    """Award XP to a player's clan after a match."""
    from apps.clans.models import Clan, ClanActivityLog, ClanLevel, ClanMembership

    try:
        membership = ClanMembership.objects.select_related('clan').get(user_id=user_id)
    except ClanMembership.DoesNotExist:
        return

    with transaction.atomic():
        clan = Clan.objects.select_for_update().get(pk=membership.clan_id)
        clan.experience += xp_amount
        clan.save(update_fields=['experience'])

        # Check level up
        next_level = ClanLevel.objects.filter(
            level=clan.level + 1,
            experience_required__lte=clan.experience,
        ).first()

        if next_level:
            clan.level = next_level.level
            clan.max_members = next_level.max_members
            clan.save(update_fields=['level', 'max_members'])

            ClanActivityLog.objects.create(
                clan=clan, actor=None,
                action=ClanActivityLog.Action.CLAN_LEVELED_UP,
                detail={'new_level': next_level.level},
            )
            logger.info('Clan [%s] leveled up to %d', clan.tag, next_level.level)


@shared_task
def calculate_clan_war_elo(war_id: str):
    """Calculate ELO changes for a finished clan war."""
    from apps.clans.models import Clan, ClanActivityLog, ClanWar

    try:
        war = ClanWar.objects.select_related('challenger', 'defender').get(pk=war_id)
    except ClanWar.DoesNotExist:
        logger.error('ClanWar %s not found', war_id)
        return

    if war.status != ClanWar.Status.FINISHED or not war.winner_id:
        return

    k_factor = 32
    challenger = war.challenger
    defender = war.defender

    # Standard ELO calculation
    expected_c = 1.0 / (1.0 + 10 ** ((defender.elo_rating - challenger.elo_rating) / 400.0))
    expected_d = 1.0 - expected_c

    actual_c = 1.0 if war.winner_id == challenger.pk else 0.0
    actual_d = 1.0 - actual_c

    raw_c = k_factor * (actual_c - expected_c)
    raw_d = k_factor * (actual_d - expected_d)

    change_c = _round_elo_delta(raw_c)
    change_d = -change_c  # Zero-sum

    winner_is_challenger = war.winner_id == challenger.pk
    winner_tag = challenger.tag if winner_is_challenger else defender.tag
    loser_tag = defender.tag if winner_is_challenger else challenger.tag

    with transaction.atomic():
        war.challenger_elo_change = change_c
        war.defender_elo_change = change_d
        war.save(update_fields=['challenger_elo_change', 'defender_elo_change'])

        Clan.objects.filter(pk=challenger.pk).update(
            elo_rating=challenger.elo_rating + change_c,
        )
        Clan.objects.filter(pk=defender.pk).update(
            elo_rating=defender.elo_rating + change_d,
        )

        # Wager transfer:
        # Both sides' wagers were already deducted from treasuries at declaration/acceptance.
        # Winner receives both wagers: challenger_wager + defender_wager = wager_gold * 2.
        if war.wager_gold > 0:
            total_prize = war.wager_gold * 2
            winner_clan = Clan.objects.select_for_update().get(pk=war.winner_id)
            winner_clan.treasury_gold += total_prize
            winner_clan.save(update_fields=['treasury_gold'])
            logger.info(
                'Clan war %s: transferred %d gold to winner [%s]',
                war_id, total_prize, winner_tag,
            )

        # Activity logs
        ClanActivityLog.objects.create(
            clan=war.challenger, actor=None,
            action=(ClanActivityLog.Action.WAR_WON if winner_is_challenger
                    else ClanActivityLog.Action.WAR_LOST),
            detail={
                'against': defender.tag,
                'elo_change': change_c,
                'wager_gold': war.wager_gold,
            },
        )
        ClanActivityLog.objects.create(
            clan=war.defender, actor=None,
            action=(ClanActivityLog.Action.WAR_WON if not winner_is_challenger
                    else ClanActivityLog.Action.WAR_LOST),
            detail={
                'against': challenger.tag,
                'elo_change': change_d,
                'wager_gold': war.wager_gold,
            },
        )

    # Award XP to all participants — winning side gets more
    from apps.clans.models import ClanWarParticipant
    participants = ClanWarParticipant.objects.select_related('user').filter(war_id=war_id)
    for p in participants:
        xp = CLAN_WAR_XP_WIN if str(p.clan_id) == str(war.winner_id) else CLAN_WAR_XP_LOSS
        award_clan_xp.delay(str(p.user_id), xp)

    logger.info(
        'Clan war %s: [%s] vs [%s] — winner [%s], ELO: %+d / %+d',
        war_id, challenger.tag, defender.tag, winner_tag, change_c, change_d,
    )
