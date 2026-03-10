import uuid
from typing import Optional, List
from ninja import Schema


class CountryOutSchema(Schema):
    id: uuid.UUID
    name: str
    code: str

    class Config:
        from_attributes = True


class RegionOutSchema(Schema):
    id: uuid.UUID
    name: str
    country_id: uuid.UUID
    is_coastal: bool
    population_weight: float
    centroid_lat: Optional[float] = None
    centroid_lng: Optional[float] = None

    class Config:
        from_attributes = True

    @staticmethod
    def resolve_centroid_lat(obj):
        return obj.centroid.y if obj.centroid else None

    @staticmethod
    def resolve_centroid_lng(obj):
        return obj.centroid.x if obj.centroid else None


class RegionGeoJsonFeature(Schema):
    type: str = 'Feature'
    id: str
    properties: dict
    geometry: dict


class RegionGeoJsonCollection(Schema):
    type: str = 'FeatureCollection'
    features: List[RegionGeoJsonFeature]
