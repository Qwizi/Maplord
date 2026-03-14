import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/game_state.dart';

class GameHUD extends StatelessWidget {
  final GameState gameState;
  final String myUserId;

  const GameHUD({
    super.key,
    required this.gameState,
    required this.myUserId,
  });

  @override
  Widget build(BuildContext context) {
    final myPlayer = gameState.players[myUserId];
    final tick = int.tryParse(gameState.meta.currentTick) ?? 0;
    final myRegions = gameState.regions.entries
        .where((e) => e.value.ownerId == myUserId)
        .length;
    final myUnits = gameState.regions.entries
        .where((e) => e.value.ownerId == myUserId)
        .fold<int>(0, (sum, e) => sum + e.value.unitCount);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgDark.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRow(Icons.access_time, 'Tick', '$tick'),
            const SizedBox(height: 6),
            _buildRow(Icons.monetization_on, 'Currency',
                '${myPlayer?.currency.toStringAsFixed(0) ?? '0'}'),
            const SizedBox(height: 6),
            _buildRow(Icons.map, 'Regions', '$myRegions'),
            const SizedBox(height: 6),
            _buildRow(Icons.groups, 'Units', '$myUnits'),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class PlayerList extends StatelessWidget {
  final Map<String, GamePlayer> players;
  final Map<String, GameRegion> regions;
  final String myUserId;

  const PlayerList({
    super.key,
    required this.players,
    required this.regions,
    required this.myUserId,
  });

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = players.entries.toList()
      ..sort((a, b) {
        final aRegions = regions.values.where((r) => r.ownerId == a.key).length;
        final bRegions = regions.values.where((r) => r.ownerId == b.key).length;
        return bRegions.compareTo(aRegions);
      });

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 8,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.bgDark.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Players',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            ...sortedPlayers.map((entry) {
              final player = entry.value;
              final regionCount = regions.values
                  .where((r) => r.ownerId == entry.key)
                  .length;
              final color = _parseColor(player.color);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        player.username,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: player.isAlive ? Colors.white : AppTheme.textSecondary,
                          decoration: player.isAlive ? null : TextDecoration.lineThrough,
                          fontWeight: entry.key == myUserId
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      '$regionCount',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String color) {
    try {
      if (color.startsWith('#')) {
        return Color(int.parse('FF${color.substring(1)}', radix: 16));
      }
      return AppTheme.primary;
    } catch (_) {
      return AppTheme.primary;
    }
  }
}
