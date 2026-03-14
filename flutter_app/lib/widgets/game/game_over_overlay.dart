import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app_theme.dart';
import '../../models/game_state.dart';

class GameOverOverlay extends StatelessWidget {
  final GameState gameState;
  final String myUserId;
  final String matchId;

  const GameOverOverlay({
    super.key,
    required this.gameState,
    required this.myUserId,
    required this.matchId,
  });

  @override
  Widget build(BuildContext context) {
    // Find winner (player with most regions or last alive)
    final alivePlayers = gameState.players.entries
        .where((e) => e.value.isAlive)
        .toList();
    final winner = alivePlayers.isNotEmpty ? alivePlayers.first : null;
    final isWinner = winner?.key == myUserId;
    final myPlayer = gameState.players[myUserId];
    final isEliminated = myPlayer != null && !myPlayer.isAlive;

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.bgMedium,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isWinner ? AppTheme.accent : AppTheme.primary,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isWinner ? AppTheme.accent : AppTheme.primary).withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isWinner ? Icons.emoji_events : Icons.flag,
                size: 64,
                color: isWinner ? AppTheme.accent : AppTheme.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                isWinner ? 'VICTORY!' : (isEliminated ? 'DEFEATED' : 'GAME OVER'),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isWinner ? AppTheme.accent : Colors.white,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              if (winner != null)
                Text(
                  'Winner: ${winner.value.username}',
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
              const SizedBox(height: 32),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.go('/match/$matchId'),
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('View Results'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/dashboard'),
                    icon: const Icon(Icons.home),
                    label: const Text('Dashboard'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CapitalSelectionOverlay extends StatelessWidget {
  final String? capitalSelectionEndsAt;

  const CapitalSelectionOverlay({
    super.key,
    this.capitalSelectionEndsAt,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgDark.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag, color: AppTheme.accent, size: 28),
              const SizedBox(height: 8),
              const Text(
                'SELECT YOUR CAPITAL',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap a region on the map to place your capital',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
