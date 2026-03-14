import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/game_config.dart';

class AbilityBar extends StatelessWidget {
  final List<AbilityType> abilities;
  final Map<String, int>? cooldowns;
  final int currentTick;
  final double currency;
  final String? selectedRegionId;
  final void Function(String abilitySlug) onUseAbility;

  const AbilityBar({
    super.key,
    required this.abilities,
    this.cooldowns,
    required this.currentTick,
    required this.currency,
    this.selectedRegionId,
    required this.onUseAbility,
  });

  @override
  Widget build(BuildContext context) {
    if (abilities.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 8,
      top: MediaQuery.of(context).size.height * 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: abilities.map((ability) {
          final cooldownTick = cooldowns?[ability.slug] ?? 0;
          final isOnCooldown = cooldownTick > currentTick;
          final canAfford = currency >= ability.currencyCost;
          final hasTarget = selectedRegionId != null;
          final isEnabled = !isOnCooldown && canAfford && hasTarget;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AbilityButton(
              ability: ability,
              isOnCooldown: isOnCooldown,
              cooldownRemaining: isOnCooldown ? cooldownTick - currentTick : 0,
              canAfford: canAfford,
              isEnabled: isEnabled,
              onTap: isEnabled
                  ? () => onUseAbility(ability.slug)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AbilityButton extends StatelessWidget {
  final AbilityType ability;
  final bool isOnCooldown;
  final int cooldownRemaining;
  final bool canAfford;
  final bool isEnabled;
  final VoidCallback? onTap;

  const _AbilityButton({
    required this.ability,
    required this.isOnCooldown,
    required this.cooldownRemaining,
    required this.canAfford,
    required this.isEnabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${ability.name}\n${ability.description}\nCost: ${ability.currencyCost}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isEnabled
                ? AppTheme.primary.withOpacity(0.2)
                : AppTheme.bgDark.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEnabled
                  ? AppTheme.primary
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  _getAbilityIcon(ability.slug),
                  size: 24,
                  color: isEnabled ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
              if (isOnCooldown)
                Center(
                  child: Text(
                    '$cooldownRemaining',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (!canAfford && !isOnCooldown)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppTheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.monetization_on,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getAbilityIcon(String slug) {
    switch (slug) {
      case 'nuke':
        return Icons.local_fire_department;
      case 'virus':
        return Icons.bug_report;
      case 'shield':
        return Icons.shield;
      case 'spy':
        return Icons.visibility;
      case 'sabotage':
        return Icons.construction;
      default:
        return Icons.auto_awesome;
    }
  }
}
