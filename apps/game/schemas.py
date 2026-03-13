import uuid
from typing import List
from datetime import datetime
from ninja import Schema


class PlayerResultOutSchema(Schema):
    user_id: uuid.UUID
    username: str
    placement: int
    regions_conquered: int
    units_produced: int
    units_lost: int
    buildings_built: int
    elo_change: int

    @staticmethod
    def resolve_username(obj):
        return obj.user.username

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


class SnapshotTickSchema(Schema):
    tick: int
    created_at: datetime

    class Config:
        from_attributes = True


class SnapshotDetailSchema(Schema):
    tick: int
    state_data: dict
    created_at: datetime

    class Config:
        from_attributes = True
