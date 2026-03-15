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


class CustomMapOutSchema(Schema):
    id: uuid.UUID
    name: str
    description: str
    author_id: uuid.UUID
    author_username: str
    is_published: bool
    province_count: int
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True

    @staticmethod
    def resolve_author_username(obj):
        return obj.author.username

    @staticmethod
    def resolve_province_count(obj):
        return obj.provinces.count()

    @staticmethod
    def resolve_created_at(obj):
        return obj.created_at.isoformat()

    @staticmethod
    def resolve_updated_at(obj):
        return obj.updated_at.isoformat()


class CustomMapCreateSchema(Schema):
    name: str
    description: str = ''


class CustomMapUpdateSchema(Schema):
    name: Optional[str] = None
    description: Optional[str] = None
    is_published: Optional[bool] = None


class CustomProvinceOutSchema(Schema):
    id: uuid.UUID
    name: str
    color: str
    geometry: dict
    centroid: Optional[List[float]] = None
    properties: dict

    class Config:
        from_attributes = True

    @staticmethod
    def resolve_geometry(obj):
        import json
        return json.loads(obj.geometry.geojson)

    @staticmethod
    def resolve_centroid(obj):
        if obj.centroid:
            return [obj.centroid.x, obj.centroid.y]
        return None


class CustomProvinceCreateSchema(Schema):
    name: str
    color: str = ''
    geometry: dict  # GeoJSON geometry object
    properties: dict = {}


class CustomProvinceUpdateSchema(Schema):
    name: Optional[str] = None
    color: Optional[str] = None
    geometry: Optional[dict] = None
    properties: Optional[dict] = None


class CustomMapDetailSchema(CustomMapOutSchema):
    provinces: List[CustomProvinceOutSchema]

    @staticmethod
    def resolve_provinces(obj):
        return list(obj.provinces.all())
