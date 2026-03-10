from ninja_extra import api_controller, route
from ninja_extra.permissions import IsAuthenticated
from ninja_jwt.authentication import JWTAuth
from django.shortcuts import get_object_or_404

from apps.game.models import MatchResult
from apps.game.schemas import MatchResultOutSchema


@api_controller('/game', tags=['Game'])
class GameController:

    @route.get('/results/{match_id}/', response=MatchResultOutSchema, auth=JWTAuth(), permissions=[IsAuthenticated])
    def get_result(self, request, match_id: str):
        return get_object_or_404(
            MatchResult.objects.prefetch_related('player_results'),
            match_id=match_id,
        )
