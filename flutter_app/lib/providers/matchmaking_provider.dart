import 'package:flutter/foundation.dart';
import '../services/ws_service.dart';

class MatchmakingProvider extends ChangeNotifier {
  final WsService _wsService;
  MatchmakingConnection? _connection;

  bool _inQueue = false;
  int _playersInQueue = 0;
  String? _matchId;
  String? _activeMatchId;
  bool _fillBots = true;

  bool get inQueue => _inQueue;
  int get playersInQueue => _playersInQueue;
  String? get matchId => _matchId;
  String? get activeMatchId => _activeMatchId;
  bool get fillBots => _fillBots;
  set fillBots(bool value) {
    _fillBots = value;
    notifyListeners();
  }

  MatchmakingProvider({required WsService wsService}) : _wsService = wsService;

  void joinQueue(String token, {String? gameModeSlug}) {
    _connection?.dispose();
    _matchId = null;

    _connection = MatchmakingConnection(
      wsService: _wsService,
      token: token,
      onMessage: _handleMessage,
      onClose: () {
        _inQueue = false;
        notifyListeners();
      },
    );
    _connection!.joinQueue(gameModeSlug: gameModeSlug, fillBots: _fillBots);
    _inQueue = true;
    notifyListeners();
  }

  void _handleMessage(Map<String, dynamic> msg) {
    switch (msg['type'] as String?) {
      case 'queue_status':
        _playersInQueue = msg['players_in_queue'] as int;
        break;
      case 'match_found':
        _matchId = msg['match_id'] as String;
        _activeMatchId = msg['match_id'] as String;
        _inQueue = false;
        break;
      case 'active_match_exists':
        _activeMatchId = msg['match_id'] as String;
        _matchId = msg['match_id'] as String;
        _inQueue = false;
        break;
      case 'queue_left':
        _inQueue = false;
        break;
    }
    notifyListeners();
  }

  void leaveQueue() {
    _connection?.leaveQueue();
    _inQueue = false;
    notifyListeners();
  }

  void clearMatchId() {
    _matchId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _connection?.dispose();
    super.dispose();
  }
}
