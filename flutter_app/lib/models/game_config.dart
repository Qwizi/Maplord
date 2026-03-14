class BuildingType {
  final int id;
  final String name;
  final String slug;
  final String assetKey;
  final String description;
  final String icon;
  final int cost;
  final int currencyCost;
  final int buildTimeTicks;
  final int maxPerRegion;
  final bool requiresCoastal;
  final double defenseBonus;
  final int visionRange;
  final double unitGenerationBonus;
  final double currencyGenerationBonus;
  final int order;

  BuildingType({
    required this.id,
    required this.name,
    required this.slug,
    required this.assetKey,
    required this.description,
    required this.icon,
    required this.cost,
    required this.currencyCost,
    required this.buildTimeTicks,
    required this.maxPerRegion,
    required this.requiresCoastal,
    required this.defenseBonus,
    required this.visionRange,
    required this.unitGenerationBonus,
    required this.currencyGenerationBonus,
    required this.order,
  });

  factory BuildingType.fromJson(Map<String, dynamic> json) => BuildingType(
    id: json['id'] as int,
    name: json['name'] as String,
    slug: json['slug'] as String,
    assetKey: json['asset_key'] as String,
    description: json['description'] as String,
    icon: json['icon'] as String,
    cost: json['cost'] as int,
    currencyCost: json['currency_cost'] as int,
    buildTimeTicks: json['build_time_ticks'] as int,
    maxPerRegion: json['max_per_region'] as int,
    requiresCoastal: json['requires_coastal'] as bool,
    defenseBonus: (json['defense_bonus'] as num).toDouble(),
    visionRange: json['vision_range'] as int,
    unitGenerationBonus: (json['unit_generation_bonus'] as num).toDouble(),
    currencyGenerationBonus: (json['currency_generation_bonus'] as num).toDouble(),
    order: json['order'] as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'asset_key': assetKey,
    'description': description,
    'icon': icon,
    'cost': cost,
    'currency_cost': currencyCost,
    'build_time_ticks': buildTimeTicks,
    'max_per_region': maxPerRegion,
    'requires_coastal': requiresCoastal,
    'defense_bonus': defenseBonus,
    'vision_range': visionRange,
    'unit_generation_bonus': unitGenerationBonus,
    'currency_generation_bonus': currencyGenerationBonus,
    'order': order,
  };
}

class UnitType {
  final int id;
  final String name;
  final String slug;
  final String assetKey;
  final String description;
  final String icon;
  final int attack;
  final int defense;
  final int speed;
  final int attackRange;
  final int seaRange;
  final double seaHopDistanceKm;
  final String movementType;
  final String? producedBySlug;
  final int productionCost;
  final int productionTimeTicks;
  final int manpowerCost;
  final int order;

  UnitType({
    required this.id,
    required this.name,
    required this.slug,
    required this.assetKey,
    required this.description,
    required this.icon,
    required this.attack,
    required this.defense,
    required this.speed,
    required this.attackRange,
    required this.seaRange,
    required this.seaHopDistanceKm,
    required this.movementType,
    this.producedBySlug,
    required this.productionCost,
    required this.productionTimeTicks,
    required this.manpowerCost,
    required this.order,
  });

  factory UnitType.fromJson(Map<String, dynamic> json) => UnitType(
    id: json['id'] as int,
    name: json['name'] as String,
    slug: json['slug'] as String,
    assetKey: json['asset_key'] as String,
    description: json['description'] as String,
    icon: json['icon'] as String,
    attack: json['attack'] as int,
    defense: json['defense'] as int,
    speed: json['speed'] as int,
    attackRange: json['attack_range'] as int,
    seaRange: json['sea_range'] as int,
    seaHopDistanceKm: (json['sea_hop_distance_km'] as num).toDouble(),
    movementType: json['movement_type'] as String,
    producedBySlug: json['produced_by_slug'] as String?,
    productionCost: json['production_cost'] as int,
    productionTimeTicks: json['production_time_ticks'] as int,
    manpowerCost: json['manpower_cost'] as int,
    order: json['order'] as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'asset_key': assetKey,
    'description': description,
    'icon': icon,
    'attack': attack,
    'defense': defense,
    'speed': speed,
    'attack_range': attackRange,
    'sea_range': seaRange,
    'sea_hop_distance_km': seaHopDistanceKm,
    'movement_type': movementType,
    'produced_by_slug': producedBySlug,
    'production_cost': productionCost,
    'production_time_ticks': productionTimeTicks,
    'manpower_cost': manpowerCost,
    'order': order,
  };
}

class AbilityType {
  final int id;
  final String name;
  final String slug;
  final String assetKey;
  final String description;
  final String icon;
  final String soundKey;
  final String targetType;
  final int range;
  final int currencyCost;
  final int cooldownTicks;
  final int damage;
  final int effectDurationTicks;
  final Map<String, num> effectParams;
  final int order;

  AbilityType({
    required this.id,
    required this.name,
    required this.slug,
    required this.assetKey,
    required this.description,
    required this.icon,
    required this.soundKey,
    required this.targetType,
    required this.range,
    required this.currencyCost,
    required this.cooldownTicks,
    required this.damage,
    required this.effectDurationTicks,
    required this.effectParams,
    required this.order,
  });

  factory AbilityType.fromJson(Map<String, dynamic> json) => AbilityType(
    id: json['id'] as int,
    name: json['name'] as String,
    slug: json['slug'] as String,
    assetKey: json['asset_key'] as String,
    description: json['description'] as String,
    icon: json['icon'] as String,
    soundKey: json['sound_key'] as String,
    targetType: json['target_type'] as String,
    range: json['range'] as int,
    currencyCost: json['currency_cost'] as int,
    cooldownTicks: json['cooldown_ticks'] as int,
    damage: json['damage'] as int,
    effectDurationTicks: json['effect_duration_ticks'] as int,
    effectParams: (json['effect_params'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as num),
    ),
    order: json['order'] as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'asset_key': assetKey,
    'description': description,
    'icon': icon,
    'sound_key': soundKey,
    'target_type': targetType,
    'range': range,
    'currency_cost': currencyCost,
    'cooldown_ticks': cooldownTicks,
    'damage': damage,
    'effect_duration_ticks': effectDurationTicks,
    'effect_params': effectParams,
    'order': order,
  };
}

class GameSettings {
  final int maxPlayers;
  final int minPlayers;
  final int tickIntervalMs;
  final int startingUnits;
  final double baseUnitGenerationRate;
  final int startingCurrency;
  final double baseCurrencyPerTick;
  final double regionCurrencyPerTick;

  GameSettings({
    required this.maxPlayers,
    required this.minPlayers,
    required this.tickIntervalMs,
    required this.startingUnits,
    required this.baseUnitGenerationRate,
    required this.startingCurrency,
    required this.baseCurrencyPerTick,
    required this.regionCurrencyPerTick,
  });

  factory GameSettings.fromJson(Map<String, dynamic> json) => GameSettings(
    maxPlayers: json['max_players'] as int,
    minPlayers: json['min_players'] as int,
    tickIntervalMs: json['tick_interval_ms'] as int,
    startingUnits: json['starting_units'] as int,
    baseUnitGenerationRate: (json['base_unit_generation_rate'] as num).toDouble(),
    startingCurrency: json['starting_currency'] as int,
    baseCurrencyPerTick: (json['base_currency_per_tick'] as num).toDouble(),
    regionCurrencyPerTick: (json['region_currency_per_tick'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'max_players': maxPlayers,
    'min_players': minPlayers,
    'tick_interval_ms': tickIntervalMs,
    'starting_units': startingUnits,
    'base_unit_generation_rate': baseUnitGenerationRate,
    'starting_currency': startingCurrency,
    'base_currency_per_tick': baseCurrencyPerTick,
    'region_currency_per_tick': regionCurrencyPerTick,
  };
}

class MapConfigItem {
  final int id;
  final String name;
  final String description;
  final List<String> countryCodes;

  MapConfigItem({
    required this.id,
    required this.name,
    required this.description,
    required this.countryCodes,
  });

  factory MapConfigItem.fromJson(Map<String, dynamic> json) => MapConfigItem(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String,
    countryCodes: (json['country_codes'] as List<dynamic>).cast<String>(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'country_codes': countryCodes,
  };
}

class GameModeListItem {
  final int id;
  final String name;
  final String slug;
  final String description;
  final int maxPlayers;
  final int minPlayers;
  final bool isDefault;
  final int order;

  GameModeListItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.maxPlayers,
    required this.minPlayers,
    required this.isDefault,
    required this.order,
  });

  factory GameModeListItem.fromJson(Map<String, dynamic> json) => GameModeListItem(
    id: json['id'] as int,
    name: json['name'] as String,
    slug: json['slug'] as String,
    description: json['description'] as String,
    maxPlayers: json['max_players'] as int,
    minPlayers: json['min_players'] as int,
    isDefault: json['is_default'] as bool,
    order: json['order'] as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'description': description,
    'max_players': maxPlayers,
    'min_players': minPlayers,
    'is_default': isDefault,
    'order': order,
  };
}

class GameMode extends GameModeListItem {
  final int tickIntervalMs;
  final int capitalSelectionTimeSeconds;
  final int matchDurationLimitMinutes;
  final double baseUnitGenerationRate;
  final double capitalGenerationBonus;
  final int startingCurrency;
  final double baseCurrencyPerTick;
  final double regionCurrencyPerTick;
  final double attackerAdvantage;
  final double defenderAdvantage;
  final double combatRandomness;
  final int startingUnits;
  final int startingRegions;
  final int neutralRegionUnits;
  final double eloKFactor;
  final int? mapConfigId;
  final bool isActive;

  GameMode({
    required super.id,
    required super.name,
    required super.slug,
    required super.description,
    required super.maxPlayers,
    required super.minPlayers,
    required super.isDefault,
    required super.order,
    required this.tickIntervalMs,
    required this.capitalSelectionTimeSeconds,
    required this.matchDurationLimitMinutes,
    required this.baseUnitGenerationRate,
    required this.capitalGenerationBonus,
    required this.startingCurrency,
    required this.baseCurrencyPerTick,
    required this.regionCurrencyPerTick,
    required this.attackerAdvantage,
    required this.defenderAdvantage,
    required this.combatRandomness,
    required this.startingUnits,
    required this.startingRegions,
    required this.neutralRegionUnits,
    required this.eloKFactor,
    this.mapConfigId,
    required this.isActive,
  });

  factory GameMode.fromJson(Map<String, dynamic> json) => GameMode(
    id: json['id'] as int,
    name: json['name'] as String,
    slug: json['slug'] as String,
    description: json['description'] as String,
    maxPlayers: json['max_players'] as int,
    minPlayers: json['min_players'] as int,
    isDefault: json['is_default'] as bool,
    order: json['order'] as int,
    tickIntervalMs: json['tick_interval_ms'] as int,
    capitalSelectionTimeSeconds: json['capital_selection_time_seconds'] as int,
    matchDurationLimitMinutes: json['match_duration_limit_minutes'] as int,
    baseUnitGenerationRate: (json['base_unit_generation_rate'] as num).toDouble(),
    capitalGenerationBonus: (json['capital_generation_bonus'] as num).toDouble(),
    startingCurrency: json['starting_currency'] as int,
    baseCurrencyPerTick: (json['base_currency_per_tick'] as num).toDouble(),
    regionCurrencyPerTick: (json['region_currency_per_tick'] as num).toDouble(),
    attackerAdvantage: (json['attacker_advantage'] as num).toDouble(),
    defenderAdvantage: (json['defender_advantage'] as num).toDouble(),
    combatRandomness: (json['combat_randomness'] as num).toDouble(),
    startingUnits: json['starting_units'] as int,
    startingRegions: json['starting_regions'] as int,
    neutralRegionUnits: json['neutral_region_units'] as int,
    eloKFactor: (json['elo_k_factor'] as num).toDouble(),
    mapConfigId: json['map_config_id'] as int?,
    isActive: json['is_active'] as bool,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'tick_interval_ms': tickIntervalMs,
    'capital_selection_time_seconds': capitalSelectionTimeSeconds,
    'match_duration_limit_minutes': matchDurationLimitMinutes,
    'base_unit_generation_rate': baseUnitGenerationRate,
    'capital_generation_bonus': capitalGenerationBonus,
    'starting_currency': startingCurrency,
    'base_currency_per_tick': baseCurrencyPerTick,
    'region_currency_per_tick': regionCurrencyPerTick,
    'attacker_advantage': attackerAdvantage,
    'defender_advantage': defenderAdvantage,
    'combat_randomness': combatRandomness,
    'starting_units': startingUnits,
    'starting_regions': startingRegions,
    'neutral_region_units': neutralRegionUnits,
    'elo_k_factor': eloKFactor,
    'map_config_id': mapConfigId,
    'is_active': isActive,
  };
}

class FullConfig {
  final GameSettings settings;
  final List<BuildingType> buildings;
  final List<UnitType> units;
  final List<AbilityType> abilities;
  final List<MapConfigItem> maps;
  final List<GameModeListItem> gameModes;

  FullConfig({
    required this.settings,
    required this.buildings,
    required this.units,
    required this.abilities,
    required this.maps,
    required this.gameModes,
  });

  factory FullConfig.fromJson(Map<String, dynamic> json) => FullConfig(
    settings: GameSettings.fromJson(json['settings'] as Map<String, dynamic>),
    buildings: (json['buildings'] as List<dynamic>)
        .map((e) => BuildingType.fromJson(e as Map<String, dynamic>))
        .toList(),
    units: (json['units'] as List<dynamic>)
        .map((e) => UnitType.fromJson(e as Map<String, dynamic>))
        .toList(),
    abilities: (json['abilities'] as List<dynamic>)
        .map((e) => AbilityType.fromJson(e as Map<String, dynamic>))
        .toList(),
    maps: (json['maps'] as List<dynamic>)
        .map((e) => MapConfigItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    gameModes: (json['game_modes'] as List<dynamic>)
        .map((e) => GameModeListItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'settings': settings.toJson(),
    'buildings': buildings.map((e) => e.toJson()).toList(),
    'units': units.map((e) => e.toJson()).toList(),
    'abilities': abilities.map((e) => e.toJson()).toList(),
    'maps': maps.map((e) => e.toJson()).toList(),
    'game_modes': gameModes.map((e) => e.toJson()).toList(),
  };
}
