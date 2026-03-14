class GameMeta {
  final String status;
  final String currentTick;
  final String tickIntervalMs;
  final String maxPlayers;
  final String minCapitalDistance;
  final String? capitalSelectionTimeSeconds;
  final String? capitalSelectionEndsAt;
  final String? isTutorial;

  GameMeta({
    required this.status,
    required this.currentTick,
    required this.tickIntervalMs,
    required this.maxPlayers,
    required this.minCapitalDistance,
    this.capitalSelectionTimeSeconds,
    this.capitalSelectionEndsAt,
    this.isTutorial,
  });

  factory GameMeta.fromJson(Map<String, dynamic> json) => GameMeta(
    status: json['status'].toString(),
    currentTick: json['current_tick'].toString(),
    tickIntervalMs: json['tick_interval_ms'].toString(),
    maxPlayers: json['max_players'].toString(),
    minCapitalDistance: json['min_capital_distance'].toString(),
    capitalSelectionTimeSeconds: json['capital_selection_time_seconds']?.toString(),
    capitalSelectionEndsAt: json['capital_selection_ends_at']?.toString(),
    isTutorial: json['is_tutorial']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'status': status,
    'current_tick': currentTick,
    'tick_interval_ms': tickIntervalMs,
    'max_players': maxPlayers,
    'min_capital_distance': minCapitalDistance,
    if (capitalSelectionTimeSeconds != null) 'capital_selection_time_seconds': capitalSelectionTimeSeconds,
    if (capitalSelectionEndsAt != null) 'capital_selection_ends_at': capitalSelectionEndsAt,
    if (isTutorial != null) 'is_tutorial': isTutorial,
  };
}

class GamePlayer {
  final String userId;
  final String username;
  final String color;
  final bool isAlive;
  final bool? connected;
  final String? disconnectDeadline;
  final String? leftMatchAt;
  final String? capitalRegionId;
  final double currency;
  final String? eliminatedReason;
  final int? eliminatedTick;
  final Map<String, dynamic>? abilityCooldowns;
  final bool? isBot;
  final int? totalRegionsConquered;
  final int? totalUnitsProduced;
  final int? totalUnitsLost;
  final int? totalBuildingsBuilt;

  GamePlayer({
    required this.userId,
    required this.username,
    required this.color,
    required this.isAlive,
    this.connected,
    this.disconnectDeadline,
    this.leftMatchAt,
    this.capitalRegionId,
    required this.currency,
    this.eliminatedReason,
    this.eliminatedTick,
    this.abilityCooldowns,
    this.isBot,
    this.totalRegionsConquered,
    this.totalUnitsProduced,
    this.totalUnitsLost,
    this.totalBuildingsBuilt,
  });

  factory GamePlayer.fromJson(Map<String, dynamic> json) => GamePlayer(
    userId: json['user_id'] as String,
    username: json['username'] as String,
    color: json['color'] as String,
    isAlive: json['is_alive'] as bool,
    connected: json['connected'] as bool?,
    disconnectDeadline: json['disconnect_deadline'] as String?,
    leftMatchAt: json['left_match_at'] as String?,
    capitalRegionId: json['capital_region_id'] as String?,
    currency: (json['currency'] as num).toDouble(),
    eliminatedReason: json['eliminated_reason'] as String?,
    eliminatedTick: json['eliminated_tick'] as int?,
    abilityCooldowns: json['ability_cooldowns'] as Map<String, dynamic>?,
    isBot: json['is_bot'] as bool?,
    totalRegionsConquered: json['total_regions_conquered'] as int?,
    totalUnitsProduced: json['total_units_produced'] as int?,
    totalUnitsLost: json['total_units_lost'] as int?,
    totalBuildingsBuilt: json['total_buildings_built'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'username': username,
    'color': color,
    'is_alive': isAlive,
    'connected': connected,
    'disconnect_deadline': disconnectDeadline,
    'left_match_at': leftMatchAt,
    'capital_region_id': capitalRegionId,
    'currency': currency,
    'eliminated_reason': eliminatedReason,
    'eliminated_tick': eliminatedTick,
    'ability_cooldowns': abilityCooldowns,
    'is_bot': isBot,
    'total_regions_conquered': totalRegionsConquered,
    'total_units_produced': totalUnitsProduced,
    'total_units_lost': totalUnitsLost,
    'total_buildings_built': totalBuildingsBuilt,
  };
}

class GameRegion {
  final String name;
  final String countryCode;
  final List<double>? centroid;
  final String? ownerId;
  final int unitCount;
  final String? unitType;
  final Map<String, dynamic>? units;
  final bool? isCoastal;
  final bool isCapital;
  final String? buildingType;
  final Map<String, dynamic>? buildings;
  final double defenseBonus;
  final int? visionRange;
  final double? unitGenerationBonus;
  final double? currencyGenerationBonus;

  GameRegion({
    required this.name,
    required this.countryCode,
    this.centroid,
    this.ownerId,
    required this.unitCount,
    this.unitType,
    this.units,
    this.isCoastal,
    required this.isCapital,
    this.buildingType,
    this.buildings,
    required this.defenseBonus,
    this.visionRange,
    this.unitGenerationBonus,
    this.currencyGenerationBonus,
  });

  factory GameRegion.fromJson(Map<String, dynamic> json) => GameRegion(
    name: json['name'] as String,
    countryCode: json['country_code'] as String,
    centroid: (json['centroid'] as List<dynamic>?)
        ?.map((e) => (e as num).toDouble())
        .toList(),
    ownerId: json['owner_id'] as String?,
    unitCount: json['unit_count'] as int,
    unitType: json['unit_type'] as String?,
    units: json['units'] as Map<String, dynamic>?,
    isCoastal: json['is_coastal'] as bool?,
    isCapital: json['is_capital'] as bool,
    buildingType: json['building_type'] as String?,
    buildings: json['buildings'] as Map<String, dynamic>?,
    defenseBonus: (json['defense_bonus'] as num).toDouble(),
    visionRange: json['vision_range'] as int?,
    unitGenerationBonus: (json['unit_generation_bonus'] as num?)?.toDouble(),
    currencyGenerationBonus: (json['currency_generation_bonus'] as num?)?.toDouble(),
  );

  /// Merge partial updates into an existing region.
  static GameRegion merge(GameRegion existing, Map<String, dynamic> update) {
    return GameRegion(
      name: update['name'] as String? ?? existing.name,
      countryCode: update['country_code'] as String? ?? existing.countryCode,
      centroid: update.containsKey('centroid')
          ? (update['centroid'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList()
          : existing.centroid,
      ownerId: update.containsKey('owner_id') ? update['owner_id'] as String? : existing.ownerId,
      unitCount: update['unit_count'] as int? ?? existing.unitCount,
      unitType: update.containsKey('unit_type') ? update['unit_type'] as String? : existing.unitType,
      units: update.containsKey('units') ? update['units'] as Map<String, dynamic>? : existing.units,
      isCoastal: update['is_coastal'] as bool? ?? existing.isCoastal,
      isCapital: update['is_capital'] as bool? ?? existing.isCapital,
      buildingType: update.containsKey('building_type') ? update['building_type'] as String? : existing.buildingType,
      buildings: update.containsKey('buildings') ? update['buildings'] as Map<String, dynamic>? : existing.buildings,
      defenseBonus: (update['defense_bonus'] as num?)?.toDouble() ?? existing.defenseBonus,
      visionRange: update['vision_range'] as int? ?? existing.visionRange,
      unitGenerationBonus: (update['unit_generation_bonus'] as num?)?.toDouble() ?? existing.unitGenerationBonus,
      currencyGenerationBonus: (update['currency_generation_bonus'] as num?)?.toDouble() ?? existing.currencyGenerationBonus,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'country_code': countryCode,
    'centroid': centroid,
    'owner_id': ownerId,
    'unit_count': unitCount,
    'unit_type': unitType,
    'units': units,
    'is_coastal': isCoastal,
    'is_capital': isCapital,
    'building_type': buildingType,
    'buildings': buildings,
    'defense_bonus': defenseBonus,
    'vision_range': visionRange,
    'unit_generation_bonus': unitGenerationBonus,
    'currency_generation_bonus': currencyGenerationBonus,
  };
}

class BuildingQueueItem {
  final String regionId;
  final String buildingType;
  final String playerId;
  final int ticksRemaining;
  final int totalTicks;

  BuildingQueueItem({
    required this.regionId,
    required this.buildingType,
    required this.playerId,
    required this.ticksRemaining,
    required this.totalTicks,
  });

  factory BuildingQueueItem.fromJson(Map<String, dynamic> json) => BuildingQueueItem(
    regionId: json['region_id'] as String,
    buildingType: json['building_type'] as String,
    playerId: json['player_id'] as String,
    ticksRemaining: json['ticks_remaining'] as int,
    totalTicks: json['total_ticks'] as int,
  );

  Map<String, dynamic> toJson() => {
    'region_id': regionId,
    'building_type': buildingType,
    'player_id': playerId,
    'ticks_remaining': ticksRemaining,
    'total_ticks': totalTicks,
  };
}

class UnitQueueItem {
  final String regionId;
  final String playerId;
  final String unitType;
  final int quantity;
  final int ticksRemaining;
  final int totalTicks;

  UnitQueueItem({
    required this.regionId,
    required this.playerId,
    required this.unitType,
    required this.quantity,
    required this.ticksRemaining,
    required this.totalTicks,
  });

  factory UnitQueueItem.fromJson(Map<String, dynamic> json) => UnitQueueItem(
    regionId: json['region_id'] as String,
    playerId: json['player_id'] as String,
    unitType: json['unit_type'] as String,
    quantity: json['quantity'] as int,
    ticksRemaining: json['ticks_remaining'] as int,
    totalTicks: json['total_ticks'] as int,
  );

  Map<String, dynamic> toJson() => {
    'region_id': regionId,
    'player_id': playerId,
    'unit_type': unitType,
    'quantity': quantity,
    'ticks_remaining': ticksRemaining,
    'total_ticks': totalTicks,
  };
}

class ActiveEffect {
  final String effectType;
  final String sourcePlayerId;
  final String targetRegionId;
  final List<String> affectedRegionIds;
  final int ticksRemaining;
  final int totalTicks;
  final Map<String, num> params;

  ActiveEffect({
    required this.effectType,
    required this.sourcePlayerId,
    required this.targetRegionId,
    required this.affectedRegionIds,
    required this.ticksRemaining,
    required this.totalTicks,
    required this.params,
  });

  factory ActiveEffect.fromJson(Map<String, dynamic> json) => ActiveEffect(
    effectType: json['effect_type'] as String,
    sourcePlayerId: json['source_player_id'] as String,
    targetRegionId: json['target_region_id'] as String,
    affectedRegionIds: (json['affected_region_ids'] as List<dynamic>).cast<String>(),
    ticksRemaining: json['ticks_remaining'] as int,
    totalTicks: json['total_ticks'] as int,
    params: (json['params'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as num),
    ),
  );

  Map<String, dynamic> toJson() => {
    'effect_type': effectType,
    'source_player_id': sourcePlayerId,
    'target_region_id': targetRegionId,
    'affected_region_ids': affectedRegionIds,
    'ticks_remaining': ticksRemaining,
    'total_ticks': totalTicks,
    'params': params,
  };
}

class GameState {
  final GameMeta meta;
  final Map<String, GamePlayer> players;
  final Map<String, GameRegion> regions;
  final List<BuildingQueueItem> buildingsQueue;
  final List<UnitQueueItem> unitQueue;
  final List<dynamic>? transitQueue;
  final List<ActiveEffect>? activeEffects;

  GameState({
    required this.meta,
    required this.players,
    required this.regions,
    required this.buildingsQueue,
    required this.unitQueue,
    this.transitQueue,
    this.activeEffects,
  });

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
    meta: GameMeta.fromJson(json['meta'] as Map<String, dynamic>),
    players: (json['players'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, GamePlayer.fromJson(v as Map<String, dynamic>)),
    ),
    regions: (json['regions'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, GameRegion.fromJson(v as Map<String, dynamic>)),
    ),
    buildingsQueue: (json['buildings_queue'] as List<dynamic>)
        .map((e) => BuildingQueueItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    unitQueue: (json['unit_queue'] as List<dynamic>)
        .map((e) => UnitQueueItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    transitQueue: json['transit_queue'] as List<dynamic>?,
    activeEffects: (json['active_effects'] as List<dynamic>?)
        ?.map((e) => ActiveEffect.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'meta': meta.toJson(),
    'players': players.map((k, v) => MapEntry(k, v.toJson())),
    'regions': regions.map((k, v) => MapEntry(k, v.toJson())),
    'buildings_queue': buildingsQueue.map((e) => e.toJson()).toList(),
    'unit_queue': unitQueue.map((e) => e.toJson()).toList(),
    'transit_queue': transitQueue,
    'active_effects': activeEffects?.map((e) => e.toJson()).toList(),
  };
}

class GameEvent {
  final String type;
  final Map<String, dynamic> data;

  GameEvent({required this.type, Map<String, dynamic>? data}) : data = data ?? {};

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    // All fields except 'type' are the event data
    final data = Map<String, dynamic>.from(json)..remove('type');
    return GameEvent(type: type, data: data);
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    ...data,
  };
}
