import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef VoidCallback = void Function();

class WsService {
  String _wsBase;

  WsService({String? wsBase}) : _wsBase = wsBase ?? 'ws://10.0.2.2/ws';

  String get wsBase => _wsBase;
  void setWsBase(String url) { _wsBase = url; }

  WebSocketChannel connect(String path, String? token) {
    final url = token != null ? '$_wsBase$path?token=$token' : '$_wsBase$path';
    return WebSocketChannel.connect(Uri.parse(url));
  }
}

typedef WsMessageHandler = void Function(Map<String, dynamic> msg);
typedef WsCloseHandler = void Function();

class GameSocketConnection {
  final WsService _wsService;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _retryTimer;
  int _backoffDelay = 1000;
  bool _disposed = false;
  bool _connected = false;

  final String matchId;
  final String token;
  final WsMessageHandler onMessage;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;
  Completer<bool>? _leaveCompleter;

  bool get connected => _connected;

  GameSocketConnection({
    required WsService wsService,
    required this.matchId,
    required this.token,
    required this.onMessage,
    this.onConnected,
    this.onDisconnected,
  }) : _wsService = wsService;

  void connect() {
    if (_disposed) return;

    _channel = _wsService.connect('/game/$matchId/', token);
    _connected = true;
    _backoffDelay = 1000;
    onConnected?.call();

    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          if (msg['type'] == 'match_left') {
            _leaveCompleter?.complete(true);
            _leaveCompleter = null;
          }
          onMessage(msg);
        } catch (e) {
          // Parse error, ignore
        }
      },
      onDone: () {
        _connected = false;
        _leaveCompleter?.complete(false);
        _leaveCompleter = null;
        onDisconnected?.call();

        if (!_disposed) {
          _retryTimer = Timer(Duration(milliseconds: _backoffDelay), () {
            _backoffDelay = min(_backoffDelay * 2, 10000);
            connect();
          });
        }
      },
      onError: (_) {
        _connected = false;
        onDisconnected?.call();
      },
    );
  }

  void send(Map<String, dynamic> data) {
    if (_channel != null && _connected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void selectCapital(String regionId) => send({'action': 'select_capital', 'region_id': regionId});
  void attack(String sourceRegionId, String targetRegionId, int units, {String? unitType}) =>
    send({'action': 'attack', 'source_region_id': sourceRegionId, 'target_region_id': targetRegionId, 'units': units, if (unitType != null) 'unit_type': unitType});
  void moveUnits(String sourceRegionId, String targetRegionId, int units, {String? unitType}) =>
    send({'action': 'move', 'source_region_id': sourceRegionId, 'target_region_id': targetRegionId, 'units': units, if (unitType != null) 'unit_type': unitType});
  void build(String regionId, String buildingType) => send({'action': 'build', 'region_id': regionId, 'building_type': buildingType});
  void produceUnit(String regionId, String unitType) => send({'action': 'produce_unit', 'region_id': regionId, 'unit_type': unitType});
  void useAbility(String targetRegionId, String abilityType) => send({'action': 'use_ability', 'target_region_id': targetRegionId, 'ability_type': abilityType});

  Future<bool> leaveMatch() {
    if (_channel == null || !_connected) return Future.value(false);
    _leaveCompleter = Completer<bool>();
    send({'action': 'leave_match'});
    return _leaveCompleter!.future.timeout(const Duration(milliseconds: 1500), onTimeout: () {
      _leaveCompleter = null;
      return false;
    });
  }

  void setTickMultiplier(int multiplier) => send({'action': 'set_tick_multiplier', 'multiplier': multiplier});

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _leaveCompleter?.complete(false);
  }
}

class MatchmakingConnection {
  final WsService _wsService;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _disposed = false;

  final String token;
  final WsMessageHandler onMessage;
  final VoidCallback? onClose;

  MatchmakingConnection({
    required WsService wsService,
    required this.token,
    required this.onMessage,
    this.onClose,
  }) : _wsService = wsService;

  void joinQueue({String? gameModeSlug, bool fillBots = true}) {
    if (_disposed) return;
    final path = gameModeSlug != null ? '/matchmaking/$gameModeSlug/' : '/matchmaking/';
    _channel = _wsService.connect(path, token);

    // Send initial actions after connection
    Future.delayed(const Duration(milliseconds: 100), () {
      send({'action': 'status'});
      if (fillBots) {
        send({'action': 'fill_bots'});
      }
    });

    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          onMessage(msg);
        } catch (_) {}
      },
      onDone: () {
        onClose?.call();
      },
    );
  }

  void leaveQueue() {
    send({'action': 'cancel'});
    _channel?.sink.close();
    _channel = null;
  }

  void send(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _channel?.sink.close();
  }
}
