import copy

from django.test import SimpleTestCase

from apps.game.consumers import GameConsumer
from apps.game.engine import GameEngine, MAX_BUILD_QUEUE_PER_REGION, MAX_UNIT_QUEUE_PER_REGION


class GameConsumerDeltaTests(SimpleTestCase):
    def test_compute_changed_regions_detects_in_place_owner_change(self):
        before_tick = {
            "2": {
                "owner_id": None,
                "unit_count": 3,
                "units": {"infantry": 3},
                "sea_distances": [{"r": 20, "provinces": ["1"]}],
            }
        }
        current = copy.deepcopy(before_tick)
        current["2"]["owner_id"] = "p1"
        current["2"]["unit_count"] = 1
        current["2"]["units"] = {"infantry": 1}

        changed = GameConsumer._compute_changed_regions(before_tick, current)

        self.assertEqual(changed["2"]["owner_id"], "p1")
        self.assertEqual(changed["2"]["unit_count"], 1)
        self.assertNotIn("sea_distances", changed["2"])

    def test_compute_changed_regions_handles_engine_in_place_mutation(self):
        settings = {
            "default_unit_type_slug": "infantry",
            "base_unit_generation_rate": 0.0,
            "combat_randomness": 0.0,
            "attacker_advantage": 0.0,
            "defender_advantage": 0.0,
        }
        neighbor_map = {"1": ["2"], "2": ["1"]}
        engine = GameEngine(settings, neighbor_map)
        regions = {
            "1": {"owner_id": "p1", "unit_count": 10, "units": {"infantry": 10}, "is_capital": False},
            "2": {"owner_id": None, "unit_count": 1, "units": {"infantry": 1}, "is_capital": False},
        }
        players = {"p1": {"currency": 0, "currency_accum": 0.0, "is_alive": True}}
        transit_queue = [{
            "action_type": "attack",
            "source_region_id": "1",
            "target_region_id": "2",
            "player_id": "p1",
            "unit_type": "infantry",
            "units": 5,
            "ticks_remaining": 0,
            "travel_ticks": 1,
        }]
        before_tick = copy.deepcopy(regions)

        result = engine.process_tick(players, regions, [], [], [], transit_queue)
        changed = GameConsumer._compute_changed_regions(before_tick, result["regions"])

        self.assertEqual(result["regions"]["2"]["owner_id"], "p1")
        self.assertIn("2", changed)
        self.assertEqual(changed["2"]["owner_id"], "p1")

    def test_compute_changed_regions_detects_completed_building_changes(self):
        settings = {
            "default_unit_type_slug": "infantry",
            "building_types": {
                "factory": {
                    "order": 1,
                    "defense_bonus": 0.25,
                    "vision_range": 1,
                    "unit_generation_bonus": 0.5,
                    "currency_generation_bonus": 0.75,
                }
            },
        }
        engine = GameEngine(settings, {})
        regions = {
            "5": {
                "owner_id": "p1",
                "unit_count": 4,
                "units": {"infantry": 4},
                "is_capital": False,
                "buildings": {},
                "building_type": None,
                "defense_bonus": 0.0,
                "vision_range": 0,
                "unit_generation_bonus": 0.0,
                "currency_generation_bonus": 0.0,
            }
        }
        before_tick = copy.deepcopy(regions)

        result = engine.process_tick(
            players={"p1": {"currency": 0, "currency_accum": 0.0, "is_alive": True}},
            regions=regions,
            actions=[],
            buildings_queue=[{
                "region_id": "5",
                "building_type": "factory",
                "player_id": "p1",
                "ticks_remaining": 0,
                "total_ticks": 1,
            }],
            unit_queue=[],
            transit_queue=[],
        )
        changed = GameConsumer._compute_changed_regions(before_tick, result["regions"])

        self.assertEqual(changed["5"]["building_type"], "factory")
        self.assertEqual(changed["5"]["buildings"]["factory"], 1)
        self.assertEqual(changed["5"]["defense_bonus"], 0.25)

    def test_compute_changed_regions_detects_source_region_unit_loss(self):
        settings = {
            "default_unit_type_slug": "infantry",
            "base_unit_generation_rate": 0.0,
            "combat_randomness": 0.0,
            "attacker_advantage": 0.0,
            "defender_advantage": 0.0,
        }
        neighbor_map = {"1": ["2"], "2": ["1"]}
        engine = GameEngine(settings, neighbor_map)
        regions = {
            "1": {"owner_id": "p1", "unit_count": 10, "units": {"infantry": 10}, "is_capital": False},
            "2": {"owner_id": None, "unit_count": 3, "units": {"infantry": 3}, "is_capital": False},
        }
        before_tick = copy.deepcopy(regions)

        result = engine.process_tick(
            players={"p1": {"currency": 0, "currency_accum": 0.0, "is_alive": True}},
            regions=regions,
            actions=[{
                "action_type": "attack",
                "source_region_id": "1",
                "target_region_id": "2",
                "player_id": "p1",
                "units": 4,
                "unit_type": "infantry",
            }],
            buildings_queue=[],
            unit_queue=[],
            transit_queue=[],
        )
        changed = GameConsumer._compute_changed_regions(before_tick, result["regions"])

        self.assertIn("1", changed)
        self.assertEqual(changed["1"]["unit_count"], 6)
        self.assertEqual(changed["1"]["units"]["infantry"], 6)

    def test_disconnect_timeout_marks_player_eliminated_and_game_over(self):
        consumer = GameConsumer()
        players = {
            "p1": {
                "is_alive": True,
                "connected": False,
                "disconnect_deadline": 1,
            },
            "p2": {
                "is_alive": True,
                "connected": True,
                "disconnect_deadline": None,
            },
        }

        changed_events = consumer._resolve_disconnect_timeout_events(players)

        self.assertEqual(changed_events[0]["type"], "player_eliminated")
        self.assertEqual(changed_events[0]["player_id"], "p1")
        self.assertEqual(changed_events[0]["reason"], "disconnect_timeout")
        self.assertEqual(changed_events[1]["type"], "game_over")
        self.assertEqual(changed_events[1]["winner_id"], "p2")
        self.assertFalse(players["p1"]["is_alive"])


class GameEngineAirMovementTests(SimpleTestCase):
    def test_air_units_can_move_to_owned_region_over_enemy_regions(self):
        settings = {
            "default_unit_type_slug": "infantry",
            "unit_types": {
                "fighter": {
                    "attack": 2.5,
                    "defense": 1.0,
                    "speed": 1,
                    "attack_range": 3,
                    "movement_type": "air",
                    "production_cost": 25,
                    "production_time_ticks": 12,
                    "manpower_cost": 10,
                }
            },
        }
        neighbor_map = {
            "1": ["2"],
            "2": ["1", "3"],
            "3": ["2", "4"],
            "4": ["3"],
        }
        engine = GameEngine(settings, neighbor_map)
        regions = {
            "1": {"owner_id": "p1", "unit_count": 10, "units": {"fighter": 1, "infantry": 10}, "is_capital": False},
            "2": {"owner_id": "enemy", "unit_count": 2, "units": {"infantry": 2}, "is_capital": False},
            "3": {"owner_id": "enemy", "unit_count": 2, "units": {"infantry": 2}, "is_capital": False},
            "4": {"owner_id": "p1", "unit_count": 0, "units": {}, "is_capital": False},
        }

        events = engine._process_move(
            {
                "action_type": "move",
                "source_region_id": "1",
                "target_region_id": "4",
                "player_id": "p1",
                "units": 1,
                "unit_type": "fighter",
            },
            regions,
            transit_queue=[],
        )

        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["type"], "troops_sent")
        self.assertEqual(events[0]["action_type"], "move")

    def test_move_to_owned_region_keeps_air_units_without_production_building(self):
        settings = {
            "default_unit_type_slug": "infantry",
            "unit_types": {
                "fighter": {
                    "attack": 2.5,
                    "defense": 1.0,
                    "speed": 1,
                    "attack_range": 3,
                    "movement_type": "air",
                    "production_cost": 25,
                    "production_time_ticks": 12,
                    "produced_by_slug": "carrier",
                    "manpower_cost": 10,
                }
            },
        }
        engine = GameEngine(settings, {"1": ["2"], "2": ["1"]})
        regions = {
            "1": {
                "owner_id": "p1",
                "unit_count": 10,
                "units": {"fighter": 1, "infantry": 10},
                "is_capital": False,
                "is_coastal": False,
                "buildings": {"carrier": 1},
            },
            "2": {
                "owner_id": "p1",
                "unit_count": 0,
                "units": {},
                "is_capital": False,
                "is_coastal": False,
                "buildings": {},
            },
        }
        transit_queue: list[dict] = []

        events = engine._process_move(
            {
                "action_type": "move",
                "source_region_id": "1",
                "target_region_id": "2",
                "player_id": "p1",
                "units": 1,
                "unit_type": "fighter",
            },
            regions,
            transit_queue=transit_queue,
        )

        self.assertEqual(events[0]["type"], "troops_sent")
        arrival_events = engine._resolve_move_arrival(transit_queue[0], regions)
        self.assertEqual(arrival_events[0]["type"], "units_moved")
        self.assertEqual(regions["2"]["units"]["fighter"], 1)

    def test_move_rejects_sea_units_to_non_coastal_owned_region(self):
        settings = {
            "default_unit_type_slug": "infantry",
            "unit_types": {
                "ship": {
                    "attack": 2.0,
                    "defense": 2.0,
                    "speed": 4,
                    "attack_range": 4,
                    "movement_type": "sea",
                    "sea_hop_distance_km": 2800,
                    "production_cost": 20,
                    "production_time_ticks": 10,
                    "produced_by_slug": "port",
                    "manpower_cost": 10,
                }
            },
        }
        engine = GameEngine(settings, {"1": ["2"], "2": ["1"]})
        regions = {
            "1": {
                "owner_id": "p1",
                "unit_count": 10,
                "units": {"ship": 1, "infantry": 10},
                "is_capital": False,
                "is_coastal": True,
                "buildings": {"port": 1},
            },
            "2": {
                "owner_id": "p1",
                "unit_count": 0,
                "units": {},
                "is_capital": False,
                "is_coastal": False,
                "buildings": {},
            },
        }

        events = engine._process_move(
            {
                "action_type": "move",
                "source_region_id": "1",
                "target_region_id": "2",
                "player_id": "p1",
                "units": 1,
                "unit_type": "ship",
            },
            regions,
            transit_queue=[],
        )

        self.assertEqual(events[0]["type"], "action_rejected")
        self.assertEqual(regions["1"]["units"]["ship"], 1)


class GameEngineQueueLimitTests(SimpleTestCase):
    def test_build_queue_has_region_cap(self):
        engine = GameEngine(
            settings={
                "default_unit_type_slug": "infantry",
                "building_types": {
                    "factory": {
                        "currency_cost": 10,
                        "build_time_ticks": 5,
                        "max_per_region": 10,
                    }
                },
            },
            neighbor_map={},
        )
        players = {"p1": {"currency": 100}}
        regions = {"1": {"owner_id": "p1", "buildings": {}, "is_coastal": False}}
        buildings_queue = [
            {"region_id": "1", "building_type": "factory", "player_id": "p1", "ticks_remaining": 3, "total_ticks": 5}
            for _ in range(MAX_BUILD_QUEUE_PER_REGION)
        ]

        events = engine._process_build(
            {"action_type": "build", "region_id": "1", "building_type": "factory", "player_id": "p1"},
            players,
            regions,
            buildings_queue,
        )

        self.assertEqual(events[0]["type"], "action_rejected")
        self.assertIn("maksymalna liczbe budow", events[0]["message"])

    def test_unit_queue_has_region_cap(self):
        engine = GameEngine(
            settings={
                "default_unit_type_slug": "infantry",
                "unit_types": {
                    "ship": {
                        "produced_by_slug": "port",
                        "movement_type": "sea",
                        "production_cost": 10,
                        "production_time_ticks": 5,
                        "manpower_cost": 1,
                    }
                },
            },
            neighbor_map={},
        )
        players = {"p1": {"currency": 100}}
        regions = {"1": {"owner_id": "p1", "buildings": {"port": 1}, "is_coastal": True, "units": {"infantry": 20}}}
        unit_queue = [
            {"region_id": "1", "player_id": "p1", "unit_type": "ship", "quantity": 1, "ticks_remaining": 3, "total_ticks": 5}
            for _ in range(MAX_UNIT_QUEUE_PER_REGION)
        ]

        events = engine._process_unit_production(
            {"action_type": "produce_unit", "region_id": "1", "unit_type": "ship", "player_id": "p1"},
            players,
            regions,
            unit_queue,
        )

        self.assertEqual(events[0]["type"], "action_rejected")
        self.assertIn("maksymalna liczbe jednostek", events[0]["message"])
