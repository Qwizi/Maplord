import 'match.dart';

class ShareLink {
  final String token;
  final String resourceType;
  final String resourceId;

  ShareLink({
    required this.token,
    required this.resourceType,
    required this.resourceId,
  });

  factory ShareLink.fromJson(Map<String, dynamic> json) => ShareLink(
    token: json['token'] as String,
    resourceType: json['resource_type'] as String,
    resourceId: json['resource_id'] as String,
  );

  Map<String, dynamic> toJson() => {
    'token': token,
    'resource_type': resourceType,
    'resource_id': resourceId,
  };
}

class SnapshotTick {
  final int tick;
  final String createdAt;

  SnapshotTick({required this.tick, required this.createdAt});

  factory SnapshotTick.fromJson(Map<String, dynamic> json) => SnapshotTick(
    tick: json['tick'] as int,
    createdAt: json['created_at'] as String,
  );

  Map<String, dynamic> toJson() => {
    'tick': tick,
    'created_at': createdAt,
  };
}

class SharedMatchData {
  final String resourceType;
  final Match match;
  final MatchResult? result;
  final List<int> snapshotTicks;

  SharedMatchData({
    required this.resourceType,
    required this.match,
    this.result,
    required this.snapshotTicks,
  });

  factory SharedMatchData.fromJson(Map<String, dynamic> json) => SharedMatchData(
    resourceType: json['resource_type'] as String,
    match: Match.fromJson(json['match'] as Map<String, dynamic>),
    result: json['result'] != null
        ? MatchResult.fromJson(json['result'] as Map<String, dynamic>)
        : null,
    snapshotTicks: (json['snapshot_ticks'] as List<dynamic>).cast<int>(),
  );

  Map<String, dynamic> toJson() => {
    'resource_type': resourceType,
    'match': match.toJson(),
    'result': result?.toJson(),
    'snapshot_ticks': snapshotTicks,
  };
}

class SnapshotDetail {
  final int tick;
  final Map<String, dynamic> stateData;
  final String createdAt;

  SnapshotDetail({
    required this.tick,
    required this.stateData,
    required this.createdAt,
  });

  factory SnapshotDetail.fromJson(Map<String, dynamic> json) => SnapshotDetail(
    tick: json['tick'] as int,
    stateData: json['state_data'] as Map<String, dynamic>,
    createdAt: json['created_at'] as String,
  );

  Map<String, dynamic> toJson() => {
    'tick': tick,
    'state_data': stateData,
    'created_at': createdAt,
  };
}
