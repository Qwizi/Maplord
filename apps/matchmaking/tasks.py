import logging
from celery import shared_task
from django.utils import timezone
from datetime import timedelta

logger = logging.getLogger(__name__)


@shared_task
def cleanup_stale_lobbies():
    """Cancel lobbies that have been waiting/full for too long.

    - waiting lobbies older than 10 minutes → cancelled
    - full lobbies older than 5 minutes (ready timeout expired) → cancelled
    - empty lobbies (no players) → cancelled
    """
    from apps.matchmaking.models import Lobby, LobbyPlayer

    now = timezone.now()
    count = 0

    # Waiting lobbies older than 10 minutes
    stale_waiting = Lobby.objects.filter(
        status=Lobby.Status.WAITING,
        created_at__lt=now - timedelta(minutes=10),
    )
    count += stale_waiting.update(status=Lobby.Status.CANCELLED)

    # Full/ready lobbies older than 5 minutes (nobody clicked ready in time)
    stale_full = Lobby.objects.filter(
        status__in=[Lobby.Status.FULL, Lobby.Status.READY],
        created_at__lt=now - timedelta(minutes=5),
    )
    count += stale_full.update(status=Lobby.Status.CANCELLED)

    # Lobbies with no players left
    from django.db.models import Count
    empty_lobbies = (
        Lobby.objects
        .filter(status__in=[Lobby.Status.WAITING, Lobby.Status.FULL, Lobby.Status.READY])
        .annotate(player_count=Count('players'))
        .filter(player_count=0)
    )
    count += empty_lobbies.update(status=Lobby.Status.CANCELLED)

    if count > 0:
        logger.info(f"Cleaned up {count} stale lobbies")

    return count
