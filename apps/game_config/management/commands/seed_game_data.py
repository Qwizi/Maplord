from django.core.management.base import BaseCommand

from apps.game_config.models import BuildingType, GameSettings, UnitType


BUILDINGS = [
    {
        "name": "Barracks",
        "slug": "barracks",
        "description": "Trains infantry units. Basic land military building.",
        "icon": "🏠",
        "cost": 30,
        "build_time_ticks": 8,
        "requires_coastal": False,
        "defense_bonus": 0.0,
        "vision_range": 0,
        "unit_generation_bonus": 0.5,
        "order": 1,
    },
    {
        "name": "Factory",
        "slug": "factory",
        "description": "Produces heavy armored vehicles. Stronger than infantry.",
        "icon": "🏭",
        "cost": 60,
        "build_time_ticks": 15,
        "requires_coastal": False,
        "defense_bonus": 0.0,
        "vision_range": 0,
        "unit_generation_bonus": 0.3,
        "order": 2,
    },
    {
        "name": "Tower",
        "slug": "tower",
        "description": "Defensive structure. Grants defense bonus to the region.",
        "icon": "🗼",
        "cost": 40,
        "build_time_ticks": 10,
        "requires_coastal": False,
        "defense_bonus": 0.4,
        "vision_range": 2,
        "unit_generation_bonus": 0.0,
        "order": 3,
    },
    {
        "name": "Port",
        "slug": "port",
        "description": "Builds ships. Must be placed on a coastal region.",
        "icon": "⚓",
        "cost": 50,
        "build_time_ticks": 12,
        "requires_coastal": True,
        "defense_bonus": 0.0,
        "vision_range": 1,
        "unit_generation_bonus": 0.2,
        "order": 4,
    },
    {
        "name": "Aircraft Carrier",
        "slug": "carrier",
        "description": "Launches fighters with long range. Requires coastal region.",
        "icon": "🛫",
        "cost": 100,
        "build_time_ticks": 25,
        "requires_coastal": True,
        "defense_bonus": 0.1,
        "vision_range": 3,
        "unit_generation_bonus": 0.1,
        "order": 5,
    },
    {
        "name": "Radar",
        "slug": "radar",
        "description": "Extends vision range. Reveals enemy movements nearby.",
        "icon": "📡",
        "cost": 35,
        "build_time_ticks": 6,
        "requires_coastal": False,
        "defense_bonus": 0.0,
        "vision_range": 5,
        "unit_generation_bonus": 0.0,
        "order": 6,
    },
]

UNITS = [
    {
        "name": "Infantry",
        "slug": "infantry",
        "description": "Basic land unit. Cheap and fast to produce.",
        "icon": "🪖",
        "attack": 1.0,
        "defense": 1.0,
        "speed": 1,
        "attack_range": 1,
        "produced_by_slug": None,
        "production_cost": 0,
        "production_time_ticks": 0,
        "movement_type": "land",
        "order": 1,
    },
    {
        "name": "Tank",
        "slug": "tank",
        "description": "Heavy armored vehicle. Slow but powerful.",
        "icon": "🛡️",
        "attack": 3.0,
        "defense": 2.5,
        "speed": 1,
        "attack_range": 1,
        "produced_by_slug": "factory",
        "production_cost": 15,
        "production_time_ticks": 8,
        "movement_type": "land",
        "order": 2,
    },
    {
        "name": "Ship",
        "slug": "ship",
        "description": "Naval unit. Can attack coastal regions.",
        "icon": "🚢",
        "attack": 2.0,
        "defense": 2.0,
        "speed": 2,
        "attack_range": 1,
        "produced_by_slug": "port",
        "production_cost": 20,
        "production_time_ticks": 10,
        "movement_type": "sea",
        "order": 3,
    },
    {
        "name": "Fighter",
        "slug": "fighter",
        "description": "Air unit with long range. Launched from carriers.",
        "icon": "✈️",
        "attack": 2.5,
        "defense": 1.0,
        "speed": 3,
        "attack_range": 3,
        "produced_by_slug": "carrier",
        "production_cost": 25,
        "production_time_ticks": 12,
        "movement_type": "air",
        "order": 4,
    },
]


class Command(BaseCommand):
    help = "Seed default GameSettings, BuildingTypes, and UnitTypes"

    def handle(self, *args, **options):
        # GameSettings singleton
        if not GameSettings.objects.exists():
            GameSettings.objects.create()
            self.stdout.write(self.style.SUCCESS("Created default GameSettings"))
        else:
            self.stdout.write("GameSettings already exists — skipping")

        # Buildings
        building_map = {}
        for data in BUILDINGS:
            obj, created = BuildingType.objects.update_or_create(
                slug=data["slug"],
                defaults={k: v for k, v in data.items() if k != "slug"},
            )
            building_map[data["slug"]] = obj
            status = "created" if created else "updated"
            self.stdout.write(f"  BuildingType {obj.name}: {status}")

        # Units
        for data in UNITS:
            produced_by_slug = data.pop("produced_by_slug")
            produced_by = building_map.get(produced_by_slug) if produced_by_slug else None
            obj, created = UnitType.objects.update_or_create(
                slug=data["slug"],
                defaults={**{k: v for k, v in data.items() if k != "slug"}, "produced_by": produced_by},
            )
            status = "created" if created else "updated"
            self.stdout.write(f"  UnitType {obj.name}: {status}")

        self.stdout.write(self.style.SUCCESS("Seed complete!"))
