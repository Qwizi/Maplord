import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import '../services/ws_service.dart';

class GameProvider extends ChangeNotifier {
  final WsService _wsService;
  GameSocketConnection? _connection;

  GameState? _gameState;
  List<GameEvent> _events = [];
  bool _connected = false;

  GameState? get gameState => _gameState;
  List<GameEvent> get events => _events;
  bool get connected => _connected;

  // Derived state
  String get gameStatus => _gameState?.meta.status ?? '';
  int get currentTick => int.tryParse(_gameState?.meta.currentTick ?? '0') ?? 0;
  Map<String, GamePlayer> get players => _gameState?.players ?? {};
  Map<String, GameRegion> get regions => _gameState?.regions ?? {};
  List<BuildingQueueItem> get buildingsQueue => _gameState?.buildingsQueue ?? [];
  List<UnitQueueItem> get unitQueue => _gameState?.unitQueue ?? [];
  List<ActiveEffect> get activeEffects => _gameState?.activeEffects ?? [];

  GameProvider({required WsService wsService}) : _wsService = wsService;

  void connectToMatch(String matchId, String token) {
    _connection?.dispose();
    _gameState = null;
    _events = [];
    _connected = false;

    _connection = GameSocketConnection(
      wsService: _wsService,
      matchId: matchId,
      token: token,
      onMessage: _handleMessage,
      onConnected: () {
        _connected = true;
        notifyListeners();
      },
      onDisconnected: () {
        _connected = false;
        notifyListeners();
      },
    );
    _connection!.connect();
  }

  void _handleMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    switch (type) {
      case 'game_state':
        _gameState = GameState.fromJson(msg['state'] as Map<String, dynamic>);
        break;
      case 'game_tick':
        if (_gameState == null) return;
        _applyTickUpdate(msg);
        break;
      case 'game_starting':
        if (_gameState != null) {
          _gameState = GameState(
            meta: GameMeta(
              status: 'in_progress',
              currentTick: _gameState!.meta.currentTick,
              tickIntervalMs: _gameState!.meta.tickIntervalMs,
              maxPlayers: _gameState!.meta.maxPlayers,
              minCapitalDistance: _gameState!.meta.minCapitalDistance,
              capitalSelectionTimeSeconds: _gameState!.meta.capitalSelectionTimeSeconds,
              capitalSelectionEndsAt: _gameState!.meta.capitalSelectionEndsAt,
              isTutorial: _gameState!.meta.isTutorial,
            ),
            players: _gameState!.players,
            regions: _gameState!.regions,
            buildingsQueue: _gameState!.buildingsQueue,
            unitQueue: _gameState!.unitQueue,
            transitQueue: _gameState!.transitQueue,
            activeEffects: _gameState!.activeEffects,
          );
        }
        break;
      case 'error':
        _events = [..._events.length > 50 ? _events.sublist(_events.length - 50) : _events,
          GameEvent(type: 'server_error', data: {'message': msg['message']})];
        break;
    }
    notifyListeners();
  }

  void _applyTickUpdate(Map<String, dynamic> msg) {
    if (_gameState == null) return;

    final tickEvents = (msg['events'] as List?)?.map((e) => GameEvent.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    final isGameOver = tickEvents.any((e) => e.type == 'game_over');

    // Merge regions
    Map<String, GameRegion> mergedRegions = Map.from(_gameState!.regions);
    if (msg['regions'] != null) {
      final regionUpdates = msg['regions'] as Map<String, dynamic>;
      for (final entry in regionUpdates.entries) {
        final existing = mergedRegions[entry.key];
        if (existing != null) {
          mergedRegions[entry.key] = GameRegion.merge(existing, entry.value as Map<String, dynamic>);
        } else {
          mergedRegions[entry.key] = GameRegion.fromJson(entry.value as Map<String, dynamic>);
        }
      }
    }

    // Merge players
    Map<String, GamePlayer> mergedPlayers = _gameState!.players;
    if (msg['players'] != null) {
      mergedPlayers = {};
      final playerUpdates = msg['players'] as Map<String, dynamic>;
      for (final entry in playerUpdates.entries) {
        mergedPlayers[entry.key] = GamePlayer.fromJson(entry.value as Map<String, dynamic>);
      }
    }

    _gameState = GameState(
      meta: GameMeta(
        status: isGameOver ? 'finished' : _gameState!.meta.status,
        currentTick: msg['tick']?.toString() ?? _gameState!.meta.currentTick,
        tickIntervalMs: _gameState!.meta.tickIntervalMs,
        maxPlayers: _gameState!.meta.maxPlayers,
        minCapitalDistance: _gameState!.meta.minCapitalDistance,
        capitalSelectionTimeSeconds: _gameState!.meta.capitalSelectionTimeSeconds,
        capitalSelectionEndsAt: _gameState!.meta.capitalSelectionEndsAt,
        isTutorial: _gameState!.meta.isTutorial,
      ),
      players: mergedPlayers,
      regions: mergedRegions,
      buildingsQueue: (msg['buildings_queue'] as List?)?.map((e) => BuildingQueueItem.fromJson(e as Map<String, dynamic>)).toList() ?? _gameState!.buildingsQueue,
      unitQueue: (msg['unit_queue'] as List?)?.map((e) => UnitQueueItem.fromJson(e as Map<String, dynamic>)).toList() ?? _gameState!.unitQueue,
      transitQueue: (msg['transit_queue'] as List?)?.cast<Map<String, dynamic>>() ?? _gameState!.transitQueue,
      activeEffects: (msg['active_effects'] as List?)?.map((e) => ActiveEffect.fromJson(e as Map<String, dynamic>)).toList() ?? _gameState!.activeEffects,
    );

    if (tickEvents.isNotEmpty) {
      _events = [..._events.length > 50 ? _events.sublist(_events.length - 50) : _events, ...tickEvents];
    }
  }

  // Actions
  void selectCapital(String regionId) => _connection?.selectCapital(regionId);
  void attack(String sourceRegionId, String targetRegionId, int units, {String? unitType}) =>
    _connection?.attack(sourceRegionId, targetRegionId, units, unitType: unitType);
  void moveUnits(String sourceRegionId, String targetRegionId, int units, {String? unitType}) =>
    _connection?.moveUnits(sourceRegionId, targetRegionId, units, unitType: unitType);
  void buildStructure(String regionId, String buildingType) => _connection?.build(regionId, buildingType);
  void produceUnit(String regionId, String unitType) => _connection?.produceUnit(regionId, unitType);
  void useAbility(String targetRegionId, String abilityType) => _connection?.useAbility(targetRegionId, abilityType);
  Future<bool> leaveMatch() => _connection?.leaveMatch() ?? Future.value(false);
  void setTickMultiplier(int multiplier) => _connection?.setTickMultiplier(multiplier);

  void disconnect() {
    _connection?.dispose();
    _connection = null;
    _connected = false;
    _gameState = null;
    _events = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _connection?.dispose();
    super.dispose();
  }
}
