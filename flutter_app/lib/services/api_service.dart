import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/token_pair.dart';
import '../models/game_config.dart';
import '../models/match.dart';
import '../models/leaderboard.dart';
import '../models/geo.dart';
import '../models/share.dart';
import '../models/developer.dart';
import '../models/game_state.dart';

class ApiError implements Exception {
  final int statusCode;
  final String message;
  final dynamic body;
  ApiError(this.statusCode, this.message, [this.body]);
  @override
  String toString() => 'ApiError($statusCode): $message';
}

class ApiService {
  // Base URL - should be configured per environment
  String _baseUrl;

  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://maplord.qwizi.ovh/api/v1',
  );

  ApiService({String? baseUrl}) : _baseUrl = baseUrl ?? defaultBaseUrl;

  void setBaseUrl(String url) { _baseUrl = url; }
  String get baseUrl => _baseUrl;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams);
    }

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'PATCH':
        response = await http.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw ApiError(0, 'Unknown method: $method');
    }

    if (response.statusCode == 204) return {};

    if (response.statusCode >= 400) {
      Map<String, dynamic> errorBody = {};
      try { errorBody = jsonDecode(response.body); } catch (_) {}
      throw ApiError(
        response.statusCode,
        errorBody['detail']?.toString() ?? response.reasonPhrase ?? 'Unknown error',
        errorBody,
      );
    }

    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is List) return {'items': decoded};
    return decoded as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> _requestList(
    String method, String path, {String? token, Map<String, dynamic>? body}
  ) async {
    var uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      default:
        throw ApiError(0, 'Unknown method: $method');
    }

    if (response.statusCode >= 400) {
      Map<String, dynamic> errorBody = {};
      try { errorBody = jsonDecode(response.body); } catch (_) {}
      throw ApiError(response.statusCode, errorBody['detail']?.toString() ?? response.reasonPhrase ?? 'Unknown error', errorBody);
    }

    final decoded = jsonDecode(response.body);
    return (decoded as List).cast<Map<String, dynamic>>();
  }

  // --- Auth ---
  Future<TokenPair> login(String email, String password) async {
    final data = await _request('POST', '/token/pair', body: {'email': email, 'password': password});
    return TokenPair.fromJson(data);
  }

  Future<TokenPair> refreshToken(String refresh) async {
    final data = await _request('POST', '/token/refresh', body: {'refresh': refresh});
    return TokenPair.fromJson(data);
  }

  Future<User> register(String username, String email, String password) async {
    final data = await _request('POST', '/auth/register', body: {'username': username, 'email': email, 'password': password});
    return User.fromJson(data);
  }

  Future<User> getMe(String token) async {
    final data = await _request('GET', '/auth/me', token: token);
    return User.fromJson(data);
  }

  Future<List<LeaderboardEntry>> getLeaderboard(String token) async {
    final list = await _requestList('GET', '/auth/leaderboard', token: token);
    return list.map((e) => LeaderboardEntry.fromJson(e)).toList();
  }

  // --- Config ---
  Future<FullConfig> getConfig() async {
    final data = await _request('GET', '/config/');
    return FullConfig.fromJson(data);
  }

  Future<List<GameModeListItem>> getGameModes() async {
    final list = await _requestList('GET', '/config/game-modes/');
    return list.map((e) => GameModeListItem.fromJson(e)).toList();
  }

  Future<GameMode> getGameMode(String slug) async {
    final data = await _request('GET', '/config/game-modes/$slug/');
    return GameMode.fromJson(data);
  }

  // --- Geo ---
  Future<List<RegionGraphEntry>> getRegionsGraph({String? matchId}) async {
    final path = matchId != null ? '/geo/regions/graph/?match_id=$matchId' : '/geo/regions/graph/';
    final list = await _requestList('GET', path);
    return list.map((e) => RegionGraphEntry.fromJson(e)).toList();
  }

  String getRegionTilesUrl({String? matchId}) {
    final base = '$_baseUrl/geo/tiles/{z}/{x}/{y}/';
    return matchId != null ? '$base?match_id=$matchId' : base;
  }

  // --- Matches ---
  Future<List<Match>> getMyMatches(String token) async {
    final list = await _requestList('GET', '/matches/', token: token);
    return list.map((e) => Match.fromJson(e)).toList();
  }

  Future<Match> getMatch(String token, String matchId) async {
    final data = await _request('GET', '/matches/$matchId/', token: token);
    return Match.fromJson(data);
  }

  Future<MatchResult> getMatchResult(String token, String matchId) async {
    final data = await _request('GET', '/game/results/$matchId/', token: token);
    return MatchResult.fromJson(data);
  }

  // --- Replay ---
  Future<List<SnapshotTick>> getMatchSnapshots(String token, String matchId) async {
    final list = await _requestList('GET', '/game/snapshots/$matchId/', token: token);
    return list.map((e) => SnapshotTick.fromJson(e)).toList();
  }

  Future<SnapshotDetail> getSnapshot(String token, String matchId, int tick) async {
    final data = await _request('GET', '/game/snapshots/$matchId/$tick/', token: token);
    return SnapshotDetail.fromJson(data);
  }

  // --- Tutorial ---
  Future<String> startTutorial(String token) async {
    final data = await _request('POST', '/matches/tutorial/start/', token: token);
    return data['match_id'] as String;
  }

  Future<void> completeTutorial(String token) async {
    await _request('POST', '/auth/tutorial/complete/', token: token);
  }

  Future<void> cleanupTutorial(String token) async {
    await _request('POST', '/matches/tutorial/cleanup/', token: token);
  }

  // --- Share ---
  Future<ShareLink> createShareLink(String token, String resourceType, String resourceId) async {
    final data = await _request('POST', '/share/create/', token: token, body: {'resource_type': resourceType, 'resource_id': resourceId});
    return ShareLink.fromJson(data);
  }

  Future<SharedMatchData> getSharedResource(String shareToken) async {
    final data = await _request('GET', '/share/$shareToken/');
    return SharedMatchData.fromJson(data);
  }

  Future<SnapshotDetail> getSharedSnapshot(String shareToken, int tick) async {
    final data = await _request('GET', '/share/$shareToken/snapshots/$tick/');
    return SnapshotDetail.fromJson(data);
  }

  // --- Developer Platform ---
  Future<DeveloperAppCreated> createDeveloperApp(String token, String name, {String? description}) async {
    final data = await _request('POST', '/developers/apps/', token: token, body: {'name': name, if (description != null) 'description': description});
    return DeveloperAppCreated.fromJson(data);
  }

  Future<List<DeveloperApp>> getDeveloperApps(String token) async {
    final list = await _requestList('GET', '/developers/apps/', token: token);
    return list.map((e) => DeveloperApp.fromJson(e)).toList();
  }

  Future<DeveloperApp> getDeveloperApp(String token, String appId) async {
    final data = await _request('GET', '/developers/apps/$appId/', token: token);
    return DeveloperApp.fromJson(data);
  }

  Future<DeveloperApp> updateDeveloperApp(String token, String appId, {String? name, String? description}) async {
    final data = await _request('PATCH', '/developers/apps/$appId/', token: token, body: {if (name != null) 'name': name, if (description != null) 'description': description});
    return DeveloperApp.fromJson(data);
  }

  Future<void> deleteDeveloperApp(String token, String appId) async {
    await _request('DELETE', '/developers/apps/$appId/', token: token);
  }

  // API Keys
  Future<APIKeyCreated> createApiKey(String token, String appId, List<String> scopes, {int? rateLimit}) async {
    final data = await _request('POST', '/developers/apps/$appId/keys/', token: token, body: {'scopes': scopes, if (rateLimit != null) 'rate_limit': rateLimit});
    return APIKeyCreated.fromJson(data);
  }

  Future<List<APIKeyOut>> getApiKeys(String token, String appId) async {
    final list = await _requestList('GET', '/developers/apps/$appId/keys/', token: token);
    return list.map((e) => APIKeyOut.fromJson(e)).toList();
  }

  Future<void> deleteApiKey(String token, String appId, String keyId) async {
    await _request('DELETE', '/developers/apps/$appId/keys/$keyId/', token: token);
  }

  // Webhooks
  Future<WebhookOut> createWebhook(String token, String appId, String url, List<String> events) async {
    final data = await _request('POST', '/developers/apps/$appId/webhooks/', token: token, body: {'url': url, 'events': events});
    return WebhookOut.fromJson(data);
  }

  Future<List<WebhookOut>> getWebhooks(String token, String appId) async {
    final list = await _requestList('GET', '/developers/apps/$appId/webhooks/', token: token);
    return list.map((e) => WebhookOut.fromJson(e)).toList();
  }

  Future<WebhookOut> updateWebhook(String token, String appId, String webhookId, {String? url, List<String>? events, bool? isActive}) async {
    final data = await _request('PATCH', '/developers/apps/$appId/webhooks/$webhookId/', token: token, body: {if (url != null) 'url': url, if (events != null) 'events': events, if (isActive != null) 'is_active': isActive});
    return WebhookOut.fromJson(data);
  }

  Future<void> deleteWebhook(String token, String appId, String webhookId) async {
    await _request('DELETE', '/developers/apps/$appId/webhooks/$webhookId/', token: token);
  }

  Future<Map<String, dynamic>> testWebhook(String token, String appId, String webhookId) async {
    return await _request('POST', '/developers/apps/$appId/webhooks/$webhookId/test/', token: token);
  }

  Future<List<WebhookDelivery>> getWebhookDeliveries(String token, String appId, String webhookId) async {
    final list = await _requestList('GET', '/developers/apps/$appId/webhooks/$webhookId/deliveries/', token: token);
    return list.map((e) => WebhookDelivery.fromJson(e)).toList();
  }

  Future<UsageStats> getAppUsage(String token, String appId) async {
    final data = await _request('GET', '/developers/apps/$appId/usage/', token: token);
    return UsageStats.fromJson(data);
  }

  Future<List<String>> getAvailableScopes(String token) async {
    final data = await _request('GET', '/developers/scopes/', token: token);
    return (data['scopes'] as List).cast<String>();
  }

  Future<List<String>> getAvailableEvents(String token) async {
    final data = await _request('GET', '/developers/events/', token: token);
    return (data['events'] as List).cast<String>();
  }
}
