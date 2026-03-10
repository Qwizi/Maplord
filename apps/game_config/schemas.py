import uuid
from typing import Optional, List
from ninja import Schema


class GameSettingsOutSchema(Schema):
    max_players: int
    min_players: int
    tick_interval_ms: int
    capital_selection_time_seconds: int
    match_duration_limit_minutes: int
    base_unit_generation_rate: float
    capital_generation_bonus: float
    attacker_advantage: float
    defender_advantage: float
    combat_randomness: float
    starting_units: int
    starting_regions: int

    class Config:
        from_attributes = True


class BuildingTypeOutSchema(Schema):
    id: uuid.UUID
    name: str
    slug: str
    description: str
    icon: str
    cost: int
    build_time_ticks: int
    max_per_region: int
    requires_coastal: bool
    defense_bonus: float
    vision_range: int
    unit_generation_bonus: float
    order: int

    class Config:
        from_attributes = True


class UnitTypeOutSchema(Schema):
    id: uuid.UUID
    name: str
    slug: str
    description: str
    icon: str
    attack: float
    defense: float
    speed: int
    attack_range: int
    produced_by_id: Optional[uuid.UUID] = None
    production_cost: int
    production_time_ticks: int
    movement_type: str
    order: int

    class Config:
        from_attributes = True


class MapConfigOutSchema(Schema):
    id: uuid.UUID
    name: str
    description: str
    country_codes: List[str]
    is_active: bool

    class Config:
        from_attributes = True


class FullConfigOutSchema(Schema):
    settings: GameSettingsOutSchema
    buildings: List[BuildingTypeOutSchema]
    units: List[UnitTypeOutSchema]
    maps: List[MapConfigOutSchema]
