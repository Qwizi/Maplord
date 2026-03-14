import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/game_state.dart';

class BuildQueuePanel extends StatelessWidget {
  final List<BuildingQueueItem> buildingsQueue;
  final List<UnitQueueItem> unitQueue;
  final String myUserId;

  const BuildQueuePanel({
    super.key,
    required this.buildingsQueue,
    required this.unitQueue,
    required this.myUserId,
  });

  @override
  Widget build(BuildContext context) {
    final myBuildings = buildingsQueue.where((b) => b.playerId == myUserId).toList();
    final myUnits = unitQueue.where((u) => u.playerId == myUserId).toList();

    if (myBuildings.isEmpty && myUnits.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 8,
      bottom: 80,
      child: Container(
        width: 180,
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
              'Production Queue',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...myBuildings.map((b) => _QueueItem(
              icon: Icons.business,
              name: b.buildingType,
              progress: 1 - (b.ticksRemaining / b.totalTicks),
              remaining: b.ticksRemaining,
            )),
            ...myUnits.map((u) => _QueueItem(
              icon: Icons.person_add,
              name: '${u.unitType} x${u.quantity}',
              progress: 1 - (u.ticksRemaining / u.totalTicks),
              remaining: u.ticksRemaining,
            )),
          ],
        ),
      ),
    );
  }
}

class _QueueItem extends StatelessWidget {
  final IconData icon;
  final String name;
  final double progress;
  final int remaining;

  const _QueueItem({
    required this.icon,
    required this.name,
    required this.progress,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${remaining}t',
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.bgLight,
            color: AppTheme.primary,
            minHeight: 3,
          ),
        ],
      ),
    );
  }
}
