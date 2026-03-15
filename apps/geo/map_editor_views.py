import json
from typing import List

from django.contrib.gis.geos import GEOSGeometry
from django.shortcuts import get_object_or_404
from ninja_extra import api_controller, route
from ninja_jwt.authentication import JWTAuth
from ninja_extra.permissions import IsAuthenticated

from apps.geo.models import CustomMap, CustomProvince
from apps.geo.schemas import (
    CustomMapOutSchema,
    CustomMapCreateSchema,
    CustomMapUpdateSchema,
    CustomMapDetailSchema,
    CustomProvinceOutSchema,
    CustomProvinceCreateSchema,
    CustomProvinceUpdateSchema,
)


@api_controller('/map-editor', tags=['Map Editor'], permissions=[IsAuthenticated], auth=JWTAuth())
class MapEditorController:

    @route.get('/maps/', response=List[CustomMapOutSchema])
    def list_maps(self, request):
        """List maps owned by the current user."""
        return list(
            CustomMap.objects.filter(author=request.user)
            .select_related('author')
            .prefetch_related('provinces')
        )

    @route.post('/maps/', response={201: CustomMapOutSchema})
    def create_map(self, request, payload: CustomMapCreateSchema):
        """Create a new custom map."""
        custom_map = CustomMap.objects.create(
            name=payload.name,
            description=payload.description,
            author=request.user,
        )
        return 201, custom_map

    @route.get('/maps/{map_id}/', response=CustomMapDetailSchema)
    def get_map(self, request, map_id: str):
        """Get map with all provinces."""
        return get_object_or_404(
            CustomMap.objects.select_related('author').prefetch_related('provinces'),
            id=map_id,
            author=request.user,
        )

    @route.patch('/maps/{map_id}/', response=CustomMapOutSchema)
    def update_map(self, request, map_id: str, payload: CustomMapUpdateSchema):
        """Update map metadata."""
        custom_map = get_object_or_404(CustomMap, id=map_id, author=request.user)
        if payload.name is not None:
            custom_map.name = payload.name
        if payload.description is not None:
            custom_map.description = payload.description
        if payload.is_published is not None:
            custom_map.is_published = payload.is_published
        custom_map.save()
        return custom_map

    @route.delete('/maps/{map_id}/', response={204: None})
    def delete_map(self, request, map_id: str):
        """Delete a custom map and all its provinces."""
        custom_map = get_object_or_404(CustomMap, id=map_id, author=request.user)
        custom_map.delete()
        return 204, None

    # --- Provinces ---

    @route.post('/maps/{map_id}/provinces/', response={201: CustomProvinceOutSchema})
    def create_province(self, request, map_id: str, payload: CustomProvinceCreateSchema):
        """Add a province (polygon) to a map."""
        custom_map = get_object_or_404(CustomMap, id=map_id, author=request.user)
        geom = GEOSGeometry(json.dumps(payload.geometry), srid=4326)
        province = CustomProvince.objects.create(
            custom_map=custom_map,
            name=payload.name,
            color=payload.color,
            geometry=geom,
            properties=payload.properties,
        )
        return 201, province

    @route.patch('/maps/{map_id}/provinces/{province_id}/', response=CustomProvinceOutSchema)
    def update_province(self, request, map_id: str, province_id: str, payload: CustomProvinceUpdateSchema):
        """Update a province."""
        province = get_object_or_404(
            CustomProvince,
            id=province_id,
            custom_map_id=map_id,
            custom_map__author=request.user,
        )
        if payload.name is not None:
            province.name = payload.name
        if payload.color is not None:
            province.color = payload.color
        if payload.geometry is not None:
            province.geometry = GEOSGeometry(json.dumps(payload.geometry), srid=4326)
            province.centroid = province.geometry.centroid
        if payload.properties is not None:
            province.properties = payload.properties
        province.save()
        return province

    @route.delete('/maps/{map_id}/provinces/{province_id}/', response={204: None})
    def delete_province(self, request, map_id: str, province_id: str):
        """Remove a province from a map."""
        province = get_object_or_404(
            CustomProvince,
            id=province_id,
            custom_map_id=map_id,
            custom_map__author=request.user,
        )
        province.delete()
        return 204, None
