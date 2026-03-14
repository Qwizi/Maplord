import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/developer.dart';

class DeveloperAppScreen extends StatefulWidget {
  final String appId;

  const DeveloperAppScreen({super.key, required this.appId});

  @override
  State<DeveloperAppScreen> createState() => _DeveloperAppScreenState();
}

class _DeveloperAppScreenState extends State<DeveloperAppScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  DeveloperApp? _app;
  UsageStats? _usage;
  List<APIKeyOut>? _apiKeys;
  List<WebhookOut>? _webhooks;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _token => context.read<AuthProvider>().token!;
  ApiService get _api => context.read<ApiService>();

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getDeveloperApp(_token, widget.appId),
        _api.getAppUsage(_token, widget.appId),
        _api.getApiKeys(_token, widget.appId),
        _api.getWebhooks(_token, widget.appId),
      ]);
      if (mounted) {
        setState(() {
          _app = results[0] as DeveloperApp;
          _usage = results[1] as UsageStats;
          _apiKeys = results[2] as List<APIKeyOut>;
          _webhooks = results[3] as List<WebhookOut>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  // --- Overview Tab ---

  Future<void> _editApp() async {
    final nameController = TextEditingController(text: _app!.name);
    final descController = TextEditingController(text: _app!.description);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit App',
          style: TextStyle(color: Color(0xFF22D3EE)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogTextField(controller: nameController, label: 'App Name'),
            const SizedBox(height: 12),
            _DialogTextField(
              controller: descController,
              label: 'Description',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22D3EE),
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) {
      nameController.dispose();
      descController.dispose();
      return;
    }

    try {
      await _api.updateDeveloperApp(
        _token,
        widget.appId,
        name: nameController.text.trim(),
        description: descController.text.trim(),
      );
      _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update app: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      nameController.dispose();
      descController.dispose();
    }
  }

  Widget _buildOverviewTab() {
    if (_app == null || _usage == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Details Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _app!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _editApp,
                      icon: const Icon(
                        Icons.edit,
                        color: Color(0xFF22D3EE),
                        size: 22,
                      ),
                    ),
                  ],
                ),
                if (_app!.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _app!.description,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                ],
                const SizedBox(height: 16),
                _DetailRow(label: 'Client ID', value: _app!.clientId, mono: true),
                const SizedBox(height: 8),
                _DetailRow(
                  label: 'Status',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _app!.isActive
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _app!.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: _app!.isActive
                            ? Colors.green.shade400
                            : Colors.red.shade400,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _DetailRow(label: 'Created', value: _formatDate(_app!.createdAt)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Usage Stats
          Text(
            'Usage Statistics',
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _StatCard(
                label: 'Total API Calls',
                value: _usage!.totalApiCalls.toString(),
                icon: Icons.api,
              ),
              _StatCard(
                label: 'Active Keys',
                value: _usage!.activeKeys.toString(),
                icon: Icons.vpn_key,
              ),
              _StatCard(
                label: 'Active Webhooks',
                value: '${_usage!.activeWebhooks}/${_usage!.totalWebhooks}',
                icon: Icons.webhook,
              ),
              _StatCard(
                label: 'Deliveries',
                value: '${_usage!.successfulDeliveries}/${_usage!.totalDeliveries}',
                icon: Icons.send,
                subtitle: _usage!.failedDeliveries > 0
                    ? '${_usage!.failedDeliveries} failed'
                    : null,
                subtitleColor: Colors.red.shade400,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- API Keys Tab ---

  Future<void> _createApiKey() async {
    List<String>? availableScopes;
    try {
      availableScopes = await _api.getAvailableScopes(_token);
    } catch (_) {
      availableScopes = ['read', 'write', 'admin'];
    }

    final selectedScopes = <String>{};

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Create API Key',
            style: TextStyle(color: Color(0xFF22D3EE)),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Scopes',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...availableScopes!.map(
                  (scope) => CheckboxListTile(
                    value: selectedScopes.contains(scope),
                    onChanged: (checked) {
                      setDialogState(() {
                        if (checked == true) {
                          selectedScopes.add(scope);
                        } else {
                          selectedScopes.remove(scope);
                        }
                      });
                    },
                    title: Text(
                      scope,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    activeColor: const Color(0xFF22D3EE),
                    checkColor: const Color(0xFF0F172A),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),
            ElevatedButton(
              onPressed: selectedScopes.isEmpty
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22D3EE),
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != true || selectedScopes.isEmpty) return;

    try {
      final created = await _api.createApiKey(
        _token,
        widget.appId,
        selectedScopes.toList(),
      );

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'API Key Created',
              style: TextStyle(color: Color(0xFF22D3EE)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Copy this key now. It will not be shown again.',
                  style: TextStyle(color: Colors.orange.shade300, fontSize: 14),
                ),
                const SizedBox(height: 16),
                _CopyableField(label: 'API Key', value: created.key),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22D3EE),
                  foregroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        );

        _refreshApiKeys();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create API key: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _refreshApiKeys() async {
    try {
      final keys = await _api.getApiKeys(_token, widget.appId);
      if (mounted) setState(() => _apiKeys = keys);
    } catch (_) {}
  }

  Future<void> _deleteApiKey(APIKeyOut key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete API Key',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          'Are you sure you want to delete the key "${key.prefix}..."? This cannot be undone.',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteApiKey(_token, widget.appId, key.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API key deleted'),
            backgroundColor: Color(0xFF22D3EE),
          ),
        );
        _refreshApiKeys();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete key: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Widget _buildApiKeysTab() {
    if (_apiKeys == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
      );
    }

    return Column(
      children: [
        // Create button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _createApiKey,
              icon: const Icon(Icons.add),
              label: const Text('Create New Key'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22D3EE),
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        if (_apiKeys!.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No API keys yet',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _apiKeys!.length,
              itemBuilder: (context, index) {
                final key = _apiKeys![index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.vpn_key,
                            size: 18,
                            color: key.isActive
                                ? const Color(0xFF22D3EE)
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${key.prefix}...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: key.isActive
                                  ? Colors.green.withOpacity(0.15)
                                  : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              key.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: key.isActive
                                    ? Colors.green.shade400
                                    : Colors.red.shade400,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _deleteApiKey(key),
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade400,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: key.scopes
                            .map(
                              (scope) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  scope,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Rate limit: ${key.rateLimit}/min',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          if (key.lastUsed != null)
                            Text(
                              'Last used: ${_formatDate(key.lastUsed!)}',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // --- Webhooks Tab ---

  Future<void> _createWebhook() async {
    final urlController = TextEditingController();
    List<String>? availableEvents;
    try {
      availableEvents = await _api.getAvailableEvents(_token);
    } catch (_) {
      availableEvents = [
        'match.started',
        'match.finished',
        'player.eliminated',
      ];
    }

    final selectedEvents = <String>{};

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Create Webhook',
            style: TextStyle(color: Color(0xFF22D3EE)),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DialogTextField(
                    controller: urlController,
                    label: 'Webhook URL',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Events',
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...availableEvents!.map(
                    (event) => CheckboxListTile(
                      value: selectedEvents.contains(event),
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            selectedEvents.add(event);
                          } else {
                            selectedEvents.remove(event);
                          }
                        });
                      },
                      title: Text(
                        event,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      activeColor: const Color(0xFF22D3EE),
                      checkColor: const Color(0xFF0F172A),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),
            ElevatedButton(
              onPressed: selectedEvents.isEmpty ||
                      urlController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22D3EE),
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != true) {
      urlController.dispose();
      return;
    }

    try {
      await _api.createWebhook(
        _token,
        widget.appId,
        urlController.text.trim(),
        selectedEvents.toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Webhook created'),
            backgroundColor: Color(0xFF22D3EE),
          ),
        );
        _refreshWebhooks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create webhook: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      urlController.dispose();
    }
  }

  Future<void> _refreshWebhooks() async {
    try {
      final webhooks = await _api.getWebhooks(_token, widget.appId);
      if (mounted) setState(() => _webhooks = webhooks);
    } catch (_) {}
  }

  Future<void> _testWebhook(WebhookOut webhook) async {
    try {
      final result = await _api.testWebhook(_token, widget.appId, webhook.id);
      if (mounted) {
        final success = result['success'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Test delivery successful'
                  : 'Test delivery failed: ${result['error'] ?? 'Unknown error'}',
            ),
            backgroundColor:
                success ? Colors.green.shade700 : Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to test webhook: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _viewDeliveries(WebhookOut webhook) async {
    try {
      final deliveries = await _api.getWebhookDeliveries(
        _token,
        widget.appId,
        webhook.id,
      );

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Webhook Deliveries',
                style: TextStyle(
                  color: Colors.grey.shade200,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (deliveries.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No deliveries yet',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: deliveries.length,
                    itemBuilder: (context, index) {
                      final d = deliveries[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  d.success
                                      ? Icons.check_circle
                                      : Icons.error,
                                  size: 18,
                                  color: d.success
                                      ? Colors.green.shade400
                                      : Colors.red.shade400,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  d.event,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                if (d.responseStatus != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (d.responseStatus! < 400
                                              ? Colors.green
                                              : Colors.red)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      d.responseStatus.toString(),
                                      style: TextStyle(
                                        color: d.responseStatus! < 400
                                            ? Colors.green.shade400
                                            : Colors.red.shade400,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDate(d.createdAt),
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load deliveries: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _deleteWebhook(WebhookOut webhook) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Webhook', style: TextStyle(color: Colors.red)),
        content: Text(
          'Are you sure you want to delete the webhook for "${webhook.url}"?',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteWebhook(_token, widget.appId, webhook.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Webhook deleted'),
            backgroundColor: Color(0xFF22D3EE),
          ),
        );
        _refreshWebhooks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete webhook: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Widget _buildWebhooksTab() {
    if (_webhooks == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
      );
    }

    return Column(
      children: [
        // Create button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _createWebhook,
              icon: const Icon(Icons.add),
              label: const Text('Create New Webhook'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22D3EE),
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        if (_webhooks!.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No webhooks yet',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _webhooks!.length,
              itemBuilder: (context, index) {
                final webhook = _webhooks![index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.webhook,
                            size: 18,
                            color: webhook.isActive
                                ? const Color(0xFF22D3EE)
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              webhook.url,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: webhook.isActive
                                  ? Colors.green.withOpacity(0.15)
                                  : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              webhook.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: webhook.isActive
                                    ? Colors.green.shade400
                                    : Colors.red.shade400,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Events
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: webhook.events
                            .map(
                              (event) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22D3EE).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  event,
                                  style: const TextStyle(
                                    color: Color(0xFF22D3EE),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      if (webhook.failureCount > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${webhook.failureCount} failures',
                          style: TextStyle(
                            color: Colors.red.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // Action buttons
                      Row(
                        children: [
                          _SmallActionButton(
                            icon: Icons.send,
                            label: 'Test',
                            onTap: () => _testWebhook(webhook),
                          ),
                          const SizedBox(width: 8),
                          _SmallActionButton(
                            icon: Icons.history,
                            label: 'Deliveries',
                            onTap: () => _viewDeliveries(webhook),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _deleteWebhook(webhook),
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade400,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          _app?.name ?? 'App Details',
          style: const TextStyle(
            color: Color(0xFF22D3EE),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF22D3EE)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF22D3EE),
          labelColor: const Color(0xFF22D3EE),
          unselectedLabelColor: Colors.grey.shade500,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'API Keys'),
            Tab(text: 'Webhooks'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Failed to load app details',
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22D3EE),
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildApiKeysTab(),
        _buildWebhooksTab(),
      ],
    );
  }
}

// --- Shared Widgets ---

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool mono;
  final Widget? child;

  const _DetailRow({
    required this.label,
    this.value,
    this.mono = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ),
        Expanded(
          child: child ??
              SelectableText(
                value ?? '',
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 13,
                  fontFamily: mono ? 'monospace' : null,
                ),
              ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color? subtitleColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF22D3EE), size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                color: subtitleColor ?? Colors.grey.shade500,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

class _CopyableField extends StatelessWidget {
  final String label;
  final String value;

  const _CopyableField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label copied to clipboard'),
                backgroundColor: const Color(0xFF22D3EE),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Icon(Icons.copy, size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;

  const _DialogTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF22D3EE)),
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF22D3EE)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF22D3EE),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
