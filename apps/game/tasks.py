import logging

import redis
from celery import shared_task
from django.conf import settings

logger = logging.getLogger(__name__)


@shared_task
def save_game_snapshot(match_id: str, tick: int, state_data: dict):
    """Save a periodic game state snapshot to PostgreSQL."""
    from apps.game.models import GameStateSnapshot

    GameStateSnapshot.objects.update_or_create(
        match_id=match_id,
        tick=tick,
        defaults={"state_data": state_data},
    )
    logger.info("Snapshot saved for match %s at tick %d", match_id, tick)


@shared_task
def finalize_match_results(
    match_id: str,
    winner_id: str | None,
    total_ticks: int,
    final_state: dict,
):
    """Persist match results, player stats, and final state snapshot to PostgreSQL."""
    from django.utils import timezone

    from apps.game.models import GameStateSnapshot, MatchResult, PlayerResult
    from apps.matchmaking.models import Match

    match = Match.objects.get(id=match_id)
    match.status = Match.Status.FINISHED
    match.finished_at = timezone.now()
    if winner_id:
        match.winner_id = winner_id
    match.save()

    # Save final state snapshot
    GameStateSnapshot.objects.update_or_create(
        match=match,
        tick=total_ticks,
        defaults={"state_data": final_state},
    )

    duration = 0
    if match.started_at:
        duration = int((match.finished_at - match.started_at).total_seconds())

    result = MatchResult.objects.create(
        match=match,
        duration_seconds=duration,
        total_ticks=total_ticks,
    )

    # Compute player stats from final game state
    regions = final_state.get("regions", {})
    players_data = final_state.get("players", {})

    for mp in match.players.select_related("user").all():
        pid = str(mp.user_id)
        player_info = players_data.get(pid, {})

        owned_regions = sum(
            1 for r in regions.values() if r.get("owner_id") == pid
        )
        total_units = sum(
            r.get("unit_count", 0)
            for r in regions.values()
            if r.get("owner_id") == pid
        )
        buildings_count = sum(
            1
            for r in regions.values()
            if r.get("owner_id") == pid and r.get("building_type")
        )

        placement = 1 if pid == winner_id else 2
        is_alive = player_info.get("is_alive", False)
        if not is_alive and pid != winner_id:
            placement = 0  # eliminated

        PlayerResult.objects.create(
            match_result=result,
            user=mp.user,
            placement=placement,
            regions_conquered=owned_regions,
            units_produced=total_units,
            buildings_built=buildings_count,
        )

    logger.info(
        "Match %s finalized: winner=%s, ticks=%d, duration=%ds",
        match_id,
        winner_id,
        total_ticks,
        duration,
    )


@shared_task
def cleanup_redis_game_state(match_id: str):
    """Remove all Redis keys for a finished match."""
    r = redis.Redis(
        host=settings.REDIS_HOST,
        port=settings.REDIS_PORT,
        db=settings.REDIS_GAME_DB,
    )
    keys = [
        f"game:{match_id}:meta",
        f"game:{match_id}:players",
        f"game:{match_id}:regions",
        f"game:{match_id}:actions",
        f"game:{match_id}:buildings_queue",
        f"game:{match_id}:loop_lock",
    ]
    deleted = r.delete(*keys)
    r.close()
    logger.info("Cleaned up %d Redis keys for match %s", deleted, match_id)


@shared_task
def cleanup_stale_matches():
    """Cancel matches stuck in non-terminal states for over 2 hours."""
    from datetime import timedelta

    from django.utils import timezone

    from apps.matchmaking.models import Match

    stale_cutoff = timezone.now() - timedelta(hours=2)
    stale_matches = Match.objects.filter(
        status__in=[Match.Status.SELECTING, Match.Status.IN_PROGRESS],
        started_at__lt=stale_cutoff,
    )

    count = 0
    for match in stale_matches:
        match.status = Match.Status.CANCELLED
        match.finished_at = timezone.now()
        match.save()
        cleanup_redis_game_state.delay(str(match.id))
        count += 1

    if count:
        logger.info("Cleaned up %d stale matches", count)


@shared_task
def cleanup_stale_queue_entries():
    """Remove matchmaking queue entries older than 30 minutes."""
    from datetime import timedelta

    from django.utils import timezone

    from apps.matchmaking.models import MatchQueue

    cutoff = timezone.now() - timedelta(minutes=30)
    deleted, _ = MatchQueue.objects.filter(joined_at__lt=cutoff).delete()
    if deleted:
        logger.info("Cleaned up %d stale queue entries", deleted)
