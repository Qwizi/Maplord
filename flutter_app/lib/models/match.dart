class MatchPlayer {
  final String id;
  final String userId;
  final String username;
  final String color;
  final bool isAlive;
  final String joinedAt;

  MatchPlayer({
    required this.id,
    required this.userId,
    required this.username,
    required this.color,
    required this.isAlive,
    required this.joinedAt,
  });

  factory MatchPlayer.fromJson(Map<String, dynamic> json) => MatchPlayer(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    username: json['username'] as String,
    color: json['color'] as String,
    isAlive: json['is_alive'] as bool,
    joinedAt: json['joined_at'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'username': username,
    'color': color,
    'is_alive': isAlive,
    'joined_at': joinedAt,
  };
}

class Match {
  final String id;
  final String status;
  final int maxPlayers;
  final String? gameModeId;
  final String? winnerId;
  final List<MatchPlayer> players;
  final String? startedAt;
  final String? finishedAt;
  final String createdAt;

  Match({
    required this.id,
    required this.status,
    required this.maxPlayers,
    this.gameModeId,
    this.winnerId,
    required this.players,
    this.startedAt,
    this.finishedAt,
    required this.createdAt,
  });

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    id: json['id'] as String,
    status: json['status'] as String,
    maxPlayers: json['max_players'] as int,
    gameModeId: json['game_mode_id'] as String?,
    winnerId: json['winner_id'] as String?,
    players: (json['players'] as List<dynamic>)
        .map((e) => MatchPlayer.fromJson(e as Map<String, dynamic>))
        .toList(),
    startedAt: json['started_at'] as String?,
    finishedAt: json['finished_at'] as String?,
    createdAt: json['created_at'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'max_players': maxPlayers,
    'game_mode_id': gameModeId,
    'winner_id': winnerId,
    'players': players.map((e) => e.toJson()).toList(),
    'started_at': startedAt,
    'finished_at': finishedAt,
    'created_at': createdAt,
  };
}

class PlayerResult {
  final String userId;
  final String username;
  final int placement;
  final int regionsConquered;
  final int unitsProduced;
  final int unitsLost;
  final int buildingsBuilt;
  final double eloChange;

  PlayerResult({
    required this.userId,
    required this.username,
    required this.placement,
    required this.regionsConquered,
    required this.unitsProduced,
    required this.unitsLost,
    required this.buildingsBuilt,
    required this.eloChange,
  });

  factory PlayerResult.fromJson(Map<String, dynamic> json) => PlayerResult(
    userId: json['user_id'] as String,
    username: json['username'] as String,
    placement: json['placement'] as int,
    regionsConquered: json['regions_conquered'] as int,
    unitsProduced: json['units_produced'] as int,
    unitsLost: json['units_lost'] as int,
    buildingsBuilt: json['buildings_built'] as int,
    eloChange: (json['elo_change'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'username': username,
    'placement': placement,
    'regions_conquered': regionsConquered,
    'units_produced': unitsProduced,
    'units_lost': unitsLost,
    'buildings_built': buildingsBuilt,
    'elo_change': eloChange,
  };
}

class MatchResult {
  final String id;
  final String matchId;
  final int durationSeconds;
  final int totalTicks;
  final List<PlayerResult> playerResults;

  MatchResult({
    required this.id,
    required this.matchId,
    required this.durationSeconds,
    required this.totalTicks,
    required this.playerResults,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
    id: json['id'] as String,
    matchId: json['match_id'] as String,
    durationSeconds: json['duration_seconds'] as int,
    totalTicks: json['total_ticks'] as int,
    playerResults: (json['player_results'] as List<dynamic>)
        .map((e) => PlayerResult.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'match_id': matchId,
    'duration_seconds': durationSeconds,
    'total_ticks': totalTicks,
    'player_results': playerResults.map((e) => e.toJson()).toList(),
  };
}
