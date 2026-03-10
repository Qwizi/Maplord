from ninja_extra import api_controller, route

from apps.game_config.models import GameSettings, BuildingType, UnitType, MapConfig
from apps.game_config.schemas import FullConfigOutSchema


@api_controller('/config', tags=['Config'])
class ConfigController:

    @route.get('/', response=FullConfigOutSchema, auth=None)
    def get_config(self):
        """Returns full public game configuration."""
        settings = GameSettings.get()
        buildings = list(BuildingType.objects.filter(is_active=True))
        units = list(UnitType.objects.filter(is_active=True))
        maps = list(MapConfig.objects.filter(is_active=True))
        return {
            'settings': settings,
            'buildings': buildings,
            'units': units,
            'maps': maps,
        }
