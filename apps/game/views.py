from typing import List

from ninja_extra import api_controller, route
from ninja_extra.permissions import IsAuthenticated
from ninja_jwt.authentication import JWTAuth
from django.shortcuts import get_object_or_404

from apps.game.models import GameStateSnapshot, MatchResult
from apps.game.schemas import MatchResultOutSchema, SnapshotDetailSchema, SnapshotTickSchema


@api_controller('/game', tags=['Game'])
class GameController:

    @route.get('/results/{match_id}/', response=MatchResultOutSchema, auth=JWTAuth(), permissions=[IsAuthenticated])
    def get_result(self, request, match_id: str):
        return get_object_or_404(
            MatchResult.objects.prefetch_related('player_results', 'player_results__user'),
            match_id=match_id,
        )

    @route.get('/snapshots/{match_id}/', response=List[SnapshotTickSchema], auth=JWTAuth(), permissions=[IsAuthenticated])
    def list_snapshots(self, request, match_id: str):
        """List available snapshot ticks for a match (for replay timeline)."""
        return list(
            GameStateSnapshot.objects.filter(match_id=match_id)
            .order_by('tick')
            .values('tick', 'created_at')
        )

    @route.get('/snapshots/{match_id}/{tick}/', response=SnapshotDetailSchema, auth=JWTAuth(), permissions=[IsAuthenticated])
    def get_snapshot(self, request, match_id: str, tick: int):
        """Get a single snapshot with full state data."""
        return get_object_or_404(GameStateSnapshot, match_id=match_id, tick=tick)
