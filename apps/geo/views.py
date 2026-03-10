import json
from typing import List
from django.contrib.gis.serializers.geojson import Serializer as GeoJSONSerializer
from ninja_extra import api_controller, route

from apps.geo.models import Country, Region
from apps.geo.schemas import CountryOutSchema, RegionOutSchema


@api_controller('/geo', tags=['Geo'])
class GeoController:

    @route.get('/countries/', response=List[CountryOutSchema], auth=None)
    def list_countries(self):
        return list(Country.objects.all())

    @route.get('/regions/', auth=None)
    def list_regions(self, country_code: str = None):
        """Returns regions as GeoJSON FeatureCollection."""
        qs = Region.objects.select_related('country').prefetch_related('neighbors')
        if country_code:
            qs = qs.filter(country__code=country_code)

        serializer = GeoJSONSerializer()
        geojson_str = serializer.serialize(
            qs,
            geometry_field='geometry',
            fields=('name', 'is_coastal', 'population_weight'),
        )
        geojson = json.loads(geojson_str)

        # Enrich properties
        regions_by_pk = {str(r.pk): r for r in qs}
        for feature in geojson['features']:
            pk = feature['properties'].get('pk') or feature.get('id')
            region = regions_by_pk.get(str(pk))
            if region:
                feature['id'] = str(region.id)
                feature['properties']['id'] = str(region.id)
                feature['properties']['country_code'] = region.country.code
                feature['properties']['country_name'] = region.country.name
                feature['properties']['neighbor_ids'] = [
                    str(n.id) for n in region.neighbors.all()
                ]
                if region.centroid:
                    feature['properties']['centroid'] = [region.centroid.x, region.centroid.y]

        return geojson

    @route.get('/regions/{region_id}/', response=RegionOutSchema, auth=None)
    def get_region(self, region_id: str):
        return Region.objects.select_related('country').get(id=region_id)
