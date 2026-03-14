import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'app_router.dart';
import 'services/api_service.dart';
import 'services/ws_service.dart';
import 'services/storage_service.dart';
import 'providers/auth_provider.dart';
import 'providers/config_provider.dart';
import 'providers/game_provider.dart';
import 'providers/matchmaking_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MapLordApp());
}

class MapLordApp extends StatelessWidget {
  const MapLordApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    final wsService = WsService();
    final storageService = StorageService();

    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<WsService>.value(value: wsService),
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(api: apiService, storage: storageService)..init(),
        ),
        ChangeNotifierProvider<ConfigProvider>(
          create: (_) => ConfigProvider(api: apiService)..loadConfig(),
        ),
        ChangeNotifierProvider<GameProvider>(
          create: (_) => GameProvider(wsService: wsService),
        ),
        ChangeNotifierProvider<MatchmakingProvider>(
          create: (_) => MatchmakingProvider(wsService: wsService),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final router = createRouter(authProvider);
          return MaterialApp.router(
            title: 'MapLord',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
