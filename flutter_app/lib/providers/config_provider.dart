import 'package:flutter/foundation.dart';
import '../models/game_config.dart';
import '../services/api_service.dart';

class ConfigProvider extends ChangeNotifier {
  final ApiService _api;

  FullConfig? _config;
  List<GameModeListItem> _gameModes = [];
  bool _loading = false;
  String? _error;

  FullConfig? get config => _config;
  List<GameModeListItem> get gameModes => _gameModes;
  List<BuildingType> get buildings => _config?.buildings ?? [];
  List<UnitType> get units => _config?.units ?? [];
  List<AbilityType> get abilities => _config?.abilities ?? [];
  bool get loading => _loading;
  String? get error => _error;

  ConfigProvider({required ApiService api}) : _api = api;

  Future<void> loadConfig() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _config = await _api.getConfig();
      _gameModes = _config!.gameModes;
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  BuildingType? getBuildingBySlug(String slug) {
    try {
      return buildings.firstWhere((b) => b.slug == slug);
    } catch (_) {
      return null;
    }
  }

  UnitType? getUnitBySlug(String slug) {
    try {
      return units.firstWhere((u) => u.slug == slug);
    } catch (_) {
      return null;
    }
  }

  AbilityType? getAbilityBySlug(String slug) {
    try {
      return abilities.firstWhere((a) => a.slug == slug);
    } catch (_) {
      return null;
    }
  }
}
