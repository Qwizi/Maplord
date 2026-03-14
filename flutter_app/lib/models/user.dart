class User {
  final String id;
  final String username;
  final String email;
  final String role;
  final double eloRating;
  final String dateJoined;
  final bool tutorialCompleted;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.eloRating,
    required this.dateJoined,
    required this.tutorialCompleted,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
    role: json['role'] as String,
    eloRating: (json['elo_rating'] as num).toDouble(),
    dateJoined: json['date_joined'] as String,
    tutorialCompleted: json['tutorial_completed'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'role': role,
    'elo_rating': eloRating,
    'date_joined': dateJoined,
    'tutorial_completed': tutorialCompleted,
  };
}
