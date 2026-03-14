from django.core.management.base import BaseCommand

from apps.inventory.models import Item, ItemCategory


CATEGORIES = [
    {'name': 'Materiały', 'slug': 'materials', 'order': 1},
    {'name': 'Blueprinty budynków', 'slug': 'blueprints-building', 'order': 2},
    {'name': 'Blueprinty jednostek', 'slug': 'blueprints-unit', 'order': 3},
    {'name': 'Pakiety taktyczne', 'slug': 'tactical-packages', 'order': 4},
    {'name': 'Bonusy', 'slug': 'boosts', 'order': 5},
    {'name': 'Skrzynie', 'slug': 'crates', 'order': 6},
    {'name': 'Klucze', 'slug': 'keys', 'order': 7},
    {'name': 'Kosmetyki', 'slug': 'cosmetics', 'order': 8},
    {'name': 'Animacje', 'slug': 'animacje', 'order': 9},
]

ITEMS = [
    # --- Materiały ---
    {'name': 'Złom stalowy', 'slug': 'steel-scrap', 'category_slug': 'materials', 'item_type': 'material', 'rarity': 'common', 'icon': 'steel_scrap', 'base_value': 5},
    {'name': 'Płytka obwodu', 'slug': 'circuit-board', 'category_slug': 'materials', 'item_type': 'material', 'rarity': 'common', 'icon': 'circuit_board', 'base_value': 5},
    {'name': 'Ogniwo paliwowe', 'slug': 'fuel-cell', 'category_slug': 'materials', 'item_type': 'material', 'rarity': 'uncommon', 'icon': 'fuel_cell', 'base_value': 15},
    {'name': 'Proch strzelniczy', 'slug': 'gunpowder', 'category_slug': 'materials', 'item_type': 'material', 'rarity': 'uncommon', 'icon': 'gunpowder', 'base_value': 15},
    {'name': 'Protokół dowodzenia', 'slug': 'command-protocol', 'category_slug': 'materials', 'item_type': 'material', 'rarity': 'rare', 'icon': 'command_protocol', 'base_value': 40},
    {'name': 'Światłowód', 'slug': 'optic-fiber', 'category_slug': 'materials', 'item_type': 'material', 'rarity': 'rare', 'icon': 'optic_fiber', 'base_value': 40},
    {'name': 'Rdzeń plazmowy', 'slug': 'plasma-core', 'category_slug': 'materials', 'item_type': 'material', 'rarity': 'epic', 'icon': 'plasma_core', 'base_value': 120},
    {'name': 'Fragment artefaktu', 'slug': 'artifact-fragment', 'category_slug': 'materials', 'item_type': 'material', 'rarity': 'legendary', 'icon': 'artifact_fragment', 'base_value': 350},

    # --- Blueprinty budynków (6 budynków × 3 poziomy) ---
    # Koszary
    {'name': 'Blueprint: Koszary Lvl 1', 'slug': 'bp-barracks-1', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'common', 'icon': 'bp_barracks', 'base_value': 20, 'is_consumable': False, 'blueprint_ref': 'barracks', 'level': 1},
    {'name': 'Blueprint: Koszary Lvl 2', 'slug': 'bp-barracks-2', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'uncommon', 'icon': 'bp_barracks', 'base_value': 50, 'is_consumable': False, 'blueprint_ref': 'barracks', 'level': 2},
    {'name': 'Blueprint: Koszary Lvl 3', 'slug': 'bp-barracks-3', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'rare', 'icon': 'bp_barracks', 'base_value': 100, 'is_consumable': False, 'blueprint_ref': 'barracks', 'level': 3},
    # Fabryka
    {'name': 'Blueprint: Fabryka Lvl 1', 'slug': 'bp-factory-1', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'common', 'icon': 'bp_factory', 'base_value': 30, 'is_consumable': False, 'blueprint_ref': 'factory', 'level': 1},
    {'name': 'Blueprint: Fabryka Lvl 2', 'slug': 'bp-factory-2', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'uncommon', 'icon': 'bp_factory', 'base_value': 70, 'is_consumable': False, 'blueprint_ref': 'factory', 'level': 2},
    {'name': 'Blueprint: Fabryka Lvl 3', 'slug': 'bp-factory-3', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'rare', 'icon': 'bp_factory', 'base_value': 120, 'is_consumable': False, 'blueprint_ref': 'factory', 'level': 3},
    # Wieża obronna
    {'name': 'Blueprint: Wieża Lvl 1', 'slug': 'bp-tower-1', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'common', 'icon': 'bp_tower', 'base_value': 25, 'is_consumable': False, 'blueprint_ref': 'tower', 'level': 1},
    {'name': 'Blueprint: Wieża Lvl 2', 'slug': 'bp-tower-2', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'uncommon', 'icon': 'bp_tower', 'base_value': 60, 'is_consumable': False, 'blueprint_ref': 'tower', 'level': 2},
    {'name': 'Blueprint: Wieża Lvl 3', 'slug': 'bp-tower-3', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'rare', 'icon': 'bp_tower', 'base_value': 110, 'is_consumable': False, 'blueprint_ref': 'tower', 'level': 3},
    # Port
    {'name': 'Blueprint: Port Lvl 1', 'slug': 'bp-port-1', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'uncommon', 'icon': 'bp_port', 'base_value': 50, 'is_consumable': False, 'blueprint_ref': 'port', 'level': 1},
    {'name': 'Blueprint: Port Lvl 2', 'slug': 'bp-port-2', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'rare', 'icon': 'bp_port', 'base_value': 100, 'is_consumable': False, 'blueprint_ref': 'port', 'level': 2},
    {'name': 'Blueprint: Port Lvl 3', 'slug': 'bp-port-3', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'epic', 'icon': 'bp_port', 'base_value': 180, 'is_consumable': False, 'blueprint_ref': 'port', 'level': 3},
    # Lotnisko
    {'name': 'Blueprint: Lotnisko Lvl 1', 'slug': 'bp-carrier-1', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'uncommon', 'icon': 'bp_carrier', 'base_value': 50, 'is_consumable': False, 'blueprint_ref': 'carrier', 'level': 1},
    {'name': 'Blueprint: Lotnisko Lvl 2', 'slug': 'bp-carrier-2', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'rare', 'icon': 'bp_carrier', 'base_value': 100, 'is_consumable': False, 'blueprint_ref': 'carrier', 'level': 2},
    {'name': 'Blueprint: Lotnisko Lvl 3', 'slug': 'bp-carrier-3', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'epic', 'icon': 'bp_carrier', 'base_value': 180, 'is_consumable': False, 'blueprint_ref': 'carrier', 'level': 3},
    # Elektrownia
    {'name': 'Blueprint: Elektrownia Lvl 1', 'slug': 'bp-radar-1', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'common', 'icon': 'bp_radar', 'base_value': 20, 'is_consumable': False, 'blueprint_ref': 'radar', 'level': 1},
    {'name': 'Blueprint: Elektrownia Lvl 2', 'slug': 'bp-radar-2', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'uncommon', 'icon': 'bp_radar', 'base_value': 50, 'is_consumable': False, 'blueprint_ref': 'radar', 'level': 2},
    {'name': 'Blueprint: Elektrownia Lvl 3', 'slug': 'bp-radar-3', 'category_slug': 'blueprints-building', 'item_type': 'blueprint_building', 'rarity': 'rare', 'icon': 'bp_radar', 'base_value': 100, 'is_consumable': False, 'blueprint_ref': 'radar', 'level': 3},

    # --- Blueprinty jednostek (3 actual units × 3 levels) ---
    # Czołg
    {'name': 'Blueprint: Czołg Lvl 1', 'slug': 'bp-tank-1', 'category_slug': 'blueprints-unit', 'item_type': 'blueprint_unit', 'rarity': 'uncommon', 'icon': 'bp_tank', 'base_value': 40, 'is_consumable': False, 'blueprint_ref': 'tank', 'level': 1},
    {'name': 'Blueprint: Czołg Lvl 2', 'slug': 'bp-tank-2', 'category_slug': 'blueprints-unit', 'item_type': 'blueprint_unit', 'rarity': 'rare', 'icon': 'bp_tank', 'base_value': 90, 'is_consumable': False, 'blueprint_ref': 'tank', 'level': 2},
    {'name': 'Blueprint: Czołg Lvl 3', 'slug': 'bp-tank-3', 'category_slug': 'blueprints-unit', 'item_type': 'blueprint_unit', 'rarity': 'epic', 'icon': 'bp_tank', 'base_value': 180, 'is_consumable': False, 'blueprint_ref': 'tank', 'level': 3},
    # Okręt
    {'name': 'Blueprint: Okręt Lvl 1', 'slug': 'bp-ship-1', 'category_slug': 'blueprints-unit', 'item_type': 'blueprint_unit', 'rarity': 'rare', 'icon': 'bp_ship', 'base_value': 80, 'is_consumable': False, 'blueprint_ref': 'ship', 'level': 1},
    {'name': 'Blueprint: Okręt Lvl 2', 'slug': 'bp-ship-2', 'category_slug': 'blueprints-unit', 'item_type': 'blueprint_unit', 'rarity': 'epic', 'icon': 'bp_ship', 'base_value': 160, 'is_consumable': False, 'blueprint_ref': 'ship', 'level': 2},
    {'name': 'Blueprint: Okręt Lvl 3', 'slug': 'bp-ship-3', 'category_slug': 'blueprints-unit', 'item_type': 'blueprint_unit', 'rarity': 'legendary', 'icon': 'bp_ship', 'base_value': 350, 'is_consumable': False, 'blueprint_ref': 'ship', 'level': 3},
    # Myśliwiec
    {'name': 'Blueprint: Myśliwiec Lvl 1', 'slug': 'bp-fighter-1', 'category_slug': 'blueprints-unit', 'item_type': 'blueprint_unit', 'rarity': 'rare', 'icon': 'bp_fighter', 'base_value': 70, 'is_consumable': False, 'blueprint_ref': 'fighter', 'level': 1},
    {'name': 'Blueprint: Myśliwiec Lvl 2', 'slug': 'bp-fighter-2', 'category_slug': 'blueprints-unit', 'item_type': 'blueprint_unit', 'rarity': 'epic', 'icon': 'bp_fighter', 'base_value': 150, 'is_consumable': False, 'blueprint_ref': 'fighter', 'level': 2},
    {'name': 'Blueprint: Myśliwiec Lvl 3', 'slug': 'bp-fighter-3', 'category_slug': 'blueprints-unit', 'item_type': 'blueprint_unit', 'rarity': 'legendary', 'icon': 'bp_fighter', 'base_value': 300, 'is_consumable': False, 'blueprint_ref': 'fighter', 'level': 3},

    # --- Pakiety taktyczne (5 zdolności × 3 poziomy) ---
    # Tarcza (Shield) — Lvl 1 darmowy, domyślnie w decku
    {'name': 'Pakiet: Tarcza Lvl 1', 'slug': 'pkg-shield-1', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'common', 'icon': 'pkg_shield', 'base_value': 0, 'is_consumable': False, 'blueprint_ref': 'ab_shield', 'level': 1},
    {'name': 'Pakiet: Tarcza Lvl 2', 'slug': 'pkg-shield-2', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'uncommon', 'icon': 'pkg_shield', 'base_value': 50, 'is_consumable': False, 'blueprint_ref': 'ab_shield', 'level': 2},
    {'name': 'Pakiet: Tarcza Lvl 3', 'slug': 'pkg-shield-3', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'rare', 'icon': 'pkg_shield', 'base_value': 120, 'is_consumable': False, 'blueprint_ref': 'ab_shield', 'level': 3},
    # Wirus
    {'name': 'Pakiet: Wirus Lvl 1', 'slug': 'pkg-virus-1', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'uncommon', 'icon': 'pkg_virus', 'base_value': 40, 'is_consumable': False, 'blueprint_ref': 'ab_virus', 'level': 1},
    {'name': 'Pakiet: Wirus Lvl 2', 'slug': 'pkg-virus-2', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'rare', 'icon': 'pkg_virus', 'base_value': 90, 'is_consumable': False, 'blueprint_ref': 'ab_virus', 'level': 2},
    {'name': 'Pakiet: Wirus Lvl 3', 'slug': 'pkg-virus-3', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'epic', 'icon': 'pkg_virus', 'base_value': 180, 'is_consumable': False, 'blueprint_ref': 'ab_virus', 'level': 3},
    # Uderzenie Nuklearne
    {'name': 'Pakiet: Uderzenie Nuklearne Lvl 1', 'slug': 'pkg-nuke-1', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'rare', 'icon': 'pkg_nuke', 'base_value': 100, 'is_consumable': False, 'blueprint_ref': 'ab_province_nuke', 'level': 1},
    {'name': 'Pakiet: Uderzenie Nuklearne Lvl 2', 'slug': 'pkg-nuke-2', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'epic', 'icon': 'pkg_nuke', 'base_value': 250, 'is_consumable': False, 'blueprint_ref': 'ab_province_nuke', 'level': 2},
    {'name': 'Pakiet: Uderzenie Nuklearne Lvl 3', 'slug': 'pkg-nuke-3', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'legendary', 'icon': 'pkg_nuke', 'base_value': 500, 'is_consumable': False, 'blueprint_ref': 'ab_province_nuke', 'level': 3},
    # Wywiad
    {'name': 'Pakiet: Wywiad Lvl 1', 'slug': 'pkg-recon-1', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'common', 'icon': 'pkg_recon', 'base_value': 20, 'is_consumable': False, 'blueprint_ref': 'ab_pr_submarine', 'level': 1},
    {'name': 'Pakiet: Wywiad Lvl 2', 'slug': 'pkg-recon-2', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'uncommon', 'icon': 'pkg_recon', 'base_value': 50, 'is_consumable': False, 'blueprint_ref': 'ab_pr_submarine', 'level': 2},
    {'name': 'Pakiet: Wywiad Lvl 3', 'slug': 'pkg-recon-3', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'rare', 'icon': 'pkg_recon', 'base_value': 110, 'is_consumable': False, 'blueprint_ref': 'ab_pr_submarine', 'level': 3},
    # Pobór
    {'name': 'Pakiet: Pobór Lvl 1', 'slug': 'pkg-conscription-1', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'common', 'icon': 'pkg_conscription', 'base_value': 15, 'is_consumable': False, 'blueprint_ref': 'ab_conscription_point', 'level': 1},
    {'name': 'Pakiet: Pobór Lvl 2', 'slug': 'pkg-conscription-2', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'uncommon', 'icon': 'pkg_conscription', 'base_value': 40, 'is_consumable': False, 'blueprint_ref': 'ab_conscription_point', 'level': 2},
    {'name': 'Pakiet: Pobór Lvl 3', 'slug': 'pkg-conscription-3', 'category_slug': 'tactical-packages', 'item_type': 'tactical_package', 'rarity': 'rare', 'icon': 'pkg_conscription', 'base_value': 100, 'is_consumable': False, 'blueprint_ref': 'ab_conscription_point', 'level': 3},

    # --- Bonusy (4 × 3 poziomy) ---
    # Mobilizacja
    {'name': 'Bonus: Mobilizacja Lvl 1', 'slug': 'boost-mobilization-1', 'category_slug': 'boosts', 'item_type': 'boost', 'rarity': 'common', 'icon': 'boost_mobilization', 'base_value': 15, 'is_consumable': True, 'level': 1,
     'boost_params': {'effect_type': 'unit_bonus', 'value': 0.15}},
    {'name': 'Bonus: Mobilizacja Lvl 2', 'slug': 'boost-mobilization-2', 'category_slug': 'boosts', 'item_type': 'boost', 'rarity': 'uncommon', 'icon': 'boost_mobilization', 'base_value': 35, 'is_consumable': True, 'level': 2,
     'boost_params': {'effect_type': 'unit_bonus', 'value': 0.30}},
    {'name': 'Bonus: Mobilizacja Lvl 3', 'slug': 'boost-mobilization-3', 'category_slug': 'boosts', 'item_type': 'boost', 'rarity': 'rare', 'icon': 'boost_mobilization', 'base_value': 70, 'is_consumable': True, 'level': 3,
     'boost_params': {'effect_type': 'unit_bonus', 'value': 0.50}},
    # Fortyfikacja
    {'name': 'Bonus: Fortyfikacja Lvl 1', 'slug': 'boost-fortification-1', 'category_slug': 'boosts', 'item_type': 'boost', 'rarity': 'common', 'icon': 'boost_fortification', 'base_value': 15, 'is_consumable': True, 'level': 1,
     'boost_params': {'effect_type': 'defense_bonus', 'value': 0.10}},
    {'name': 'Bonus: Fortyfikacja Lvl 2', 'slug': 'boost-fortification-2', 'category_slug': 'boosts', 'item_type': 'boost', 'rarity': 'uncommon', 'icon': 'boost_fortification', 'base_value': 35, 'is_consumable': True, 'level': 2,
     'boost_params': {'effect_type': 'defense_bonus', 'value': 0.20}},
    {'name': 'Bonus: Fortyfikacja Lvl 3', 'slug': 'boost-fortification-3', 'category_slug': 'boosts', 'item_type': 'boost', 'rarity': 'rare', 'icon': 'boost_fortification', 'base_value': 70, 'is_consumable': True, 'level': 3,
     'boost_params': {'effect_type': 'defense_bonus', 'value': 0.35}},
    # Ekonomia Wojenna
    {'name': 'Bonus: Ekonomia Wojenna Lvl 1', 'slug': 'boost-war-economy-1', 'category_slug': 'boosts', 'item_type': 'boost', 'rarity': 'uncommon', 'icon': 'boost_war_economy', 'base_value': 25, 'is_consumable': True, 'level': 1,
     'boost_params': {'effect_type': 'energy_bonus', 'value': 0.20}},
    {'name': 'Bonus: Ekonomia Wojenna Lvl 2', 'slug': 'boost-war-economy-2', 'category_slug': 'boosts', 'item_type': 'boost', 'rarity': 'rare', 'icon': 'boost_war_economy', 'base_value': 60, 'is_consumable': True, 'level': 2,
     'boost_params': {'effect_type': 'energy_bonus', 'value': 0.40}},
    {'name': 'Bonus: Ekonomia Wojenna Lvl 3', 'slug': 'boost-war-economy-3', 'category_slug': 'boosts', 'item_type': 'boost', 'rarity': 'epic', 'icon': 'boost_war_economy', 'base_value': 130, 'is_consumable': True, 'level': 3,
     'boost_params': {'effect_type': 'energy_bonus', 'value': 0.65}},
    # Blitzkrieg
    {'name': 'Bonus: Blitzkrieg Lvl 1', 'slug': 'boost-blitzkrieg-1', 'category_slug': 'boosts', 'item_type': 'boost', 'rarity': 'uncommon', 'icon': 'boost_blitzkrieg', 'base_value': 25, 'is_consumable': True, 'level': 1,
     'boost_params': {'effect_type': 'attack_bonus', 'value': 0.15}},
    {'name': 'Bonus: Blitzkrieg Lvl 2', 'slug': 'boost-blitzkrieg-2', 'category_slug': 'boosts', 'item_type': 'boost', 'rarity': 'rare', 'icon': 'boost_blitzkrieg', 'base_value': 60, 'is_consumable': True, 'level': 2,
     'boost_params': {'effect_type': 'attack_bonus', 'value': 0.30}},
    {'name': 'Bonus: Blitzkrieg Lvl 3', 'slug': 'boost-blitzkrieg-3', 'category_slug': 'boosts', 'item_type': 'boost', 'rarity': 'epic', 'icon': 'boost_blitzkrieg', 'base_value': 130, 'is_consumable': True, 'level': 3,
     'boost_params': {'effect_type': 'attack_bonus', 'value': 0.50}},

    # --- Skrzynie ---
    {'name': 'Skrzynia Żołnierska', 'slug': 'crate-soldier', 'category_slug': 'crates', 'item_type': 'crate', 'rarity': 'common', 'icon': 'crate_soldier', 'base_value': 20, 'is_consumable': True,
     'crate_loot_table': [
         {'item_slug': 'steel-scrap', 'weight': 40, 'min_qty': 2, 'max_qty': 5},
         {'item_slug': 'circuit-board', 'weight': 40, 'min_qty': 2, 'max_qty': 5},
         {'item_slug': 'fuel-cell', 'weight': 15, 'min_qty': 1, 'max_qty': 2},
         {'item_slug': 'gunpowder', 'weight': 15, 'min_qty': 1, 'max_qty': 2},
         {'item_slug': 'boost-mobilization-1', 'weight': 5, 'min_qty': 1, 'max_qty': 1},
         {'item_slug': 'bp-barracks-1', 'weight': 3, 'min_qty': 1, 'max_qty': 1},
         {'item_slug': 'pkg-shield-1', 'weight': 2, 'min_qty': 1, 'max_qty': 1},
     ]},
    {'name': 'Skrzynia Oficerska', 'slug': 'crate-officer', 'category_slug': 'crates', 'item_type': 'crate', 'rarity': 'uncommon', 'icon': 'crate_officer', 'base_value': 50, 'is_consumable': True,
     'crate_loot_table': [
         {'item_slug': 'fuel-cell', 'weight': 30, 'min_qty': 1, 'max_qty': 3},
         {'item_slug': 'gunpowder', 'weight': 30, 'min_qty': 1, 'max_qty': 3},
         {'item_slug': 'command-protocol', 'weight': 15, 'min_qty': 1, 'max_qty': 2},
         {'item_slug': 'optic-fiber', 'weight': 15, 'min_qty': 1, 'max_qty': 2},
         {'item_slug': 'bp-barracks-1', 'weight': 5, 'min_qty': 1, 'max_qty': 1},
         {'item_slug': 'bp-factory-1', 'weight': 5, 'min_qty': 1, 'max_qty': 1},
         {'item_slug': 'bp-tower-1', 'weight': 5, 'min_qty': 1, 'max_qty': 1},
         {'item_slug': 'boost-fortification-1', 'weight': 4, 'min_qty': 1, 'max_qty': 1},
         {'item_slug': 'pkg-recon-1', 'weight': 3, 'min_qty': 1, 'max_qty': 1},
     ]},
    {'name': 'Skrzynia Generalna', 'slug': 'crate-general', 'category_slug': 'crates', 'item_type': 'crate', 'rarity': 'rare', 'icon': 'crate_general', 'base_value': 120, 'is_consumable': True,
     'crate_loot_table': [
         {'item_slug': 'command-protocol', 'weight': 25, 'min_qty': 1, 'max_qty': 3},
         {'item_slug': 'optic-fiber', 'weight': 25, 'min_qty': 1, 'max_qty': 3},
         {'item_slug': 'plasma-core', 'weight': 15, 'min_qty': 1, 'max_qty': 1},
         {'item_slug': 'bp-barracks-2', 'weight': 7, 'min_qty': 1, 'max_qty': 1},
         {'item_slug': 'bp-factory-2', 'weight': 7, 'min_qty': 1, 'max_qty': 1},
         {'item_slug': 'bp-tank-1', 'weight': 5, 'min_qty': 1, 'max_qty': 1},
         {'item_slug': 'bp-ship-1', 'weight': 3, 'min_qty': 1, 'max_qty': 1},
         {'item_slug': 'bp-fighter-1', 'weight': 3, 'min_qty': 1, 'max_qty': 1},
         {'item_slug': 'pkg-nuke-1', 'weight': 3, 'min_qty': 1, 'max_qty': 1},
         {'item_slug': 'boost-war-economy-2', 'weight': 3, 'min_qty': 1, 'max_qty': 1},
         {'item_slug': 'artifact-fragment', 'weight': 1, 'min_qty': 1, 'max_qty': 1},
     ]},

    # --- Klucze ---
    {'name': 'Klucz Żołnierski', 'slug': 'key-soldier', 'category_slug': 'keys', 'item_type': 'key', 'rarity': 'common', 'icon': 'key_soldier', 'base_value': 15, 'is_consumable': True, 'opens_crate_slug': 'crate-soldier'},
    {'name': 'Klucz Oficerski', 'slug': 'key-officer', 'category_slug': 'keys', 'item_type': 'key', 'rarity': 'uncommon', 'icon': 'key_officer', 'base_value': 35, 'is_consumable': True, 'opens_crate_slug': 'crate-officer'},
    {'name': 'Klucz Generalny', 'slug': 'key-general', 'category_slug': 'keys', 'item_type': 'key', 'rarity': 'rare', 'icon': 'key_general', 'base_value': 80, 'is_consumable': True, 'opens_crate_slug': 'crate-general'},

    # --- Kosmetyki ---
    {'name': 'Kamuflaż Pustynny', 'slug': 'skin-desert-camo', 'category_slug': 'cosmetics', 'item_type': 'cosmetic', 'rarity': 'uncommon', 'icon': 'skin_desert', 'base_value': 40},
    {'name': 'Biel Arktyczna', 'slug': 'skin-arctic-white', 'category_slug': 'cosmetics', 'item_type': 'cosmetic', 'rarity': 'uncommon', 'icon': 'skin_arctic', 'base_value': 40},
    {'name': 'Szkarłat Bojowy', 'slug': 'skin-blood-red', 'category_slug': 'cosmetics', 'item_type': 'cosmetic', 'rarity': 'rare', 'icon': 'skin_blood_red', 'base_value': 80},
    {'name': 'Złoty Dowódca', 'slug': 'skin-golden-commander', 'category_slug': 'cosmetics', 'item_type': 'cosmetic', 'rarity': 'epic', 'icon': 'skin_golden', 'base_value': 200},
    {'name': 'Emblemat Czaszki', 'slug': 'emblem-skull', 'category_slug': 'cosmetics', 'item_type': 'cosmetic', 'rarity': 'common', 'icon': 'emblem_skull', 'base_value': 15},
    {'name': 'Emblemat Orła', 'slug': 'emblem-eagle', 'category_slug': 'cosmetics', 'item_type': 'cosmetic', 'rarity': 'uncommon', 'icon': 'emblem_eagle', 'base_value': 30},
    {'name': 'Emblemat Smoka', 'slug': 'emblem-dragon', 'category_slug': 'cosmetics', 'item_type': 'cosmetic', 'rarity': 'rare', 'icon': 'emblem_dragon', 'base_value': 60},
    {'name': 'Ślad Ognia', 'slug': 'effect-fire-trail', 'category_slug': 'cosmetics', 'item_type': 'cosmetic', 'rarity': 'epic', 'icon': 'effect_fire', 'base_value': 180},
    {'name': 'Efekt Błyskawicy', 'slug': 'effect-lightning', 'category_slug': 'cosmetics', 'item_type': 'cosmetic', 'rarity': 'legendary', 'icon': 'effect_lightning', 'base_value': 500},

    # --- Animacje VFX ---
    {
        'name': 'Ognisty Szturm',
        'slug': 'vfx-ognisty-szturm',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_attack',
        'rarity': 'epic',
        'base_value': 500,
        'cosmetic_params': {
            'trail': {
                'color': '#ff6b00',
                'opacity': 0.7,
                'width': 5,
                'glow': True,
                'glow_color': '#ff6b0044',
                'glow_width': 10,
                'particle_color': '#fbbf24',
                'particle_count': 8,
            },
            'impact_attack': {
                'duration': 800,
                'layers': [
                    {'type': 'ring', 'color': '#ff6b00', 'radius': [10, 160], 'opacity_start': 0.8, 'opacity_curve': 1.2, 'duration_pct': 1.0},
                    {'type': 'fill', 'color': '#ef4444', 'radius': [8, 100], 'opacity_start': 0.9, 'opacity_curve': 1.5, 'duration_pct': 0.6},
                    {'type': 'fill', 'color': '#fbbf24', 'radius': [4, 30], 'opacity_start': 1.0, 'opacity_curve': 1.0, 'duration_pct': 0.3},
                ],
            },
            'pulse': {'color': '#ff6b00', 'rings': 4, 'radius_expand': 60},
        },
    },
    {
        'name': 'Lodowy Podmuch',
        'slug': 'vfx-lodowy-podmuch',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_attack',
        'rarity': 'rare',
        'base_value': 300,
        'cosmetic_params': {
            'trail': {
                'color': '#38bdf8',
                'opacity': 0.6,
                'width': 3,
                'blur': 1.5,
                'glow': True,
                'glow_color': '#38bdf844',
                'glow_width': 8,
                'particle_color': '#a5f3fc',
            },
            'impact_attack': {
                'duration': 700,
                'layers': [
                    {'type': 'ring', 'color': '#22d3ee', 'radius': [8, 120], 'opacity_start': 0.7, 'opacity_curve': 1.3, 'duration_pct': 1.0},
                    {'type': 'fill', 'color': '#a5f3fc', 'radius': [6, 50], 'opacity_start': 0.85, 'opacity_curve': 1.5, 'duration_pct': 0.5},
                ],
            },
            'pulse': {'color': '#38bdf8'},
        },
    },
    {
        'name': 'Widmowy Ruch',
        'slug': 'vfx-widmowy-ruch',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_move',
        'rarity': 'uncommon',
        'base_value': 150,
        'cosmetic_params': {
            'trail': {
                'color': '#64748b',
                'opacity': 0.15,
                'width': 1,
                'line_style': 'dashed',
                'dash_pattern': [2, 6],
                'particles': 'none',
            },
            'impact_move': {
                'duration': 300,
                'layers': [
                    {'type': 'ring', 'color': '#94a3b8', 'radius': [4, 30], 'opacity_start': 0.4, 'opacity_curve': 1.5, 'duration_pct': 1.0},
                ],
            },
            'pulse': {'enabled': False},
        },
    },
    {
        'name': 'Królewski Szturm',
        'slug': 'vfx-krolewski-szturm',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_attack',
        'rarity': 'legendary',
        'base_value': 1000,
        'cosmetic_params': {
            'trail': {
                'color': '#a855f7',
                'width': 5,
                'glow': True,
                'glow_color': '#a855f744',
                'glow_width': 12,
                'particle_color': '#e9d5ff',
                'particle_count': 10,
                'particle_head_size': 6,
            },
            'impact_attack': {
                'duration': 1000,
                'layers': [
                    {'type': 'ring', 'color': '#a855f7', 'radius': [12, 180], 'opacity_start': 0.7, 'opacity_curve': 1.2, 'duration_pct': 1.0},
                    {'type': 'ring', 'color': '#e9d5ff', 'radius': [8, 120], 'opacity_start': 0.5, 'opacity_curve': 1.3, 'duration_pct': 0.8},
                    {'type': 'fill', 'color': '#7c3aed', 'radius': [6, 50], 'opacity_start': 0.9, 'opacity_curve': 1.5, 'duration_pct': 0.4},
                ],
            },
            'pulse': {'color': '#a855f7', 'rings': 4, 'radius_expand': 60},
        },
    },
    {
        'name': 'Nuklearny Chaos',
        'slug': 'vfx-nuklearny-chaos',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_nuke',
        'rarity': 'legendary',
        'base_value': 800,
        'cosmetic_params': {
            'trail': {
                'color': '#ef4444',
                'width': 8,
                'glow': True,
                'glow_color': '#ef444444',
                'glow_width': 14,
            },
            'impact_attack': {
                'duration': 2200,
                'layers': [
                    {'type': 'ring', 'color': '#ff6b00', 'radius': [12, 200], 'opacity_start': 0.8, 'opacity_curve': 1.0, 'duration_pct': 1.0},
                    {'type': 'ring', 'color': '#ef4444', 'radius': [10, 140], 'opacity_start': 0.9, 'opacity_curve': 1.2, 'duration_pct': 0.8},
                    {'type': 'fill', 'color': '#fbbf24', 'radius': [8, 60], 'opacity_start': 1.0, 'opacity_curve': 1.0, 'duration_pct': 0.5},
                    {'type': 'fill', 'color': '#ffffff', 'radius': [4, 25], 'opacity_start': 1.0, 'opacity_curve': 2.0, 'duration_pct': 0.2},
                ],
            },
        },
    },
    # --- Animacje VFX — szalone/kompletne zmiany ---
    {
        'name': 'Plazma',
        'slug': 'vfx-plazma',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_attack',
        'rarity': 'legendary',
        'base_value': 1200,
        'cosmetic_params': {
            'trail': {
                'color': '#06b6d4',
                'opacity': 0.95,
                'width': 7,
                'blur': 2.5,
                'length': 0.45,
                'glow': True,
                'glow_color': '#06b6d466',
                'glow_width': 18,
                'particles': 'circle',
                'particle_count': 14,
                'particle_spacing': 0.025,
                'particle_head_size': 9,
                'particle_decay': 0.5,
                'particle_decay_base': 6,
                'particle_min_size': 1.5,
                'particle_color': '#67e8f9',
            },
            'icon': {
                'size': 0.35,
                'breathe_amplitude': 0.12,
                'breathe_speed': 25,
            },
            'impact_attack': {
                'duration': 1200,
                'layers': [
                    {'type': 'ring', 'color': '#06b6d4', 'radius': [15, 200], 'opacity_start': 0.9, 'opacity_curve': 0.8, 'duration_pct': 1.0},
                    {'type': 'ring', 'color': '#67e8f9', 'radius': [12, 140], 'opacity_start': 0.7, 'opacity_curve': 1.0, 'duration_pct': 0.85},
                    {'type': 'fill', 'color': '#a5f3fc', 'radius': [8, 80], 'opacity_start': 0.85, 'opacity_curve': 1.5, 'duration_pct': 0.6},
                    {'type': 'fill', 'color': '#ecfeff', 'radius': [4, 30], 'opacity_start': 1.0, 'opacity_curve': 2.0, 'duration_pct': 0.25},
                ],
            },
            'pulse': {'color': '#06b6d4', 'rings': 5, 'radius_base': 6, 'radius_expand': 70, 'start_at': 0.45, 'opacity': 0.9},
        },
    },
    {
        'name': 'Nekromancja',
        'slug': 'vfx-nekromancja',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_attack',
        'rarity': 'legendary',
        'base_value': 1500,
        'cosmetic_params': {
            'trail': {
                'color': '#4ade80',
                'opacity': 0.4,
                'width': 2,
                'blur': 3,
                'length': 0.5,
                'glow': True,
                'glow_color': '#4ade8033',
                'glow_width': 20,
                'particles': 'circle',
                'particle_count': 16,
                'particle_spacing': 0.03,
                'particle_head_size': 4,
                'particle_decay': 0.15,
                'particle_decay_base': 3.5,
                'particle_min_size': 1,
                'particle_color': '#86efac',
            },
            'icon': {
                'size': 0.25,
                'breathe_amplitude': 0.15,
                'breathe_speed': 10,
                'fade_start': 0.85,
                'fade_blend_min': 0.3,
            },
            'impact_attack': {
                'duration': 1400,
                'layers': [
                    {'type': 'ring', 'color': '#166534', 'radius': [20, 180], 'opacity_start': 0.6, 'opacity_curve': 0.7, 'duration_pct': 1.0},
                    {'type': 'fill', 'color': '#4ade80', 'radius': [10, 120], 'opacity_start': 0.5, 'opacity_curve': 1.0, 'duration_pct': 0.8},
                    {'type': 'fill', 'color': '#bbf7d0', 'radius': [6, 50], 'opacity_start': 0.7, 'opacity_curve': 1.8, 'duration_pct': 0.4},
                    {'type': 'fill', 'color': '#dcfce7', 'radius': [3, 15], 'opacity_start': 1.0, 'opacity_curve': 3.0, 'duration_pct': 0.2},
                ],
            },
            'pulse': {'color': '#4ade80', 'rings': 6, 'radius_base': 4, 'radius_expand': 80, 'start_at': 0.4, 'opacity': 0.5},
        },
    },
    {
        'name': 'Cichy Zabójca',
        'slug': 'vfx-cichy-zabojca',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_attack',
        'rarity': 'epic',
        'base_value': 600,
        'cosmetic_params': {
            'trail': {
                'color': '#1e1b4b',
                'opacity': 0.12,
                'width': 1,
                'blur': 0,
                'length': 0.1,
                'line_style': 'none',
                'particles': 'circle',
                'particle_count': 3,
                'particle_spacing': 0.04,
                'particle_head_size': 3,
                'particle_decay': 0.5,
                'particle_decay_base': 2,
                'particle_min_size': 1,
                'particle_color': '#6366f1',
            },
            'icon': {
                'size': 0.15,
                'breathe_amplitude': 0.02,
                'fade_start': 0.5,
                'fade_blend_min': 0.2,
            },
            'impact_attack': {
                'duration': 250,
                'layers': [
                    {'type': 'ring', 'color': '#6366f1', 'radius': [3, 20], 'opacity_start': 0.6, 'opacity_curve': 2.5, 'duration_pct': 1.0},
                ],
            },
            'pulse': {'enabled': False},
        },
    },
    {
        'name': 'Supernowa',
        'slug': 'vfx-supernowa',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_attack',
        'rarity': 'legendary',
        'base_value': 2000,
        'cosmetic_params': {
            'trail': {
                'color': '#fbbf24',
                'opacity': 1.0,
                'width': 8,
                'blur': 3,
                'length': 0.6,
                'glow': True,
                'glow_color': '#fbbf2455',
                'glow_width': 24,
                'particles': 'circle',
                'particle_count': 18,
                'particle_spacing': 0.02,
                'particle_head_size': 10,
                'particle_decay': 0.4,
                'particle_decay_base': 7,
                'particle_min_size': 2,
                'particle_color': '#fef3c7',
            },
            'icon': {
                'size': 0.5,
                'breathe_amplitude': 0.18,
                'breathe_speed': 30,
                'fade_start': 0.9,
                'fade_blend_min': 0.8,
            },
            'impact_attack': {
                'duration': 2000,
                'layers': [
                    {'type': 'ring', 'color': '#fbbf24', 'radius': [20, 250], 'opacity_start': 1.0, 'opacity_curve': 0.6, 'duration_pct': 1.0},
                    {'type': 'ring', 'color': '#f59e0b', 'radius': [16, 180], 'opacity_start': 0.8, 'opacity_curve': 0.8, 'duration_pct': 0.9},
                    {'type': 'fill', 'color': '#fde68a', 'radius': [12, 120], 'opacity_start': 0.9, 'opacity_curve': 1.0, 'duration_pct': 0.7},
                    {'type': 'fill', 'color': '#fffbeb', 'radius': [8, 60], 'opacity_start': 1.0, 'opacity_curve': 1.5, 'duration_pct': 0.4},
                    {'type': 'fill', 'color': '#ffffff', 'radius': [4, 20], 'opacity_start': 1.0, 'opacity_curve': 3.0, 'duration_pct': 0.15},
                ],
            },
            'pulse': {'color': '#fbbf24', 'rings': 5, 'radius_base': 10, 'radius_expand': 90, 'start_at': 0.3, 'opacity': 1.0},
        },
    },
    {
        'name': 'Ciche Wody',
        'slug': 'vfx-ciche-wody',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_move',
        'rarity': 'rare',
        'base_value': 350,
        'cosmetic_params': {
            'trail': {
                'color': '#0ea5e9',
                'opacity': 0.3,
                'width': 4,
                'blur': 2,
                'length': 0.4,
                'glow': True,
                'glow_color': '#0ea5e922',
                'glow_width': 14,
                'particles': 'circle',
                'particle_count': 12,
                'particle_spacing': 0.035,
                'particle_head_size': 4,
                'particle_decay': 0.2,
                'particle_decay_base': 3,
                'particle_min_size': 1,
                'particle_color': '#7dd3fc',
            },
            'impact_move': {
                'duration': 500,
                'layers': [
                    {'type': 'ring', 'color': '#0ea5e9', 'radius': [8, 60], 'opacity_start': 0.5, 'opacity_curve': 1.5, 'duration_pct': 1.0},
                    {'type': 'ring', 'color': '#7dd3fc', 'radius': [5, 40], 'opacity_start': 0.4, 'opacity_curve': 2.0, 'duration_pct': 0.6},
                ],
            },
            'pulse': {'enabled': False},
        },
    },
    {
        'name': 'Piekielna Zagłada',
        'slug': 'vfx-piekielna-zaglada',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_nuke',
        'rarity': 'legendary',
        'base_value': 2500,
        'cosmetic_params': {
            'trail': {
                'color': '#dc2626',
                'opacity': 0.9,
                'width': 10,
                'blur': 4,
                'length': 0.15,
                'glow': True,
                'glow_color': '#dc262666',
                'glow_width': 22,
                'particles': 'circle',
                'particle_count': 15,
                'particle_spacing': 0.006,
                'particle_head_size': 8,
                'particle_decay': 0.4,
                'particle_decay_base': 6,
                'particle_min_size': 2,
                'particle_color': '#fca5a5',
            },
            'impact_attack': {
                'duration': 3000,
                'layers': [
                    {'type': 'ring', 'color': '#7f1d1d', 'radius': [25, 280], 'opacity_start': 0.8, 'opacity_curve': 0.5, 'duration_pct': 1.0},
                    {'type': 'ring', 'color': '#dc2626', 'radius': [20, 220], 'opacity_start': 0.9, 'opacity_curve': 0.7, 'duration_pct': 0.9},
                    {'type': 'fill', 'color': '#ef4444', 'radius': [15, 160], 'opacity_start': 0.85, 'opacity_curve': 1.0, 'duration_pct': 0.75},
                    {'type': 'fill', 'color': '#f97316', 'radius': [10, 100], 'opacity_start': 0.9, 'opacity_curve': 1.2, 'duration_pct': 0.55},
                    {'type': 'fill', 'color': '#fbbf24', 'radius': [6, 50], 'opacity_start': 1.0, 'opacity_curve': 1.5, 'duration_pct': 0.35},
                    {'type': 'fill', 'color': '#ffffff', 'radius': [3, 18], 'opacity_start': 1.0, 'opacity_curve': 3.0, 'duration_pct': 0.12},
                ],
            },
        },
    },
    {
        'name': 'Matryca',
        'slug': 'vfx-matryca',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_attack',
        'rarity': 'epic',
        'base_value': 700,
        'cosmetic_params': {
            'trail': {
                'color': '#22c55e',
                'opacity': 0.6,
                'width': 2,
                'blur': 0,
                'length': 0.35,
                'particles': 'circle',
                'particle_count': 20,
                'particle_spacing': 0.018,
                'particle_head_size': 3,
                'particle_decay': 0.1,
                'particle_decay_base': 2.5,
                'particle_min_size': 0.8,
                'particle_color': '#4ade80',
            },
            'icon': {
                'size': 0.18,
                'breathe_amplitude': 0.03,
                'breathe_speed': 40,
            },
            'impact_attack': {
                'duration': 400,
                'layers': [
                    {'type': 'ring', 'color': '#22c55e', 'radius': [5, 80], 'opacity_start': 0.7, 'opacity_curve': 2.0, 'duration_pct': 1.0},
                    {'type': 'ring', 'color': '#4ade80', 'radius': [3, 50], 'opacity_start': 0.5, 'opacity_curve': 2.5, 'duration_pct': 0.7},
                ],
            },
            'pulse': {'color': '#22c55e', 'rings': 2, 'radius_base': 4, 'radius_expand': 30, 'start_at': 0.7, 'opacity': 0.4},
        },
    },

    # --- vfx_move — dodatkowe ---
    {
        'name': 'Złoty Konwój',
        'slug': 'vfx-zloty-konwoj',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_move',
        'rarity': 'epic',
        'base_value': 450,
        'cosmetic_params': {
            'trail': {
                'color': '#fbbf24',
                'opacity': 0.5,
                'width': 4,
                'blur': 1,
                'length': 0.35,
                'glow': True,
                'glow_color': '#fbbf2433',
                'glow_width': 10,
                'particles': 'circle',
                'particle_count': 8,
                'particle_spacing': 0.04,
                'particle_head_size': 5,
                'particle_decay': 0.3,
                'particle_decay_base': 4,
                'particle_min_size': 1.5,
                'particle_color': '#fde68a',
            },
            'impact_move': {
                'duration': 500,
                'layers': [
                    {'type': 'ring', 'color': '#fbbf24', 'radius': [6, 50], 'opacity_start': 0.6, 'opacity_curve': 1.5, 'duration_pct': 1.0},
                    {'type': 'fill', 'color': '#fef3c7', 'radius': [4, 20], 'opacity_start': 0.7, 'opacity_curve': 2.0, 'duration_pct': 0.4},
                ],
            },
            'pulse': {'enabled': False},
        },
    },
    {
        'name': 'Teleportacja',
        'slug': 'vfx-teleportacja',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_move',
        'rarity': 'legendary',
        'base_value': 800,
        'cosmetic_params': {
            'trail': {
                'color': '#a855f7',
                'opacity': 0.08,
                'width': 1,
                'blur': 0,
                'length': 0.05,
                'line_style': 'none',
                'particles': 'circle',
                'particle_count': 5,
                'particle_spacing': 0.01,
                'particle_head_size': 2,
                'particle_decay': 0.3,
                'particle_decay_base': 1.5,
                'particle_min_size': 0.5,
                'particle_color': '#c084fc',
            },
            'icon': {
                'size': 0.15,
                'breathe_amplitude': 0.2,
                'breathe_speed': 50,
                'fade_start': 0.3,
                'fade_blend_min': 0.1,
            },
            'impact_move': {
                'duration': 350,
                'layers': [
                    {'type': 'ring', 'color': '#a855f7', 'radius': [2, 40], 'opacity_start': 0.8, 'opacity_curve': 3.0, 'duration_pct': 1.0},
                    {'type': 'fill', 'color': '#e9d5ff', 'radius': [2, 15], 'opacity_start': 1.0, 'opacity_curve': 3.0, 'duration_pct': 0.3},
                ],
            },
            'pulse': {'enabled': False},
        },
    },
    {
        'name': 'Burza Piaskowa',
        'slug': 'vfx-burza-piaskowa',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_move',
        'rarity': 'rare',
        'base_value': 250,
        'cosmetic_params': {
            'trail': {
                'color': '#d97706',
                'opacity': 0.45,
                'width': 6,
                'blur': 2,
                'length': 0.4,
                'glow': True,
                'glow_color': '#d9770622',
                'glow_width': 16,
                'particles': 'circle',
                'particle_count': 14,
                'particle_spacing': 0.03,
                'particle_head_size': 5,
                'particle_decay': 0.25,
                'particle_decay_base': 4,
                'particle_min_size': 1.5,
                'particle_color': '#fcd34d',
            },
            'impact_move': {
                'duration': 600,
                'layers': [
                    {'type': 'ring', 'color': '#d97706', 'radius': [10, 70], 'opacity_start': 0.5, 'opacity_curve': 1.2, 'duration_pct': 1.0},
                    {'type': 'fill', 'color': '#fcd34d', 'radius': [6, 40], 'opacity_start': 0.4, 'opacity_curve': 1.8, 'duration_pct': 0.5},
                ],
            },
            'pulse': {'enabled': False},
        },
    },

    # --- vfx_nuke — dodatkowe ---
    {
        'name': 'Lodowa Apokalipsa',
        'slug': 'vfx-lodowa-apokalipsa',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_nuke',
        'rarity': 'legendary',
        'base_value': 1800,
        'cosmetic_params': {
            'trail': {
                'color': '#0ea5e9',
                'opacity': 0.8,
                'width': 7,
                'blur': 2,
                'length': 0.18,
                'glow': True,
                'glow_color': '#0ea5e955',
                'glow_width': 16,
                'particles': 'circle',
                'particle_count': 14,
                'particle_spacing': 0.007,
                'particle_head_size': 7,
                'particle_color': '#bae6fd',
            },
            'impact_attack': {
                'duration': 2500,
                'layers': [
                    {'type': 'ring', 'color': '#0c4a6e', 'radius': [20, 260], 'opacity_start': 0.7, 'opacity_curve': 0.6, 'duration_pct': 1.0},
                    {'type': 'ring', 'color': '#0ea5e9', 'radius': [16, 200], 'opacity_start': 0.8, 'opacity_curve': 0.8, 'duration_pct': 0.85},
                    {'type': 'fill', 'color': '#38bdf8', 'radius': [12, 140], 'opacity_start': 0.85, 'opacity_curve': 1.0, 'duration_pct': 0.65},
                    {'type': 'fill', 'color': '#bae6fd', 'radius': [8, 70], 'opacity_start': 0.9, 'opacity_curve': 1.5, 'duration_pct': 0.4},
                    {'type': 'fill', 'color': '#f0f9ff', 'radius': [4, 25], 'opacity_start': 1.0, 'opacity_curve': 2.5, 'duration_pct': 0.15},
                ],
            },
        },
    },
    {
        'name': 'Czarna Dziura',
        'slug': 'vfx-czarna-dziura',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_nuke',
        'rarity': 'legendary',
        'base_value': 3000,
        'cosmetic_params': {
            'trail': {
                'color': '#7c3aed',
                'opacity': 0.7,
                'width': 5,
                'blur': 4,
                'length': 0.2,
                'glow': True,
                'glow_color': '#7c3aed44',
                'glow_width': 20,
                'particles': 'circle',
                'particle_count': 10,
                'particle_spacing': 0.008,
                'particle_head_size': 6,
                'particle_decay': 0.4,
                'particle_decay_base': 5,
                'particle_min_size': 1,
                'particle_color': '#c4b5fd',
            },
            'impact_attack': {
                'duration': 2800,
                'layers': [
                    {'type': 'ring', 'color': '#2e1065', 'radius': [30, 300], 'opacity_start': 0.6, 'opacity_curve': 0.4, 'duration_pct': 1.0},
                    {'type': 'ring', 'color': '#7c3aed', 'radius': [25, 240], 'opacity_start': 0.7, 'opacity_curve': 0.6, 'duration_pct': 0.9},
                    {'type': 'fill', 'color': '#8b5cf6', 'radius': [18, 160], 'opacity_start': 0.8, 'opacity_curve': 0.8, 'duration_pct': 0.7},
                    {'type': 'fill', 'color': '#a78bfa', 'radius': [12, 90], 'opacity_start': 0.85, 'opacity_curve': 1.2, 'duration_pct': 0.5},
                    {'type': 'fill', 'color': '#ddd6fe', 'radius': [6, 40], 'opacity_start': 0.95, 'opacity_curve': 2.0, 'duration_pct': 0.25},
                    {'type': 'fill', 'color': '#ffffff', 'radius': [3, 12], 'opacity_start': 1.0, 'opacity_curve': 4.0, 'duration_pct': 0.08},
                ],
            },
        },
    },
    {
        'name': 'Toksyczna Mgła',
        'slug': 'vfx-toksyczna-mgla',
        'category_slug': 'animacje',
        'item_type': 'cosmetic',
        'asset_key': 'vfx_nuke',
        'rarity': 'epic',
        'base_value': 900,
        'cosmetic_params': {
            'trail': {
                'color': '#84cc16',
                'opacity': 0.5,
                'width': 9,
                'blur': 5,
                'length': 0.25,
                'glow': True,
                'glow_color': '#84cc1633',
                'glow_width': 24,
                'particles': 'circle',
                'particle_count': 16,
                'particle_spacing': 0.006,
                'particle_head_size': 6,
                'particle_decay': 0.3,
                'particle_decay_base': 5,
                'particle_min_size': 2,
                'particle_color': '#bef264',
            },
            'impact_attack': {
                'duration': 2400,
                'layers': [
                    {'type': 'fill', 'color': '#365314', 'radius': [20, 240], 'opacity_start': 0.5, 'opacity_curve': 0.5, 'duration_pct': 1.0},
                    {'type': 'fill', 'color': '#84cc16', 'radius': [15, 180], 'opacity_start': 0.6, 'opacity_curve': 0.8, 'duration_pct': 0.8},
                    {'type': 'fill', 'color': '#bef264', 'radius': [10, 100], 'opacity_start': 0.7, 'opacity_curve': 1.2, 'duration_pct': 0.55},
                    {'type': 'fill', 'color': '#ecfccb', 'radius': [6, 40], 'opacity_start': 0.8, 'opacity_curve': 2.0, 'duration_pct': 0.25},
                ],
            },
        },
    },
]

RECIPES = [
    # -------------------------------------------------------------------------
    # Blueprinty budynków — Koszary (6 receptur: Lvl1, Lvl2 upgrade, Lvl3 upgrade)
    # -------------------------------------------------------------------------
    {'name': 'Stwórz Blueprint Koszary Lvl 1', 'slug': 'craft-bp-barracks-1', 'result_slug': 'bp-barracks-1', 'gold_cost': 10,
     'ingredients': [('steel-scrap', 5), ('gunpowder', 2)]},
    {'name': 'Ulepsz Blueprint Koszary na Lvl 2', 'slug': 'craft-bp-barracks-2', 'result_slug': 'bp-barracks-2', 'gold_cost': 30,
     'ingredients': [('bp-barracks-1', 1), ('steel-scrap', 5), ('gunpowder', 3)]},
    {'name': 'Ulepsz Blueprint Koszary na Lvl 3', 'slug': 'craft-bp-barracks-3', 'result_slug': 'bp-barracks-3', 'gold_cost': 60,
     'ingredients': [('bp-barracks-2', 1), ('steel-scrap', 10), ('command-protocol', 2)]},

    # Fabryka
    {'name': 'Stwórz Blueprint Fabryka Lvl 1', 'slug': 'craft-bp-factory-1', 'result_slug': 'bp-factory-1', 'gold_cost': 15,
     'ingredients': [('steel-scrap', 6), ('fuel-cell', 2)]},
    {'name': 'Ulepsz Blueprint Fabryka na Lvl 2', 'slug': 'craft-bp-factory-2', 'result_slug': 'bp-factory-2', 'gold_cost': 40,
     'ingredients': [('bp-factory-1', 1), ('steel-scrap', 8), ('fuel-cell', 3)]},
    {'name': 'Ulepsz Blueprint Fabryka na Lvl 3', 'slug': 'craft-bp-factory-3', 'result_slug': 'bp-factory-3', 'gold_cost': 80,
     'ingredients': [('bp-factory-2', 1), ('steel-scrap', 12), ('plasma-core', 1)]},

    # Wieża obronna
    {'name': 'Stwórz Blueprint Wieża Lvl 1', 'slug': 'craft-bp-tower-1', 'result_slug': 'bp-tower-1', 'gold_cost': 12,
     'ingredients': [('steel-scrap', 5), ('circuit-board', 2)]},
    {'name': 'Ulepsz Blueprint Wieża na Lvl 2', 'slug': 'craft-bp-tower-2', 'result_slug': 'bp-tower-2', 'gold_cost': 35,
     'ingredients': [('bp-tower-1', 1), ('steel-scrap', 6), ('optic-fiber', 2)]},
    {'name': 'Ulepsz Blueprint Wieża na Lvl 3', 'slug': 'craft-bp-tower-3', 'result_slug': 'bp-tower-3', 'gold_cost': 65,
     'ingredients': [('bp-tower-2', 1), ('steel-scrap', 10), ('command-protocol', 2)]},

    # Port
    {'name': 'Stwórz Blueprint Port Lvl 1', 'slug': 'craft-bp-port-1', 'result_slug': 'bp-port-1', 'gold_cost': 25,
     'ingredients': [('steel-scrap', 8), ('fuel-cell', 3)]},
    {'name': 'Ulepsz Blueprint Port na Lvl 2', 'slug': 'craft-bp-port-2', 'result_slug': 'bp-port-2', 'gold_cost': 55,
     'ingredients': [('bp-port-1', 1), ('steel-scrap', 10), ('optic-fiber', 3)]},
    {'name': 'Ulepsz Blueprint Port na Lvl 3', 'slug': 'craft-bp-port-3', 'result_slug': 'bp-port-3', 'gold_cost': 100,
     'ingredients': [('bp-port-2', 1), ('command-protocol', 3), ('plasma-core', 1)]},

    # Lotnisko
    {'name': 'Stwórz Blueprint Lotnisko Lvl 1', 'slug': 'craft-bp-carrier-1', 'result_slug': 'bp-carrier-1', 'gold_cost': 25,
     'ingredients': [('circuit-board', 6), ('fuel-cell', 3)]},
    {'name': 'Ulepsz Blueprint Lotnisko na Lvl 2', 'slug': 'craft-bp-carrier-2', 'result_slug': 'bp-carrier-2', 'gold_cost': 55,
     'ingredients': [('bp-carrier-1', 1), ('circuit-board', 8), ('optic-fiber', 3)]},
    {'name': 'Ulepsz Blueprint Lotnisko na Lvl 3', 'slug': 'craft-bp-carrier-3', 'result_slug': 'bp-carrier-3', 'gold_cost': 100,
     'ingredients': [('bp-carrier-2', 1), ('command-protocol', 3), ('plasma-core', 1)]},

    # Elektrownia
    {'name': 'Stwórz Blueprint Elektrownia Lvl 1', 'slug': 'craft-bp-radar-1', 'result_slug': 'bp-radar-1', 'gold_cost': 10,
     'ingredients': [('circuit-board', 5), ('optic-fiber', 2)]},
    {'name': 'Ulepsz Blueprint Elektrownia na Lvl 2', 'slug': 'craft-bp-radar-2', 'result_slug': 'bp-radar-2', 'gold_cost': 30,
     'ingredients': [('bp-radar-1', 1), ('circuit-board', 6), ('optic-fiber', 3)]},
    {'name': 'Ulepsz Blueprint Elektrownia na Lvl 3', 'slug': 'craft-bp-radar-3', 'result_slug': 'bp-radar-3', 'gold_cost': 60,
     'ingredients': [('bp-radar-2', 1), ('command-protocol', 2), ('plasma-core', 1)]},

    # -------------------------------------------------------------------------
    # Blueprinty jednostek — Czołg
    # -------------------------------------------------------------------------
    {'name': 'Stwórz Blueprint Czołg Lvl 1', 'slug': 'craft-bp-tank-1', 'result_slug': 'bp-tank-1', 'gold_cost': 20,
     'ingredients': [('steel-scrap', 8), ('fuel-cell', 2)]},
    {'name': 'Ulepsz Blueprint Czołg na Lvl 2', 'slug': 'craft-bp-tank-2', 'result_slug': 'bp-tank-2', 'gold_cost': 50,
     'ingredients': [('bp-tank-1', 1), ('steel-scrap', 12), ('fuel-cell', 4), ('gunpowder', 3)]},
    {'name': 'Ulepsz Blueprint Czołg na Lvl 3', 'slug': 'craft-bp-tank-3', 'result_slug': 'bp-tank-3', 'gold_cost': 100,
     'ingredients': [('bp-tank-2', 1), ('steel-scrap', 18), ('plasma-core', 2), ('command-protocol', 2)]},

    # Blueprinty jednostek — Okręt
    {'name': 'Stwórz Blueprint Okręt Lvl 1', 'slug': 'craft-bp-ship-1', 'result_slug': 'bp-ship-1', 'gold_cost': 40,
     'ingredients': [('steel-scrap', 10), ('optic-fiber', 3), ('fuel-cell', 3)]},
    {'name': 'Ulepsz Blueprint Okręt na Lvl 2', 'slug': 'craft-bp-ship-2', 'result_slug': 'bp-ship-2', 'gold_cost': 90,
     'ingredients': [('bp-ship-1', 1), ('steel-scrap', 15), ('optic-fiber', 5), ('plasma-core', 1)]},
    {'name': 'Ulepsz Blueprint Okręt na Lvl 3', 'slug': 'craft-bp-ship-3', 'result_slug': 'bp-ship-3', 'gold_cost': 180,
     'ingredients': [('bp-ship-2', 1), ('command-protocol', 4), ('plasma-core', 2), ('artifact-fragment', 1)]},

    # Blueprinty jednostek — Myśliwiec
    {'name': 'Stwórz Blueprint Myśliwiec Lvl 1', 'slug': 'craft-bp-fighter-1', 'result_slug': 'bp-fighter-1', 'gold_cost': 35,
     'ingredients': [('circuit-board', 8), ('fuel-cell', 3), ('optic-fiber', 2)]},
    {'name': 'Ulepsz Blueprint Myśliwiec na Lvl 2', 'slug': 'craft-bp-fighter-2', 'result_slug': 'bp-fighter-2', 'gold_cost': 80,
     'ingredients': [('bp-fighter-1', 1), ('circuit-board', 12), ('optic-fiber', 4), ('plasma-core', 1)]},
    {'name': 'Ulepsz Blueprint Myśliwiec na Lvl 3', 'slug': 'craft-bp-fighter-3', 'result_slug': 'bp-fighter-3', 'gold_cost': 160,
     'ingredients': [('bp-fighter-2', 1), ('command-protocol', 4), ('plasma-core', 2), ('artifact-fragment', 1)]},

    # -------------------------------------------------------------------------
    # Pakiety taktyczne — Tarcza
    # -------------------------------------------------------------------------
    {'name': 'Stwórz Pakiet Tarcza Lvl 1', 'slug': 'craft-pkg-shield-1', 'result_slug': 'pkg-shield-1', 'gold_cost': 0,
     'ingredients': [('steel-scrap', 3), ('circuit-board', 2)]},
    {'name': 'Ulepsz Pakiet Tarcza na Lvl 2', 'slug': 'craft-pkg-shield-2', 'result_slug': 'pkg-shield-2', 'gold_cost': 30,
     'ingredients': [('pkg-shield-1', 1), ('steel-scrap', 5), ('optic-fiber', 2)]},
    {'name': 'Ulepsz Pakiet Tarcza na Lvl 3', 'slug': 'craft-pkg-shield-3', 'result_slug': 'pkg-shield-3', 'gold_cost': 70,
     'ingredients': [('pkg-shield-2', 1), ('command-protocol', 3), ('plasma-core', 1)]},

    # Wirus
    {'name': 'Stwórz Pakiet Wirus Lvl 1', 'slug': 'craft-pkg-virus-1', 'result_slug': 'pkg-virus-1', 'gold_cost': 20,
     'ingredients': [('circuit-board', 5), ('command-protocol', 1)]},
    {'name': 'Ulepsz Pakiet Wirus na Lvl 2', 'slug': 'craft-pkg-virus-2', 'result_slug': 'pkg-virus-2', 'gold_cost': 50,
     'ingredients': [('pkg-virus-1', 1), ('circuit-board', 8), ('command-protocol', 2)]},
    {'name': 'Ulepsz Pakiet Wirus na Lvl 3', 'slug': 'craft-pkg-virus-3', 'result_slug': 'pkg-virus-3', 'gold_cost': 110,
     'ingredients': [('pkg-virus-2', 1), ('command-protocol', 4), ('plasma-core', 1)]},

    # Uderzenie Nuklearne
    {'name': 'Stwórz Pakiet Uderzenie Nuklearne Lvl 1', 'slug': 'craft-pkg-nuke-1', 'result_slug': 'pkg-nuke-1', 'gold_cost': 60,
     'ingredients': [('gunpowder', 8), ('plasma-core', 1)]},
    {'name': 'Ulepsz Pakiet Uderzenie Nuklearne na Lvl 2', 'slug': 'craft-pkg-nuke-2', 'result_slug': 'pkg-nuke-2', 'gold_cost': 140,
     'ingredients': [('pkg-nuke-1', 1), ('gunpowder', 12), ('plasma-core', 2)]},
    {'name': 'Ulepsz Pakiet Uderzenie Nuklearne na Lvl 3', 'slug': 'craft-pkg-nuke-3', 'result_slug': 'pkg-nuke-3', 'gold_cost': 300,
     'ingredients': [('pkg-nuke-2', 1), ('plasma-core', 3), ('artifact-fragment', 1)]},

    # Wywiad
    {'name': 'Stwórz Pakiet Wywiad Lvl 1', 'slug': 'craft-pkg-recon-1', 'result_slug': 'pkg-recon-1', 'gold_cost': 10,
     'ingredients': [('steel-scrap', 4), ('optic-fiber', 2)]},
    {'name': 'Ulepsz Pakiet Wywiad na Lvl 2', 'slug': 'craft-pkg-recon-2', 'result_slug': 'pkg-recon-2', 'gold_cost': 30,
     'ingredients': [('pkg-recon-1', 1), ('optic-fiber', 3), ('fuel-cell', 2)]},
    {'name': 'Ulepsz Pakiet Wywiad na Lvl 3', 'slug': 'craft-pkg-recon-3', 'result_slug': 'pkg-recon-3', 'gold_cost': 65,
     'ingredients': [('pkg-recon-2', 1), ('optic-fiber', 5), ('command-protocol', 2)]},

    # Pobór
    {'name': 'Stwórz Pakiet Pobór Lvl 1', 'slug': 'craft-pkg-conscription-1', 'result_slug': 'pkg-conscription-1', 'gold_cost': 8,
     'ingredients': [('gunpowder', 4), ('steel-scrap', 3)]},
    {'name': 'Ulepsz Pakiet Pobór na Lvl 2', 'slug': 'craft-pkg-conscription-2', 'result_slug': 'pkg-conscription-2', 'gold_cost': 25,
     'ingredients': [('pkg-conscription-1', 1), ('gunpowder', 5), ('command-protocol', 1)]},
    {'name': 'Ulepsz Pakiet Pobór na Lvl 3', 'slug': 'craft-pkg-conscription-3', 'result_slug': 'pkg-conscription-3', 'gold_cost': 60,
     'ingredients': [('pkg-conscription-2', 1), ('gunpowder', 8), ('command-protocol', 3)]},

    # -------------------------------------------------------------------------
    # Bonusy — Mobilizacja
    # -------------------------------------------------------------------------
    {'name': 'Stwórz Bonus Mobilizacja Lvl 1', 'slug': 'craft-boost-mobilization-1', 'result_slug': 'boost-mobilization-1', 'gold_cost': 8,
     'ingredients': [('steel-scrap', 3), ('fuel-cell', 1)]},
    {'name': 'Ulepsz Bonus Mobilizacja na Lvl 2', 'slug': 'craft-boost-mobilization-2', 'result_slug': 'boost-mobilization-2', 'gold_cost': 20,
     'ingredients': [('boost-mobilization-1', 1), ('steel-scrap', 5), ('fuel-cell', 2)]},
    {'name': 'Ulepsz Bonus Mobilizacja na Lvl 3', 'slug': 'craft-boost-mobilization-3', 'result_slug': 'boost-mobilization-3', 'gold_cost': 45,
     'ingredients': [('boost-mobilization-2', 1), ('fuel-cell', 4), ('command-protocol', 1)]},

    # Fortyfikacja
    {'name': 'Stwórz Bonus Fortyfikacja Lvl 1', 'slug': 'craft-boost-fortification-1', 'result_slug': 'boost-fortification-1', 'gold_cost': 8,
     'ingredients': [('steel-scrap', 4), ('gunpowder', 1)]},
    {'name': 'Ulepsz Bonus Fortyfikacja na Lvl 2', 'slug': 'craft-boost-fortification-2', 'result_slug': 'boost-fortification-2', 'gold_cost': 20,
     'ingredients': [('boost-fortification-1', 1), ('steel-scrap', 6), ('gunpowder', 2)]},
    {'name': 'Ulepsz Bonus Fortyfikacja na Lvl 3', 'slug': 'craft-boost-fortification-3', 'result_slug': 'boost-fortification-3', 'gold_cost': 45,
     'ingredients': [('boost-fortification-2', 1), ('gunpowder', 4), ('command-protocol', 1)]},

    # Ekonomia Wojenna
    {'name': 'Stwórz Bonus Ekonomia Wojenna Lvl 1', 'slug': 'craft-boost-war-economy-1', 'result_slug': 'boost-war-economy-1', 'gold_cost': 14,
     'ingredients': [('circuit-board', 4), ('fuel-cell', 2)]},
    {'name': 'Ulepsz Bonus Ekonomia Wojenna na Lvl 2', 'slug': 'craft-boost-war-economy-2', 'result_slug': 'boost-war-economy-2', 'gold_cost': 35,
     'ingredients': [('boost-war-economy-1', 1), ('circuit-board', 5), ('fuel-cell', 3)]},
    {'name': 'Ulepsz Bonus Ekonomia Wojenna na Lvl 3', 'slug': 'craft-boost-war-economy-3', 'result_slug': 'boost-war-economy-3', 'gold_cost': 80,
     'ingredients': [('boost-war-economy-2', 1), ('optic-fiber', 4), ('plasma-core', 1)]},

    # Blitzkrieg
    {'name': 'Stwórz Bonus Blitzkrieg Lvl 1', 'slug': 'craft-boost-blitzkrieg-1', 'result_slug': 'boost-blitzkrieg-1', 'gold_cost': 14,
     'ingredients': [('gunpowder', 4), ('fuel-cell', 2)]},
    {'name': 'Ulepsz Bonus Blitzkrieg na Lvl 2', 'slug': 'craft-boost-blitzkrieg-2', 'result_slug': 'boost-blitzkrieg-2', 'gold_cost': 35,
     'ingredients': [('boost-blitzkrieg-1', 1), ('gunpowder', 5), ('fuel-cell', 3)]},
    {'name': 'Ulepsz Bonus Blitzkrieg na Lvl 3', 'slug': 'craft-boost-blitzkrieg-3', 'result_slug': 'boost-blitzkrieg-3', 'gold_cost': 80,
     'ingredients': [('boost-blitzkrieg-2', 1), ('gunpowder', 8), ('plasma-core', 1)]},

    # -------------------------------------------------------------------------
    # Kosmetyki
    # -------------------------------------------------------------------------
    {'name': 'Stwórz Kamuflaż Pustynny', 'slug': 'craft-skin-desert', 'result_slug': 'skin-desert-camo', 'gold_cost': 20,
     'ingredients': [('steel-scrap', 5), ('fuel-cell', 2)]},
    {'name': 'Stwórz Szkarłat Bojowy', 'slug': 'craft-skin-blood-red', 'result_slug': 'skin-blood-red', 'gold_cost': 50,
     'ingredients': [('plasma-core', 1), ('gunpowder', 5)]},
    {'name': 'Stwórz Złoty Dowódca', 'slug': 'craft-skin-golden', 'result_slug': 'skin-golden-commander', 'gold_cost': 150,
     'ingredients': [('plasma-core', 2), ('artifact-fragment', 1), ('command-protocol', 3)]},
]


class Command(BaseCommand):
    help = "Seed economy data: item categories, items, and crafting recipes"

    def handle(self, *args, **options):
        from apps.crafting.models import Recipe, RecipeIngredient

        # Categories
        cat_map = {}
        for cat_data in CATEGORIES:
            obj, created = ItemCategory.objects.update_or_create(
                slug=cat_data['slug'],
                defaults={'name': cat_data['name'], 'order': cat_data['order']},
            )
            cat_map[cat_data['slug']] = obj
            status = "created" if created else "updated"
            self.stdout.write(f"  ItemCategory {obj.name}: {status}")

        # Items (first pass: all except key->crate FK)
        item_map = {}
        crate_links = {}  # key_slug -> crate_slug

        for item_data in ITEMS:
            cat_slug = item_data.get('category_slug')
            opens_crate_slug = item_data.get('opens_crate_slug')

            defaults = {
                'name': item_data['name'],
                'category': cat_map[cat_slug],
                'item_type': item_data['item_type'],
                'rarity': item_data['rarity'],
                'icon': item_data.get('icon', ''),
                'asset_key': item_data.get('asset_key', ''),
                'base_value': item_data.get('base_value', 0),
                'is_consumable': item_data.get('is_consumable', False),
                'is_tradeable': item_data.get('is_tradeable', True),
                'blueprint_ref': item_data.get('blueprint_ref', ''),
                'level': item_data.get('level', 1),
            }
            if 'crate_loot_table' in item_data:
                defaults['crate_loot_table'] = item_data['crate_loot_table']
            if 'boost_params' in item_data:
                defaults['boost_params'] = item_data['boost_params']
            if 'cosmetic_params' in item_data:
                defaults['cosmetic_params'] = item_data['cosmetic_params']

            obj, created = Item.objects.update_or_create(
                slug=item_data['slug'],
                defaults=defaults,
            )
            item_map[item_data['slug']] = obj
            status = "created" if created else "updated"
            self.stdout.write(f"  Item {obj.name}: {status}")

            if opens_crate_slug:
                crate_links[item_data['slug']] = opens_crate_slug

        # Second pass: link keys to crates
        for key_slug, crate_slug in crate_links.items():
            key_item = item_map.get(key_slug)
            crate_item = item_map.get(crate_slug)
            if key_item and crate_item:
                key_item.opens_crate = crate_item
                key_item.save(update_fields=['opens_crate'])
                self.stdout.write(f"  Linked {key_slug} -> {crate_slug}")

        # Recipes
        for idx, recipe_data in enumerate(RECIPES):
            result_item = item_map.get(recipe_data['result_slug'])
            if not result_item:
                self.stdout.write(self.style.WARNING(f"  Skipping recipe {recipe_data['slug']}: result item not found"))
                continue

            recipe, created = Recipe.objects.update_or_create(
                slug=recipe_data['slug'],
                defaults={
                    'name': recipe_data['name'],
                    'result_item': result_item,
                    'result_quantity': 1,
                    'gold_cost': recipe_data['gold_cost'],
                    'order': idx,
                },
            )

            RecipeIngredient.objects.filter(recipe=recipe).delete()
            for ing_slug, ing_qty in recipe_data['ingredients']:
                ing_item = item_map.get(ing_slug)
                if ing_item:
                    RecipeIngredient.objects.create(
                        recipe=recipe,
                        item=ing_item,
                        quantity=ing_qty,
                    )

            status = "created" if created else "updated"
            self.stdout.write(f"  Recipe {recipe.name}: {status}")

        self.stdout.write(self.style.SUCCESS("Economy seed complete!"))
