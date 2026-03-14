class LeaderboardEntry {
  final String id;
  final String username;
  final double eloRating;
  final int matchesPlayed;
  final int wins;
  final double winRate;
  final double averagePlacement;

  LeaderboardEntry({
    required this.id,
    required this.username,
    required this.eloRating,
    required this.matchesPlayed,
    required this.wins,
    required this.winRate,
    required this.averagePlacement,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
    id: json['id'] as String,
    username: json['username'] as String,
    eloRating: (json['elo_rating'] as num).toDouble(),
    matchesPlayed: json['matches_played'] as int,
    wins: json['wins'] as int,
    winRate: (json['win_rate'] as num).toDouble(),
    averagePlacement: (json['average_placement'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'elo_rating': eloRating,
    'matches_played': matchesPlayed,
    'wins': wins,
    'win_rate': winRate,
    'average_placement': averagePlacement,
  };
}
