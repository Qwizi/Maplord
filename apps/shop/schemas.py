import uuid
from typing import List, Optional
from ninja import Schema


class ShopItemOutSchema(Schema):
    id: uuid.UUID
    name: str
    description: str
    item_type: str
    price: int
    icon: str
    image: Optional[str] = None

    class Config:
        from_attributes = True


class ShopCategoryOutSchema(Schema):
    id: uuid.UUID
    name: str
    slug: str
    items: List[ShopItemOutSchema] = []

    class Config:
        from_attributes = True
