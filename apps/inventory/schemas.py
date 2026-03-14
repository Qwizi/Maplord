import uuid
from datetime import datetime
from typing import Optional
from ninja import Schema


class DeckItemSlotSchema(Schema):
    """Input schema for a single item slot when updating a deck."""
    item_slug: str
    quantity: int


class DeckCreateSchema(Schema):
    name: str


class DeckUpdateSchema(Schema):
    name: Optional[str] = None
    items: Optional[list[DeckItemSlotSchema]] = None


class ItemOutSchema(Schema):
    id: uuid.UUID
    name: str
    slug: str
    description: str
    item_type: str
    rarity: str
    icon: str
    asset_key: str
    is_stackable: bool
    is_tradeable: bool
    is_consumable: bool
    base_value: int
    level: int
    blueprint_ref: str = ''

    class Config:
        from_attributes = True


class ItemCategoryOutSchema(Schema):
    id: uuid.UUID
    name: str
    slug: str
    items: list[ItemOutSchema] = []

    class Config:
        from_attributes = True


class InventoryItemOutSchema(Schema):
    id: uuid.UUID
    item: ItemOutSchema
    quantity: int

    class Config:
        from_attributes = True


class WalletOutSchema(Schema):
    gold: int
    total_earned: int
    total_spent: int

    class Config:
        from_attributes = True


class ItemDropOutSchema(Schema):
    id: uuid.UUID
    item: ItemOutSchema
    quantity: int
    source: str
    match_id: Optional[uuid.UUID] = None
    created_at: datetime

    class Config:
        from_attributes = True


class OpenCrateInSchema(Schema):
    crate_item_slug: str
    key_item_slug: str


class DeckItemOutSchema(Schema):
    item: ItemOutSchema
    quantity: int

    class Config:
        from_attributes = True


class DeckOutSchema(Schema):
    id: uuid.UUID
    name: str
    is_default: bool
    items: list[DeckItemOutSchema] = []

    class Config:
        from_attributes = True


class EquipCosmeticInSchema(Schema):
    item_slug: str


class UnequipCosmeticInSchema(Schema):
    slot: str


class EquippedCosmeticOutSchema(Schema):
    slot: str
    item_slug: str
    item_name: str
    asset_url: str | None = None
    cosmetic_params: dict | None = None

    class Config:
        from_attributes = True

    @staticmethod
    def resolve_item_slug(obj):
        return obj.item.slug

    @staticmethod
    def resolve_item_name(obj):
        return obj.item.name

    @staticmethod
    def resolve_asset_url(obj):
        if obj.item.cosmetic_asset and obj.item.cosmetic_asset.file:
            return obj.item.cosmetic_asset.file.url
        return None

    @staticmethod
    def resolve_cosmetic_params(obj):
        return obj.item.cosmetic_params
