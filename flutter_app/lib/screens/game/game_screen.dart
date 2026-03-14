import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/game_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../models/game_state.dart';

// -- Constants ---------------------------------------------------------------

const _kCyan = Color(0xFF22D3EE);
const _kBg = Color(0xFF0F172A);
const _kSurface = Color(0xFF1E293B);
const _kSurfaceLight = Color(0xFF334155);

const _kPlayerColors = <Color>[
  Color(0xFF22D3EE), // cyan
  Color(0xFFF87171), // red
  Color(0xFF4ADE80), // green
  Color(0xFFFBBF24), // amber
  Color(0xFFA78BFA), // violet
  Color(0xFFFB923C), // orange
  Color(0xFF38BDF8), // sky
  Color(0xFFF472B6), // pink
];

const _kNeutralColor = Color(0xFF64748B);

// -- Helper ------------------------------------------------------------------

Color _colorFromHex(String hex) {
  final cleaned = hex.replaceAll('#', '');
  if (cleaned.length == 6) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  return _kNeutralColor;
}

Color _playerColor(String? colorHex, int index) {
  if (colorHex != null && colorHex.isNotEmpty) {
    return _colorFromHex(colorHex);
  }
  return _kPlayerColors[index % _kPlayerColors.length];
}

// -- Game Screen -------------------------------------------------------------

class GameScreen extends StatefulWidget {
  final String matchId;

  const GameScreen({super.key, required this.matchId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final MapController _mapController = MapController();
  String? _selectedRegionId;
  String? _targetRegionId;
  double _unitSliderValue = 1;
  String _actionMode = 'none'; // none, attack, move

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectToGame();
    });
  }

  void _connectToGame() {
    final auth = context.read<AuthProvider>();
    final game = context.read<GameProvider>();
    if (auth.token != null) {
      game.connectToMatch(widget.matchId, auth.token!);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // -- Derived helpers -------------------------------------------------------

  String? get _myUserId => context.read<AuthProvider>().user?.id;

  GamePlayer? _myPlayer(GameState state) {
    final uid = _myUserId;
    if (uid == null) return null;
    return state.players[uid];
  }

  int _myRegionCount(GameState state) {
    final uid = _myUserId;
    if (uid == null) return 0;
    return state.regions.values.where((r) => r.ownerId == uid).length;
  }

  int _myTotalUnits(GameState state) {
    final uid = _myUserId;
    if (uid == null) return 0;
    return state.regions.values
        .where((r) => r.ownerId == uid)
        .fold(0, (sum, r) => sum + r.unitCount);
  }

  Map<String, Color> _buildPlayerColorMap(GameState state) {
    final map = <String, Color>{};
    var i = 0;
    for (final entry in state.players.entries) {
      map[entry.key] = _playerColor(entry.value.color, i);
      i++;
    }
    return map;
  }

  // -- Actions ---------------------------------------------------------------

  void _onRegionTap(String regionId) {
    final game = context.read<GameProvider>();
    final state = game.gameState;
    if (state == null) return;

    if (state.meta.status == 'selecting') {
      game.selectCapital(regionId);
      return;
    }

    if (_actionMode == 'attack' || _actionMode == 'move') {
      if (_selectedRegionId != null && regionId != _selectedRegionId) {
        setState(() => _targetRegionId = regionId);
        return;
      }
    }

    setState(() {
      _selectedRegionId = regionId;
      _targetRegionId = null;
      _actionMode = 'none';
      _unitSliderValue = 1;
    });
  }

  void _executeAttack() {
    if (_selectedRegionId == null || _targetRegionId == null) return;
    final game = context.read<GameProvider>();
    game.attack(_selectedRegionId!, _targetRegionId!, _unitSliderValue.round());
    setState(() {
      _actionMode = 'none';
      _targetRegionId = null;
    });
  }

  void _executeMove() {
    if (_selectedRegionId == null || _targetRegionId == null) return;
    final game = context.read<GameProvider>();
    game.moveUnits(
        _selectedRegionId!, _targetRegionId!, _unitSliderValue.round());
    setState(() {
      _actionMode = 'none';
      _targetRegionId = null;
    });
  }

  void _buildStructure(String buildingSlug) {
    if (_selectedRegionId == null) return;
    context.read<GameProvider>().buildStructure(_selectedRegionId!, buildingSlug);
  }

  void _produceUnit(String unitSlug) {
    if (_selectedRegionId == null) return;
    context.read<GameProvider>().produceUnit(_selectedRegionId!, unitSlug);
  }

  void _useAbility(String abilitySlug) {
    if (_selectedRegionId == null) return;
    context.read<GameProvider>().useAbility(_selectedRegionId!, abilitySlug);
  }

  Future<void> _leaveMatch() async {
    final game = context.read<GameProvider>();
    final left = await game.leaveMatch();
    if (left && mounted) {
      game.disconnect();
      context.go('/dashboard');
    }
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, game, _) {
        if (game.gameState == null) {
          return _buildLoadingScreen();
        }

        final state = game.gameState!;

        return Scaffold(
          body: Stack(
            children: [
              // Map layer
              _buildMap(state),

              // Capital selection banner
              if (state.meta.status == 'selecting') _buildCapitalSelectionBanner(),

              // HUD overlay - top left
              if (state.meta.status != 'selecting') _buildHud(state),

              // Player list - top right
              if (state.meta.status != 'selecting') _buildPlayerList(state),

              // Ability bar - left side
              if (state.meta.status == 'in_progress') _buildAbilityBar(),

              // Build queue display
              if (state.meta.status == 'in_progress' &&
                  game.buildingsQueue.isNotEmpty)
                _buildBuildQueueDisplay(game),

              // Action bar at bottom (attack/move slider)
              if (_actionMode != 'none' && _selectedRegionId != null)
                _buildActionBar(state),

              // Game over overlay
              if (state.meta.status == 'finished') _buildGameOverOverlay(state),

              // Back / leave button
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: _buildIconBtn(Icons.arrow_back, () => _leaveMatch()),
              ),
            ],
          ),

          // Region info bottom sheet
          bottomSheet: _selectedRegionId != null &&
                  state.meta.status != 'finished' &&
                  state.meta.status != 'selecting'
              ? _buildRegionInfoSheet(state)
              : null,
        );
      },
    );
  }

  // -- Loading ---------------------------------------------------------------

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: _kBg,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _kCyan),
            SizedBox(height: 24),
            Text(
              'Connecting to match...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // -- Map -------------------------------------------------------------------

  Widget _buildMap(GameState state) {
    final playerColors = _buildPlayerColorMap(state);

    final markers = <CircleMarker>[];
    for (final entry in state.regions.entries) {
      final region = entry.value;
      if (region.centroid == null || region.centroid!.length < 2) continue;

      final lat = region.centroid![1];
      final lng = region.centroid![0];
      final isSelected = entry.key == _selectedRegionId;
      final isTarget = entry.key == _targetRegionId;

      Color fillColor;
      if (region.ownerId != null && playerColors.containsKey(region.ownerId)) {
        fillColor = playerColors[region.ownerId]!;
      } else {
        fillColor = _kNeutralColor;
      }

      double radius = region.isCapital ? 12 : 8;
      if (isSelected) radius = 14;
      if (isTarget) radius = 12;

      Color borderColor = Colors.transparent;
      double borderWidth = 0;
      if (isSelected) {
        borderColor = Colors.white;
        borderWidth = 3;
      } else if (isTarget) {
        borderColor = _actionMode == 'attack'
            ? const Color(0xFFF87171)
            : const Color(0xFF4ADE80);
        borderWidth = 3;
      } else if (region.isCapital) {
        borderColor = Colors.white70;
        borderWidth = 2;
      }

      markers.add(
        CircleMarker(
          point: LatLng(lat, lng),
          radius: radius,
          color: fillColor.withOpacity(isSelected ? 1.0 : 0.75),
          borderColor: borderColor,
          borderStrokeWidth: borderWidth,
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(30, 10),
        initialZoom: 3,
        minZoom: 2,
        maxZoom: 10,
        backgroundColor: const Color(0xFF0A0F1A),
        onTap: (tapPosition, point) {
          _handleMapTap(point, state);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.maplord.app',
          tileBuilder: _darkTileBuilder,
        ),
        CircleLayer(circles: markers),
        // Unit count labels
        MarkerLayer(
          markers: _buildUnitCountMarkers(state),
        ),
      ],
    );
  }

  /// Applies a dark tint to OSM raster tiles.
  Widget _darkTileBuilder(
      BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.3, 0, 0, 0, 0, //
        0, 0.3, 0, 0, 0, //
        0, 0, 0.4, 0, 0, //
        0, 0, 0, 1, 0, //
      ]),
      child: tileWidget,
    );
  }

  List<Marker> _buildUnitCountMarkers(GameState state) {
    final markers = <Marker>[];
    for (final entry in state.regions.entries) {
      final region = entry.value;
      if (region.centroid == null || region.centroid!.length < 2) continue;
      if (region.ownerId == null && region.unitCount == 0) continue;

      final lat = region.centroid![1];
      final lng = region.centroid![0];

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 40,
          height: 20,
          child: IgnorePointer(
            child: Container(
              alignment: Alignment.center,
              child: Text(
                '${region.unitCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(blurRadius: 4, color: Colors.black),
                    Shadow(blurRadius: 8, color: Colors.black),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  void _handleMapTap(LatLng point, GameState state) {
    // Find closest region centroid within a threshold
    String? closest;
    double closestDist = double.infinity;

    for (final entry in state.regions.entries) {
      final region = entry.value;
      if (region.centroid == null || region.centroid!.length < 2) continue;

      final lat = region.centroid![1];
      final lng = region.centroid![0];
      final dist = (point.latitude - lat) * (point.latitude - lat) +
          (point.longitude - lng) * (point.longitude - lng);

      if (dist < closestDist) {
        closestDist = dist;
        closest = entry.key;
      }
    }

    // Threshold depends on zoom level -- at zoom 3, ~5 degrees; at zoom 7, ~0.5
    final zoom = _mapController.camera.zoom;
    final threshold = 50.0 / (zoom * zoom);

    if (closest != null && closestDist < threshold) {
      _onRegionTap(closest);
    } else {
      setState(() {
        if (_actionMode == 'none') {
          _selectedRegionId = null;
          _targetRegionId = null;
        }
      });
    }
  }

  // -- Capital Selection Banner ----------------------------------------------

  Widget _buildCapitalSelectionBanner() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 60,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _kSurface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kCyan.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.flag, color: _kCyan, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SELECT YOUR CAPITAL',
                    style: TextStyle(
                      color: _kCyan,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap a region on the map to claim it as your capital.',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- HUD -------------------------------------------------------------------

  Widget _buildHud(GameState state) {
    final me = _myPlayer(state);
    final currency = me?.currency ?? 0;
    final regionCount = _myRegionCount(state);
    final unitCount = _myTotalUnits(state);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 60,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _kSurface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kCyan.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _hudItem(Icons.timer_outlined, 'T${state.meta.currentTick}'),
            const SizedBox(width: 14),
            _hudItem(Icons.monetization_on_outlined,
                currency.toStringAsFixed(0)),
            const SizedBox(width: 14),
            _hudItem(Icons.map_outlined, '$regionCount'),
            const SizedBox(width: 14),
            _hudItem(Icons.groups_outlined, '$unitCount'),
          ],
        ),
      ),
    );
  }

  Widget _hudItem(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _kCyan, size: 16),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // -- Player List -----------------------------------------------------------

  Widget _buildPlayerList(GameState state) {
    final sorted = state.players.entries.toList()
      ..sort((a, b) {
        // Alive players first, then by region count descending
        if (a.value.isAlive != b.value.isAlive) {
          return a.value.isAlive ? -1 : 1;
        }
        final aRegions =
            state.regions.values.where((r) => r.ownerId == a.key).length;
        final bRegions =
            state.regions.values.where((r) => r.ownerId == b.key).length;
        return bRegions.compareTo(aRegions);
      });

    final playerColors = _buildPlayerColorMap(state);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 8,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kSurface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PLAYERS',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            ...sorted.map((entry) {
              final player = entry.value;
              final color = playerColors[entry.key] ?? _kNeutralColor;
              final regions = state.regions.values
                  .where((r) => r.ownerId == entry.key)
                  .length;
              final isMe = entry.key == _myUserId;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: player.isAlive ? color : color.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: isMe
                            ? Border.all(color: Colors.white, width: 1.5)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        player.username,
                        style: TextStyle(
                          color: player.isAlive
                              ? Colors.white
                              : Colors.white38,
                          fontSize: 11,
                          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                          decoration: player.isAlive
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$regions',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
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

  // -- Ability Bar (left side) -----------------------------------------------

  Widget _buildAbilityBar() {
    final config = context.read<ConfigProvider>();
    final abilities = config.abilities;
    if (abilities.isEmpty) return const SizedBox.shrink();

    final game = context.read<GameProvider>();
    final me = game.gameState != null ? _myPlayer(game.gameState!) : null;
    final cooldowns = me?.abilityCooldowns ?? {};

    return Positioned(
      left: 8,
      top: MediaQuery.of(context).padding.top + 70,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _kSurface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: abilities.map((ability) {
            final cooldown = cooldowns[ability.slug];
            final isOnCooldown =
                cooldown != null && cooldown is num && cooldown > 0;
            final hasCurrency =
                me != null && me.currency >= ability.currencyCost;
            final canUse =
                !isOnCooldown && hasCurrency && _selectedRegionId != null;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Tooltip(
                message:
                    '${ability.name} (${ability.currencyCost} gold)\n${ability.description}',
                child: GestureDetector(
                  onTap: canUse ? () => _useAbility(ability.slug) : null,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: canUse
                          ? _kCyan.withOpacity(0.2)
                          : _kSurfaceLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: canUse
                            ? _kCyan.withOpacity(0.5)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.bolt,
                          color: canUse ? _kCyan : Colors.white24,
                          size: 22,
                        ),
                        if (isOnCooldown)
                          Text(
                            '${(cooldown as num).toInt()}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // -- Build Queue Display ---------------------------------------------------

  Widget _buildBuildQueueDisplay(GameProvider game) {
    final queue = game.buildingsQueue;
    final uid = _myUserId;
    final myQueue = queue.where((q) => q.playerId == uid).toList();
    if (myQueue.isEmpty) return const SizedBox.shrink();

    return Positioned(
      right: 8,
      bottom: MediaQuery.of(context).padding.bottom + 80,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _kSurface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'BUILD QUEUE',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            ...myQueue.map((item) {
              final progress = item.totalTicks > 0
                  ? (item.totalTicks - item.ticksRemaining) / item.totalTicks
                  : 0.0;
              final regionName =
                  game.gameState?.regions[item.regionId]?.name ?? item.regionId;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.buildingType} - $regionName',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_kCyan),
                        minHeight: 4,
                      ),
                    ),
                    Text(
                      '${item.ticksRemaining} ticks left',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 9,
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

  // -- Action Bar (bottom slider) -------------------------------------------

  Widget _buildActionBar(GameState state) {
    final region = state.regions[_selectedRegionId];
    if (region == null) return const SizedBox.shrink();

    final maxUnits = region.unitCount;
    if (maxUnits <= 0) {
      return const SizedBox.shrink();
    }

    final isAttack = _actionMode == 'attack';
    final accentColor = isAttack ? const Color(0xFFF87171) : const Color(0xFF4ADE80);
    final label = isAttack ? 'ATTACK' : 'MOVE';
    final hasTarget = _targetRegionId != null;
    final targetName = _targetRegionId != null
        ? (state.regions[_targetRegionId]?.name ?? _targetRegionId!)
        : 'Select target...';

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 8,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kSurface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withOpacity(0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  isAttack ? Icons.gps_fixed : Icons.move_up,
                  color: accentColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  targetName,
                  style: TextStyle(
                    color: hasTarget ? Colors.white : Colors.white38,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _actionMode = 'none';
                      _targetRegionId = null;
                    });
                  },
                  child: const Icon(Icons.close, color: Colors.white38, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${_unitSliderValue.round()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accentColor,
                      inactiveTrackColor: Colors.white.withOpacity(0.1),
                      thumbColor: accentColor,
                      overlayColor: accentColor.withOpacity(0.2),
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: _unitSliderValue.clamp(1, maxUnits.toDouble()),
                      min: 1,
                      max: maxUnits.toDouble(),
                      divisions: maxUnits > 1 ? maxUnits - 1 : 1,
                      onChanged: (v) => setState(() => _unitSliderValue = v),
                    ),
                  ),
                ),
                Text(
                  '$maxUnits',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: hasTarget
                    ? (isAttack ? _executeAttack : _executeMove)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: _kBg,
                  disabledBackgroundColor: accentColor.withOpacity(0.3),
                  disabledForegroundColor: _kBg.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  hasTarget
                      ? '$label ${_unitSliderValue.round()} units'
                      : 'Tap a region to target',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Region Info Bottom Sheet ----------------------------------------------

  Widget _buildRegionInfoSheet(GameState state) {
    final region = state.regions[_selectedRegionId];
    if (region == null) {
      return const SizedBox.shrink();
    }

    final playerColors = _buildPlayerColorMap(state);
    final ownerName = region.ownerId != null
        ? (state.players[region.ownerId]?.username ?? 'Unknown')
        : 'Neutral';
    final ownerColor = region.ownerId != null
        ? (playerColors[region.ownerId] ?? _kNeutralColor)
        : _kNeutralColor;
    final isMyRegion = region.ownerId == _myUserId;
    final config = context.read<ConfigProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.25,
      minChildSize: 0.12,
      maxChildSize: 0.50,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Region header
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: ownerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          region.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$ownerName  |  ${region.countryCode}${region.isCapital ? "  |  CAPITAL" : ""}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedRegionId = null;
                      _targetRegionId = null;
                      _actionMode = 'none';
                    }),
                    child:
                        const Icon(Icons.close, color: Colors.white38, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Stats row
              Row(
                children: [
                  _regionStat(Icons.groups, '${region.unitCount}', 'Units'),
                  _regionStat(Icons.shield,
                      '+${region.defenseBonus.toStringAsFixed(0)}%', 'Defense'),
                  if (region.buildingType != null)
                    _regionStat(Icons.business, region.buildingType!, 'Building'),
                  if (region.isCoastal == true)
                    _regionStat(Icons.water, 'Yes', 'Coastal'),
                ],
              ),
              const SizedBox(height: 14),

              // Action buttons (only for owned regions)
              if (isMyRegion && _actionMode == 'none') ...[
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        icon: Icons.gps_fixed,
                        label: 'Attack',
                        color: const Color(0xFFF87171),
                        onTap: region.unitCount > 0
                            ? () => setState(() {
                                  _actionMode = 'attack';
                                  _targetRegionId = null;
                                  _unitSliderValue = 1;
                                })
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionButton(
                        icon: Icons.move_up,
                        label: 'Move',
                        color: const Color(0xFF4ADE80),
                        onTap: region.unitCount > 0
                            ? () => setState(() {
                                  _actionMode = 'move';
                                  _targetRegionId = null;
                                  _unitSliderValue = 1;
                                })
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        icon: Icons.construction,
                        label: 'Build',
                        color: const Color(0xFFFBBF24),
                        onTap: () => _showBuildDialog(config, region),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionButton(
                        icon: Icons.add_circle_outline,
                        label: 'Produce',
                        color: const Color(0xFFA78BFA),
                        onTap: () => _showProduceDialog(config, region),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _regionStat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: _kCyan, size: 18),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.15) : _kSurfaceLight.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? color.withOpacity(0.4) : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: enabled ? color : Colors.white24, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: enabled ? color : Colors.white24,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Build / Produce Dialogs -----------------------------------------------

  void _showBuildDialog(ConfigProvider config, GameRegion region) {
    final buildings = config.buildings.where((b) {
      if (b.requiresCoastal && region.isCoastal != true) return false;
      return true;
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BUILD',
                style: TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              if (buildings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No buildings available for this region.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              else
                ...buildings.map((b) => ListTile(
                      leading: const Icon(Icons.business,
                          color: Color(0xFFFBBF24), size: 22),
                      title: Text(b.name,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '${b.currencyCost} gold  |  ${b.buildTimeTicks} ticks',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.add,
                          color: Colors.white38, size: 18),
                      onTap: () {
                        Navigator.pop(ctx);
                        _buildStructure(b.slug);
                      },
                    )),
            ],
          ),
        );
      },
    );
  }

  void _showProduceDialog(ConfigProvider config, GameRegion region) {
    final units = config.units;

    showModalBottomSheet(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PRODUCE UNIT',
                style: TextStyle(
                  color: Color(0xFFA78BFA),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              if (units.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No unit types available.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              else
                ...units.map((u) => ListTile(
                      leading: const Icon(Icons.person,
                          color: Color(0xFFA78BFA), size: 22),
                      title: Text(u.name,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '${u.productionCost} gold  |  ${u.productionTimeTicks} ticks  |  ATK ${u.attack} DEF ${u.defense}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.add,
                          color: Colors.white38, size: 18),
                      onTap: () {
                        Navigator.pop(ctx);
                        _produceUnit(u.slug);
                      },
                    )),
            ],
          ),
        );
      },
    );
  }

  // -- Game Over Overlay -----------------------------------------------------

  Widget _buildGameOverOverlay(GameState state) {
    // Find the winner (alive player with most regions, or the last alive)
    final alivePlayers =
        state.players.entries.where((e) => e.value.isAlive).toList();
    String? winnerId;
    String winnerName = 'Unknown';

    if (alivePlayers.length == 1) {
      winnerId = alivePlayers.first.key;
      winnerName = alivePlayers.first.value.username;
    } else if (alivePlayers.isNotEmpty) {
      // Most regions wins
      alivePlayers.sort((a, b) {
        final aR =
            state.regions.values.where((r) => r.ownerId == a.key).length;
        final bR =
            state.regions.values.where((r) => r.ownerId == b.key).length;
        return bR.compareTo(aR);
      });
      winnerId = alivePlayers.first.key;
      winnerName = alivePlayers.first.value.username;
    }

    final isWinner = winnerId == _myUserId;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.75),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isWinner
                    ? const Color(0xFFFBBF24).withOpacity(0.5)
                    : const Color(0xFFF87171).withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isWinner ? Icons.emoji_events : Icons.flag,
                  color: isWinner
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFFF87171),
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  isWinner ? 'VICTORY!' : 'GAME OVER',
                  style: TextStyle(
                    color: isWinner
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFF87171),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isWinner
                      ? 'You conquered the map!'
                      : '$winnerName wins the match',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Final tick: ${state.meta.currentTick}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 200,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<GameProvider>().disconnect();
                      context.go('/dashboard');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kCyan,
                      foregroundColor: _kBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Back to Lobby',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- Shared Widgets --------------------------------------------------------

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _kSurface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }
}
