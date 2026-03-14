import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/ws_service.dart';
import '../../app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiUrlController;
  late TextEditingController _wsUrlController;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    final ws = context.read<WsService>();
    _apiUrlController = TextEditingController(text: api.baseUrl);
    _wsUrlController = TextEditingController(text: ws.wsBase);
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _wsUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.primary.withOpacity(0.2),
                    child: Text(
                      (auth.user?.username ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    auth.user?.username ?? 'Unknown',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.user?.email ?? '',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ELO: ${auth.user?.eloRating.toStringAsFixed(0) ?? '0'}',
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          auth.user?.role ?? 'player',
                          style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Server configuration
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Server Configuration',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiUrlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'API Base URL',
                      hintText: 'http://10.0.2.2/api/v1',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _wsUrlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'WebSocket Base URL',
                      hintText: 'ws://10.0.2.2/ws',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<ApiService>().setBaseUrl(_apiUrlController.text.trim());
                        context.read<WsService>().setWsBase(_wsUrlController.text.trim());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Server URLs updated')),
                        );
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tutorial
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tutorial',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    auth.user?.tutorialCompleted == true
                        ? 'Tutorial completed'
                        : 'Tutorial not completed',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Logout
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
