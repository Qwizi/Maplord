import json
from pathlib import Path

from django.core.management import call_command
from django.core.management.base import BaseCommand, CommandError

from apps.game_config.models import BuildingType, GameSettings, MapConfig, UnitType
from apps.matchmaking.models import Match


DEFAULT_FIXTURE_PATH = (
    Path(__file__).resolve().parent.parent.parent.parent.parent
    / "fixtures"
    / "game_config.json"
)


class Command(BaseCommand):
    help = "Cleanly reload game config from fixture, then re-import provinces"

    def add_arguments(self, parser):
        parser.add_argument(
            "--fixture",
            type=str,
            default=str(DEFAULT_FIXTURE_PATH),
            help=f"Path to fixture JSON (default: {DEFAULT_FIXTURE_PATH})",
        )
        parser.add_argument(
            "--skip-provinces",
            action="store_true",
            help="Skip running import_provinces after loading config",
        )

    def handle(self, *args, **options):
        fixture_path = Path(options["fixture"])
        if not fixture_path.exists():
            raise CommandError(f"Fixture not found: {fixture_path}")

        with fixture_path.open() as fixture_file:
            payload = json.load(fixture_file)

        settings_entry = None
        building_entries = []
        unit_entries = []
        map_entries = []

        for entry in payload:
            model = entry.get("model")
            if model == "game_config.gamesettings":
                settings_entry = entry
            elif model == "game_config.buildingtype":
                building_entries.append(entry)
            elif model == "game_config.unittype":
                unit_entries.append(entry)
            elif model == "game_config.mapconfig":
                map_entries.append(entry)

        if not settings_entry:
            raise CommandError("Fixture does not contain game_config.gamesettings")

        self.stdout.write("Clearing existing game config...")
        Match.objects.update(map_config=None)
        UnitType.objects.all().delete()
        BuildingType.objects.all().delete()
        MapConfig.objects.all().delete()
        GameSettings.objects.all().delete()
        self.stdout.write("  Cleared.")

        self._load_settings(settings_entry)
        building_map = self._load_buildings(building_entries)
        self._load_units(unit_entries, building_entries, building_map)
        self._load_maps(map_entries)

        self.stdout.write(self.style.SUCCESS("Game config loaded successfully"))

        if not options["skip_provinces"]:
            self.stdout.write("\nRunning import_provinces --clear ...")
            call_command("import_provinces", clear=True, stdout=self.stdout, stderr=self.stderr)

    def _load_settings(self, entry: dict):
        fields = dict(entry.get("fields") or {})
        GameSettings.objects.create(**fields)
        self.stdout.write("  GameSettings: created")

    def _load_buildings(self, entries: list[dict]) -> dict[str, BuildingType]:
        building_map: dict[str, BuildingType] = {}

        for entry in entries:
            fields = dict(entry.get("fields") or {})
            instance = BuildingType.objects.create(**fields)
            building_map[str(entry.get("pk"))] = instance

        self.stdout.write(f"  BuildingType: {len(building_map)} created")
        return building_map

    def _load_units(
        self,
        entries: list[dict],
        building_entries: list[dict],
        building_map: dict[str, BuildingType],
    ):
        building_pk_to_slug = {
            str(entry.get("pk")): (entry.get("fields") or {}).get("slug")
            for entry in building_entries
        }
        count = 0

        for entry in entries:
            fields = dict(entry.get("fields") or {})
            produced_by_pk = fields.pop("produced_by", None)
            produced_by_slug = building_pk_to_slug.get(str(produced_by_pk)) if produced_by_pk else None
            fields["produced_by"] = (
                BuildingType.objects.filter(slug=produced_by_slug).first()
                if produced_by_slug
                else None
            )
            UnitType.objects.create(**fields)
            count += 1

        self.stdout.write(f"  UnitType: {count} created")

    def _load_maps(self, entries: list[dict]):
        count = 0

        for entry in entries:
            fields = {k: v for k, v in (entry.get("fields") or {}).items() if k != "created_at"}
            MapConfig.objects.create(**fields)
            count += 1

        self.stdout.write(f"  MapConfig: {count} created")
