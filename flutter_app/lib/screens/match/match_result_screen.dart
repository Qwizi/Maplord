import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/match.dart' as models;

class MatchResultScreen extends StatefulWidget {
  final String matchId;

  const MatchResultScreen({super.key, required this.matchId});

  @override
  State<MatchResultScreen> createState() => _MatchResultScreenState();
}

class _MatchResultScreenState extends State<MatchResultScreen> {
  models.Match? _match;
  models.MatchResult? _result;
  bool _loading = true;
  String? _error;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final api = context.read<ApiService>();
      final token = auth.token!;
      final results = await Future.wait([
        api.getMatch(token, widget.matchId),
        api.getMatchResult(token, widget.matchId),
      ]);
      if (mounted) {
        setState(() {
          _match = results[0] as models.Match;
          _result = results[1] as models.MatchResult;
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

  Future<void> _shareMatch() async {
    setState(() => _sharing = true);
    try {
      final auth = context.read<AuthProvider>();
      final api = context.read<ApiService>();
      final shareLink = await api.createShareLink(
        auth.token!,
        'match',
        widget.matchId,
      );
      final url = '${api.baseUrl.replaceAll('/api/v1', '')}/share/${shareLink.token}';
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Share link copied to clipboard'),
            backgroundColor: Color(0xFF22D3EE),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create share link: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Match Result',
          style: TextStyle(
            color: Color(0xFF22D3EE),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF22D3EE)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
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
              'Failed to load match result',
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
              onPressed: _loadData,
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

    final result = _result!;
    final match = _match!;
    final sortedResults = List<models.PlayerResult>.from(result.playerResults)
      ..sort((a, b) => a.placement.compareTo(b.placement));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Match Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.flag,
                  color: Color(0xFF22D3EE),
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Match Complete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _InfoColumn(
                      label: 'Duration',
                      value: _formatDuration(result.durationSeconds),
                    ),
                    _InfoColumn(
                      label: 'Total Ticks',
                      value: result.totalTicks.toString(),
                    ),
                    _InfoColumn(
                      label: 'Players',
                      value: match.maxPlayers.toString(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Player Results
          Text(
            'Player Results',
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...sortedResults.map(
            (pr) => _PlayerResultCard(
              playerResult: pr,
              isWinner: pr.placement == 1,
              winnerId: match.winnerId,
            ),
          ),
          const SizedBox(height: 24),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _sharing ? null : _shareMatch,
                    icon: _sharing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0F172A),
                            ),
                          )
                        : const Icon(Icons.share),
                    label: const Text('Share'),
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
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/replay/${widget.matchId}'),
                    icon: const Icon(Icons.replay),
                    label: const Text('Watch Replay'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF22D3EE),
                      side: const BorderSide(color: Color(0xFF22D3EE)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;

  const _InfoColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF22D3EE),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      ],
    );
  }
}

class _PlayerResultCard extends StatelessWidget {
  final models.PlayerResult playerResult;
  final bool isWinner;
  final String? winnerId;

  const _PlayerResultCard({
    required this.playerResult,
    required this.isWinner,
    this.winnerId,
  });

  @override
  Widget build(BuildContext context) {
    final pr = playerResult;
    final eloColor = pr.eloChange >= 0 ? Colors.green.shade400 : Colors.red.shade400;
    final eloPrefix = pr.eloChange >= 0 ? '+' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: isWinner
            ? Border.all(color: const Color(0xFFFFD700), width: 2)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Placement
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isWinner
                        ? const Color(0xFFFFD700).withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: isWinner
                      ? const Icon(
                          Icons.emoji_events,
                          color: Color(0xFFFFD700),
                          size: 20,
                        )
                      : Text(
                          '#${pr.placement}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pr.username,
                    style: TextStyle(
                      color: isWinner
                          ? const Color(0xFFFFD700)
                          : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // ELO change
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: eloColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$eloPrefix${pr.eloChange.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: eloColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MiniStat(
                  icon: Icons.map,
                  value: pr.regionsConquered.toString(),
                  label: 'Regions',
                ),
                _MiniStat(
                  icon: Icons.groups,
                  value: pr.unitsProduced.toString(),
                  label: 'Produced',
                ),
                _MiniStat(
                  icon: Icons.dangerous,
                  value: pr.unitsLost.toString(),
                  label: 'Lost',
                ),
                _MiniStat(
                  icon: Icons.home_work,
                  value: pr.buildingsBuilt.toString(),
                  label: 'Buildings',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
        ),
      ],
    );
  }
}
