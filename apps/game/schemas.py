import uuid
from typing import List
from datetime import datetime
from ninja import Schema


class PlayerResultOutSchema(Schema):
    user_id: uuid.UUID
    placement: int
    regions_conquered: int
    units_produced: int
    units_lost: int
    buildings_built: int
    elo_change: int

    class Config:
        from_attributes = True


class MatchResultOutSchema(Schema):
    id: uuid.UUID
    match_id: uuid.UUID
    duration_seconds: int
    total_ticks: int
    player_results: List[PlayerResultOutSchema] = []

    class Config:
        from_attributes = True
