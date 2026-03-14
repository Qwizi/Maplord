import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/game_state.dart';
import '../../models/game_config.dart';

class RegionPanel extends StatefulWidget {
  final String regionId;
  final GameRegion region;
  final GamePlayer? owner;
  final bool isMyRegion;
  final List<BuildingType> buildingTypes;
  final List<UnitType> unitTypes;
  final List<String> neighborIds;
  final Map<String, GameRegion> allRegions;
  final String myUserId;
  final void Function(String sourceRegionId, String targetRegionId, int units, {String? unitType}) onAttack;
  final void Function(String sourceRegionId, String targetRegionId, int units, {String? unitType}) onMove;
  final void Function(String regionId, String buildingType) onBuild;
  final void Function(String regionId, String unitType) onProduceUnit;

  const RegionPanel({
    super.key,
    required this.regionId,
    required this.region,
    this.owner,
    required this.isMyRegion,
    required this.buildingTypes,
    required this.unitTypes,
    required this.neighborIds,
    required this.allRegions,
    required this.myUserId,
    required this.onAttack,
    required this.onMove,
    required this.onBuild,
    required this.onProduceUnit,
  });

  @override
  State<RegionPanel> createState() => _RegionPanelState();
}

class _RegionPanelState extends State<RegionPanel> {
  int _unitCount = 1;
  String? _selectedTarget;
  String _actionMode = 'none'; // 'none', 'attack', 'move'
  String? _selectedUnitType;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.1,
      maxChildSize: 0.7,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.bgMedium,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Region header
              Row(
                children: [
                  if (widget.region.isCapital)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.star, color: AppTheme.accent, size: 20),
                    ),
                  Expanded(
                    child: Text(
                      widget.region.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (widget.owner != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _parseColor(widget.owner!.color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.owner!.username,
                        style: TextStyle(
                          fontSize: 12,
                          color: _parseColor(widget.owner!.color),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Stats row
              Row(
                children: [
                  _buildStat(Icons.groups, 'Units', '${widget.region.unitCount}'),
                  const SizedBox(width: 16),
                  _buildStat(Icons.shield, 'Defense', '+${widget.region.defenseBonus}'),
                  if (widget.region.buildingType != null) ...[
                    const SizedBox(width: 16),
                    _buildStat(Icons.business, 'Building', widget.region.buildingType!),
                  ],
                ],
              ),
              // Buildings info
              if (widget.region.buildings != null && widget.region.buildings!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Buildings', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: widget.region.buildings!.entries.map((e) {
                    return Chip(
                      label: Text('${e.key} x${e.value}', style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppTheme.bgLight,
                    );
                  }).toList(),
                ),
              ],
              // Unit types info
              if (widget.region.units != null && widget.region.units!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Unit Types', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: widget.region.units!.entries.map((e) {
                    return Chip(
                      label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppTheme.bgLight,
                    );
                  }).toList(),
                ),
              ],
              // Actions for own regions
              if (widget.isMyRegion) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                // Attack / Move buttons
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.gps_fixed,
                        label: 'Attack',
                        isActive: _actionMode == 'attack',
                        onTap: () => setState(() {
                          _actionMode = _actionMode == 'attack' ? 'none' : 'attack';
                          _selectedTarget = null;
                        }),
                        color: AppTheme.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.swap_horiz,
                        label: 'Move',
                        isActive: _actionMode == 'move',
                        onTap: () => setState(() {
                          _actionMode = _actionMode == 'move' ? 'none' : 'move';
                          _selectedTarget = null;
                        }),
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                // Target and unit selection
                if (_actionMode != 'none') ...[
                  const SizedBox(height: 12),
                  // Target selector
                  DropdownButtonFormField<String>(
                    value: _selectedTarget,
                    decoration: const InputDecoration(
                      labelText: 'Target Region',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    dropdownColor: AppTheme.bgLight,
                    items: _getTargetRegions().map((id) {
                      final r = widget.allRegions[id];
                      return DropdownMenuItem(
                        value: id,
                        child: Text(r?.name ?? id, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedTarget = v),
                  ),
                  const SizedBox(height: 12),
                  // Unit count slider
                  Row(
                    children: [
                      const Text('Units: ', style: TextStyle(color: AppTheme.textSecondary)),
                      Expanded(
                        child: Slider(
                          value: _unitCount.toDouble(),
                          min: 1,
                          max: widget.region.unitCount.toDouble().clamp(1, double.infinity),
                          divisions: widget.region.unitCount > 1 ? widget.region.unitCount - 1 : 1,
                          label: '$_unitCount',
                          activeColor: AppTheme.primary,
                          onChanged: (v) => setState(() => _unitCount = v.round()),
                        ),
                      ),
                      Text('$_unitCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  // Execute button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectedTarget != null
                          ? () {
                              if (_actionMode == 'attack') {
                                widget.onAttack(widget.regionId, _selectedTarget!, _unitCount, unitType: _selectedUnitType);
                              } else {
                                widget.onMove(widget.regionId, _selectedTarget!, _unitCount, unitType: _selectedUnitType);
                              }
                              setState(() {
                                _actionMode = 'none';
                                _selectedTarget = null;
                              });
                            }
                          : null,
                      icon: Icon(_actionMode == 'attack' ? Icons.gps_fixed : Icons.swap_horiz),
                      label: Text(_actionMode == 'attack' ? 'Attack' : 'Move'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _actionMode == 'attack' ? AppTheme.error : AppTheme.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Build section
                const Text('Build', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.buildingTypes.map((bt) {
                    final canBuild = !bt.requiresCoastal || (widget.region.isCoastal ?? false);
                    return ActionChip(
                      label: Text('${bt.name} (${bt.currencyCost})', style: const TextStyle(fontSize: 12)),
                      avatar: const Icon(Icons.business, size: 16),
                      onPressed: canBuild ? () => widget.onBuild(widget.regionId, bt.slug) : null,
                      backgroundColor: canBuild ? AppTheme.bgLight : AppTheme.bgDark,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Produce units section
                const Text('Produce Units', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.unitTypes.map((ut) {
                    return ActionChip(
                      label: Text('${ut.name} (${ut.productionCost})', style: const TextStyle(fontSize: 12)),
                      avatar: const Icon(Icons.person_add, size: 16),
                      onPressed: () => widget.onProduceUnit(widget.regionId, ut.slug),
                      backgroundColor: AppTheme.bgLight,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<String> _getTargetRegions() {
    if (_actionMode == 'attack') {
      return widget.neighborIds.where((id) {
        final r = widget.allRegions[id];
        return r != null && r.ownerId != widget.myUserId;
      }).toList();
    } else {
      return widget.neighborIds.where((id) {
        final r = widget.allRegions[id];
        return r != null && r.ownerId == widget.myUserId;
      }).toList();
    }
  }

  Widget _buildStat(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : AppTheme.bgLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? color : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
