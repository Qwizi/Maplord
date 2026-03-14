import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/game/game_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/match/match_result_screen.dart';
import 'screens/replay/replay_screen.dart';
import 'screens/developers/developers_screen.dart';
import 'screens/developers/developer_app_screen.dart';
import 'screens/settings/settings_screen.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isLoading = authProvider.loading;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (isLoading) return null;

      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      if (isAuthenticated && isAuthRoute) {
        return '/dashboard';
      }

      if (isAuthenticated && state.matchedLocation == '/') {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => '/dashboard',
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/game/:matchId',
        builder: (context, state) => GameScreen(
          matchId: state.pathParameters['matchId']!,
        ),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/match/:id',
        builder: (context, state) => MatchResultScreen(
          matchId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/replay/:matchId',
        builder: (context, state) => ReplayScreen(
          matchId: state.pathParameters['matchId']!,
        ),
      ),
      GoRoute(
        path: '/developers',
        builder: (context, state) => const DevelopersScreen(),
      ),
      GoRoute(
        path: '/developers/:appId',
        builder: (context, state) => DeveloperAppScreen(
          appId: state.pathParameters['appId']!,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    ),
  );
}
