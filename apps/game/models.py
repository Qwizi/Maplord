import uuid
from django.conf import settings
from django.db import models


class GameStateSnapshot(models.Model):
    """Periodic snapshots of game state from Redis → PostgreSQL for history/replay."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    match = models.ForeignKey('matchmaking.Match', on_delete=models.CASCADE, related_name='snapshots')
    tick = models.PositiveIntegerField()
    state_data = models.JSONField(help_text='Full game state snapshot (regions, players, buildings)')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['match', 'tick']
        unique_together = ('match', 'tick')

    def __str__(self):
        return f"Snapshot {self.match_id} tick {self.tick}"


class MatchResult(models.Model):
    """Post-match statistics and results."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    match = models.OneToOneField('matchmaking.Match', on_delete=models.CASCADE, related_name='result')
    duration_seconds = models.PositiveIntegerField(default=0)
    total_ticks = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['-match__created_at']

    def __str__(self):
        return f"Result for {self.match_id}"


class PlayerResult(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    match_result = models.ForeignKey(MatchResult, on_delete=models.CASCADE, related_name='player_results')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='game_results')
    placement = models.PositiveIntegerField(default=0, help_text='1=winner, 2=second, etc.')
    regions_conquered = models.PositiveIntegerField(default=0)
    units_produced = models.PositiveIntegerField(default=0)
    units_lost = models.PositiveIntegerField(default=0)
    buildings_built = models.PositiveIntegerField(default=0)
    elo_change = models.IntegerField(default=0)

    class Meta:
        ordering = ['placement']
        unique_together = ('match_result', 'user')

    def __str__(self):
        return f"{self.user.username} - #{self.placement} in {self.match_result.match_id}"
