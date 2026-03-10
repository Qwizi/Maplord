from typing import List
from ninja_extra import api_controller, route
from ninja_extra.permissions import IsAuthenticated
from ninja_jwt.authentication import JWTAuth

from apps.matchmaking.models import Match
from apps.matchmaking.schemas import MatchOutSchema


@api_controller('/matches', tags=['Matches'])
class MatchController:

    @route.get('/', response=List[MatchOutSchema], auth=JWTAuth(), permissions=[IsAuthenticated])
    def list_my_matches(self, request):
        """List matches for the authenticated user."""
        return list(
            Match.objects.filter(players__user=request.auth)
            .prefetch_related('players')
            .distinct()
        )

    @route.get('/{match_id}/', response=MatchOutSchema, auth=JWTAuth(), permissions=[IsAuthenticated])
    def get_match(self, request, match_id: str):
        return Match.objects.prefetch_related('players').get(id=match_id)
