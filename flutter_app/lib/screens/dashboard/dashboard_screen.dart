import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/matchmaking_provider.dart';
import '../../models/match.dart' as models;
import '../../services/api_service.dart';

const _kCyan = Color(0xFF22D3EE);
const _kBgDark = Color(0xFF0F172A);
const _kBgLight = Color(0xFF1E293B);
const _kCardBg = Color(0xFF1E293B);
const _kCardBorder = Color(0x1AFFFFFF); // white 10%

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _navIndex = 0;
  List<models.Match>? _recentMatches;
  bool _loadingMatches = false;
  String? _matchesError;
  String? _selectedGameModeSlug;

  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
      // Listen for match found to auto-navigate
      context.read<MatchmakingProvider>().addListener(_onMatchmakingChanged);
    });
  }

  void _onMatchmakingChanged() {
    final matchmaking = context.read<MatchmakingProvider>();
    final matchId = matchmaking.matchId;
    if (matchId != null && mounted) {
      matchmaking.clearMatchId();
      context.go('/game/$matchId');
    }
  }

  @override
  void dispose() {
    _dotController.dispose();
    // Remove listener safely — provider may already be disposed
    try {
      context.read<MatchmakingProvider>().removeListener(_onMatchmakingChanged);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _initData() async {
    final configProvider = context.read<ConfigProvider>();
    if (configProvider.config == null && !configProvider.loading) {
      configProvider.loadConfig();
    }
    await _loadRecentMatches();
  }

  Future<void> _loadRecentMatches() async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null) return;

    setState(() {
      _loadingMatches = true;
      _matchesError = null;
    });

    try {
      final api = context.read<ApiService>();
      final matches = await api.getMyMatches(auth.token!);
      if (mounted) {
        setState(() {
          _recentMatches = matches;
          _loadingMatches = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _matchesError = e.toString();
          _loadingMatches = false;
        });
      }
    }
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        setState(() => _navIndex = 0);
        break;
      case 1:
        context.go('/leaderboard');
        break;
      case 2:
        context.go('/developers');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBgDark, _kBgLight],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: RefreshIndicator(
                  color: _kCyan,
                  backgroundColor: _kCardBg,
                  onRefresh: () async {
                    await context.read<AuthProvider>().refreshUser();
                    await context.read<ConfigProvider>().loadConfig();
                    await _loadRecentMatches();
                  },
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      const SizedBox(height: 16),
                      _buildPlayerStatsCard(),
                      const SizedBox(height: 24),
                      _buildActiveMatchBanner(),
                      _buildTutorialButton(),
                      _buildSectionTitle('GAME MODES'),
                      const SizedBox(height: 12),
                      _buildGameModeGrid(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('MATCHMAKING'),
                      const SizedBox(height: 12),
                      _buildMatchmakingSection(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('RECENT MATCHES'),
                      const SizedBox(height: 12),
                      _buildRecentMatchesList(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ---------------------------------------------------------------------------
  // App Bar
  // ---------------------------------------------------------------------------

  Widget _buildAppBar() {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kBgDark.withOpacity(0.8),
        border: const Border(
          bottom: BorderSide(color: _kCardBorder),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'MAPLORD',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _kCyan,
              letterSpacing: 3,
            ),
          ),
          const Spacer(),
          if (user != null) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: _kCyan.withOpacity(0.2),
              child: Text(
                user.username.isNotEmpty
                    ? user.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: _kCyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Logout',
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Player Stats Card
  // ---------------------------------------------------------------------------

  Widget _buildPlayerStatsCard() {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
        boxShadow: [
          BoxShadow(
            color: _kCyan.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: _kCyan.withOpacity(0.15),
            child: Icon(
              Icons.person,
              size: 32,
              color: _kCyan,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      'ELO ${user.eloRating.toInt()}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildRoleBadge(user.role),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    IconData badgeIcon;

    switch (role.toLowerCase()) {
      case 'admin':
        badgeColor = Colors.red.shade400;
        badgeIcon = Icons.admin_panel_settings;
        break;
      case 'moderator':
        badgeColor = Colors.orange.shade400;
        badgeIcon = Icons.shield;
        break;
      default:
        badgeColor = _kCyan;
        badgeIcon = Icons.military_tech;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: badgeColor,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Active Match Banner
  // ---------------------------------------------------------------------------

  Widget _buildActiveMatchBanner() {
    final matchmaking = context.watch<MatchmakingProvider>();
    final activeMatchId = matchmaking.activeMatchId;

    if (activeMatchId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade900.withOpacity(0.3),
              Colors.orange.shade900.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Match',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'You have an active match in progress.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                context.go('/game/$activeMatchId');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: _kBgDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text(
                'Rejoin',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tutorial Button
  // ---------------------------------------------------------------------------

  Widget _buildTutorialButton() {
    final user = context.watch<AuthProvider>().user;
    if (user == null || user.tutorialCompleted) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade900.withOpacity(0.3),
              Colors.teal.shade900.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.school_rounded, color: Colors.greenAccent, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New to MapLord?',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Complete the tutorial to learn the basics.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => context.go('/tutorial'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: _kBgDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text(
                'Start Tutorial',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section Title
  // ---------------------------------------------------------------------------

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: _kCyan,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Game Mode Grid
  // ---------------------------------------------------------------------------

  Widget _buildGameModeGrid() {
    final configProvider = context.watch<ConfigProvider>();

    if (configProvider.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: _kCyan),
        ),
      );
    }

    if (configProvider.error != null) {
      return _buildErrorCard(
        'Failed to load game modes',
        configProvider.error!,
        onRetry: () => configProvider.loadConfig(),
      );
    }

    final gameModes = configProvider.gameModes;
    if (gameModes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No game modes available.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: gameModes.length,
      itemBuilder: (context, index) {
        final mode = gameModes[index];
        final isSelected = _selectedGameModeSlug == mode.slug;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedGameModeSlug =
                  isSelected ? null : mode.slug;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? _kCyan.withOpacity(0.1)
                  : _kCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? _kCyan
                    : _kCardBorder,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mode.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color:
                              isSelected ? _kCyan : Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (mode.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kCyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'DEFAULT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _kCyan,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    mode.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.people_outline,
                        size: 14, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(
                      '${mode.minPlayers}-${mode.maxPlayers} players',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Matchmaking Section
  // ---------------------------------------------------------------------------

  Widget _buildMatchmakingSection() {
    final matchmaking = context.watch<MatchmakingProvider>();
    final auth = context.watch<AuthProvider>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        children: [
          // Fill with Bots toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.smart_toy_outlined,
                      size: 18, color: Colors.white54),
                  const SizedBox(width: 8),
                  const Text(
                    'Fill with Bots',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              Switch(
                value: matchmaking.fillBots,
                onChanged: matchmaking.inQueue
                    ? null
                    : (val) => matchmaking.fillBots = val,
                activeColor: _kCyan,
                activeTrackColor: _kCyan.withOpacity(0.3),
                inactiveThumbColor: Colors.white38,
                inactiveTrackColor: Colors.white12,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (matchmaking.inQueue) ...[
            // In queue state
            _buildQueueStatus(matchmaking),
          ] else ...[
            // Find match button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: auth.token == null
                    ? null
                    : () {
                        matchmaking.joinQueue(
                          auth.token!,
                          gameModeSlug: _selectedGameModeSlug,
                        );
                      },
                icon: const Icon(Icons.search, size: 22),
                label: const Text(
                  'Find Match',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kCyan,
                  foregroundColor: _kBgDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            if (_selectedGameModeSlug != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Mode: $_selectedGameModeSlug',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildQueueStatus(MatchmakingProvider matchmaking) {
    return Column(
      children: [
        // Animated searching indicator
        AnimatedBuilder(
          animation: _dotController,
          builder: (context, child) {
            final dotCount = (_dotController.value * 4).floor() % 4;
            final dots = '.' * dotCount;
            return Text(
              'Searching$dots',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kCyan,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // Player count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _kCyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people, size: 16, color: _kCyan),
              const SizedBox(width: 6),
              Text(
                '${matchmaking.playersInQueue} in queue',
                style: const TextStyle(
                  color: _kCyan,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => matchmaking.leaveQueue(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade400,
              side: BorderSide(color: Colors.red.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Recent Matches List
  // ---------------------------------------------------------------------------

  Widget _buildRecentMatchesList() {
    if (_loadingMatches) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: _kCyan),
        ),
      );
    }

    if (_matchesError != null) {
      return _buildErrorCard(
        'Failed to load matches',
        _matchesError!,
        onRetry: _loadRecentMatches,
      );
    }

    final matches = _recentMatches;
    if (matches == null || matches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kCardBorder),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.history, size: 40, color: Colors.white24),
              SizedBox(height: 8),
              Text(
                'No matches yet. Start your first game!',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Show last 10 matches
    final displayMatches = matches.take(10).toList();

    return Column(
      children: displayMatches.map((match) => _buildMatchTile(match)).toList(),
    );
  }

  Widget _buildMatchTile(models.Match match) {
    final statusColor = _matchStatusColor(match.status);
    final statusLabel = _matchStatusLabel(match.status);
    final dateStr = _formatDate(match.createdAt);

    // Determine winner username if finished
    String? winnerName;
    if (match.winnerId != null) {
      try {
        winnerName = match.players
            .firstWhere((p) => p.userId == match.winnerId)
            .username;
      } catch (_) {
        winnerName = null;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (match.status == 'finished') {
              context.go('/match-result/${match.id}');
            } else if (match.status == 'in_progress') {
              context.go('/game/${match.id}');
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kCardBorder),
            ),
            child: Row(
              children: [
                // Status badge
                Container(
                  width: 8,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.people_outline,
                              size: 14, color: Colors.white38),
                          const SizedBox(width: 3),
                          Text(
                            '${match.players.length}/${match.maxPlayers}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (winnerName != null) ...[
                            const Icon(Icons.emoji_events,
                                size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              winnerName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.amber,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white30,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error Card
  // ---------------------------------------------------------------------------

  Widget _buildErrorCard(String title, String message,
      {VoidCallback? onRetry}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade800.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.red.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: _kCyan),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom Navigation Bar
  // ---------------------------------------------------------------------------

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: _kBgDark,
        border: Border(top: BorderSide(color: _kCardBorder)),
      ),
      child: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: _onNavTap,
        backgroundColor: Colors.transparent,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _kCyan,
        unselectedItemColor: Colors.white38,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events),
            label: 'Leaderboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.code_outlined),
            activeIcon: Icon(Icons.code),
            label: 'Developers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Color _matchStatusColor(String status) {
    switch (status) {
      case 'waiting':
        return Colors.blue.shade400;
      case 'in_progress':
        return Colors.green.shade400;
      case 'finished':
        return Colors.grey.shade400;
      case 'cancelled':
        return Colors.red.shade400;
      default:
        return Colors.white38;
    }
  }

  String _matchStatusLabel(String status) {
    switch (status) {
      case 'waiting':
        return 'WAITING';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'finished':
        return 'FINISHED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return status.toUpperCase();
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
