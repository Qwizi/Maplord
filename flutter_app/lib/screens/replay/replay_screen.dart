import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/share.dart';
import '../../models/game_state.dart';

class ReplayScreen extends StatefulWidget {
  final String matchId;

  const ReplayScreen({super.key, required this.matchId});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  final MapController _mapController = MapController();

  List<SnapshotTick>? _snapshots;
  SnapshotDetail? _currentSnapshot;
  GameState? _currentGameState;
  int _currentIndex = 0;
  bool _loading = true;
  bool _loadingSnapshot = false;
  String? _error;
  bool _playing = false;
  double _speed = 1.0;
  Timer? _playTimer;

  static const List<double> _speeds = [1.0, 2.0, 4.0, 8.0];

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadSnapshots() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final api = context.read<ApiService>();
      final snapshots = await api.getMatchSnapshots(
        auth.token!,
        widget.matchId,
      );
      if (mounted) {
        setState(() {
          _snapshots = snapshots;
          _loading = false;
        });
        if (snapshots.isNotEmpty) {
          await _loadSnapshotAt(0);
        }
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

  Future<void> _loadSnapshotAt(int index) async {
    if (_snapshots == null || index < 0 || index >= _snapshots!.length) return;

    setState(() {
      _loadingSnapshot = true;
      _currentIndex = index;
    });

    try {
      final auth = context.read<AuthProvider>();
      final api = context.read<ApiService>();
      final snapshot = await api.getSnapshot(
        auth.token!,
        widget.matchId,
        _snapshots![index].tick,
      );
      if (mounted) {
        setState(() {
          _currentSnapshot = snapshot;
          _currentGameState = GameState.fromJson(snapshot.stateData);
          _loadingSnapshot = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingSnapshot = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load snapshot: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _togglePlay() {
    if (_playing) {
      _playTimer?.cancel();
      setState(() => _playing = false);
    } else {
      setState(() => _playing = true);
      _startPlayback();
    }
  }

  void _startPlayback() {
    _playTimer?.cancel();
    final intervalMs = (1000 / _speed).round();
    _playTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!mounted) {
        _playTimer?.cancel();
        return;
      }
      if (_currentIndex < (_snapshots?.length ?? 1) - 1) {
        _loadSnapshotAt(_currentIndex + 1);
      } else {
        _playTimer?.cancel();
        setState(() => _playing = false);
      }
    });
  }

  void _setSpeed(double speed) {
    setState(() => _speed = speed);
    if (_playing) {
      _startPlayback();
    }
  }

  Color _parsePlayerColor(String colorStr) {
    try {
      final hex = colorStr.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF22D3EE);
    }
  }

  List<Marker> _buildRegionMarkers() {
    if (_currentGameState == null) return [];

    final markers = <Marker>[];
    final players = _currentGameState!.players;

    for (final entry in _currentGameState!.regions.entries) {
      final region = entry.value;
      if (region.ownerId == null || region.centroid == null) continue;
      if (region.centroid!.length < 2) continue;

      final player = players[region.ownerId];
      final color = player != null
          ? _parsePlayerColor(player.color)
          : const Color(0xFF22D3EE);

      final lat = region.centroid![1];
      final lng = region.centroid![0];

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 24,
          height: 24,
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(
                color: region.isCapital ? Colors.white : color,
                width: region.isCapital ? 3 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: region.unitCount > 0
                ? Text(
                    region.unitCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Replay',
          style: TextStyle(
            color: Color(0xFF22D3EE),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF22D3EE)),
        elevation: 0,
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
              'Failed to load replay',
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
              onPressed: _loadSnapshots,
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

    if (_snapshots == null || _snapshots!.isEmpty) {
      return Center(
        child: Text(
          'No snapshots available for this match',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
        ),
      );
    }

    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(30, 0),
            initialZoom: 3,
            minZoom: 2,
            maxZoom: 8,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.maplord.app',
              tileBuilder: (context, tileWidget, tile) {
                return ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    0.2126, 0.7152, 0.0722, 0, -40,
                    0.2126, 0.7152, 0.0722, 0, -40,
                    0.2126, 0.7152, 0.0722, 0, -40,
                    0,      0,      0,      1,   0,
                  ]),
                  child: tileWidget,
                );
              },
            ),
            MarkerLayer(markers: _buildRegionMarkers()),
          ],
        ),
        // Player legend overlay
        if (_currentGameState != null)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: _currentGameState!.players.values.map((player) {
                  final color = _parsePlayerColor(player.color);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          player.username,
                          style: TextStyle(
                            color: player.isAlive
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontSize: 13,
                            decoration: player.isAlive
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        // Tick info overlay
        if (_currentSnapshot != null)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Tick ${_snapshots![_currentIndex].tick}',
                style: const TextStyle(
                  color: Color(0xFF22D3EE),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        // Loading snapshot indicator
        if (_loadingSnapshot)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF22D3EE),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Loading...',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Bottom controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Timeline scrubber
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFF22D3EE),
                    inactiveTrackColor: Colors.white.withOpacity(0.1),
                    thumbColor: const Color(0xFF22D3EE),
                    overlayColor: const Color(0xFF22D3EE).withOpacity(0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _currentIndex.toDouble(),
                    min: 0,
                    max: (_snapshots!.length - 1).toDouble(),
                    divisions: _snapshots!.length > 1
                        ? _snapshots!.length - 1
                        : null,
                    onChanged: (value) {
                      final idx = value.round();
                      if (idx != _currentIndex) {
                        _loadSnapshotAt(idx);
                      }
                    },
                  ),
                ),
                // Controls row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Play/Pause button
                    IconButton(
                      onPressed: _togglePlay,
                      icon: Icon(
                        _playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 44,
                        color: const Color(0xFF22D3EE),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Speed selector
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: _speeds.map((speed) {
                          final isSelected = _speed == speed;
                          return GestureDetector(
                            onTap: () => _setSpeed(speed),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF22D3EE)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${speed.toStringAsFixed(0)}x',
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF0F172A)
                                      : Colors.grey.shade400,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
