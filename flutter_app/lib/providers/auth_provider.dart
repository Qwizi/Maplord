import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/token_pair.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final StorageService _storage;

  User? _user;
  String? _token;
  bool _loading = true;

  User? get user => _user;
  String? get token => _token;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null && _token != null;

  AuthProvider({required ApiService api, required StorageService storage})
      : _api = api, _storage = storage;

  Future<void> init() async {
    final accessToken = await _storage.getAccessToken();
    if (accessToken != null) {
      await _loadUser(accessToken);
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _loadUser(String accessToken) async {
    try {
      final me = await _api.getMe(accessToken);
      _user = me;
      _token = accessToken;
    } catch (_) {
      // Token might be expired, try refresh
      final refresh = await _storage.getRefreshToken();
      if (refresh != null) {
        try {
          final newTokens = await _api.refreshToken(refresh);
          await _storage.saveTokens(newTokens.access, newTokens.refresh);
          final me = await _api.getMe(newTokens.access);
          _user = me;
          _token = newTokens.access;
        } catch (_) {
          await _storage.clearTokens();
          _user = null;
          _token = null;
        }
      } else {
        await _storage.clearTokens();
        _user = null;
        _token = null;
      }
    }
  }

  Future<void> login(String email, String password) async {
    final tokens = await _api.login(email, password);
    await _storage.saveTokens(tokens.access, tokens.refresh);
    await _loadUser(tokens.access);
    notifyListeners();
  }

  Future<void> register(String username, String email, String password) async {
    await _api.register(username, email, password);
    await login(email, password);
  }

  Future<void> logout() async {
    await _storage.clearTokens();
    _user = null;
    _token = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final accessToken = await _storage.getAccessToken();
    if (accessToken == null) return;
    await _loadUser(accessToken);
    notifyListeners();
  }
}
