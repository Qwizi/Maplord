class DeveloperApp {
  final String id;
  final String name;
  final String description;
  final String clientId;
  final bool isActive;
  final String createdAt;

  DeveloperApp({
    required this.id,
    required this.name,
    required this.description,
    required this.clientId,
    required this.isActive,
    required this.createdAt,
  });

  factory DeveloperApp.fromJson(Map<String, dynamic> json) => DeveloperApp(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    clientId: json['client_id'] as String,
    isActive: json['is_active'] as bool,
    createdAt: json['created_at'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'client_id': clientId,
    'is_active': isActive,
    'created_at': createdAt,
  };
}

class DeveloperAppCreated extends DeveloperApp {
  final String clientSecret;

  DeveloperAppCreated({
    required super.id,
    required super.name,
    required super.description,
    required super.clientId,
    required super.isActive,
    required super.createdAt,
    required this.clientSecret,
  });

  factory DeveloperAppCreated.fromJson(Map<String, dynamic> json) => DeveloperAppCreated(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    clientId: json['client_id'] as String,
    isActive: json['is_active'] as bool,
    createdAt: json['created_at'] as String,
    clientSecret: json['client_secret'] as String,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'client_secret': clientSecret,
  };
}

class APIKeyOut {
  final String id;
  final String prefix;
  final List<String> scopes;
  final int rateLimit;
  final bool isActive;
  final String? lastUsed;
  final String createdAt;

  APIKeyOut({
    required this.id,
    required this.prefix,
    required this.scopes,
    required this.rateLimit,
    required this.isActive,
    this.lastUsed,
    required this.createdAt,
  });

  factory APIKeyOut.fromJson(Map<String, dynamic> json) => APIKeyOut(
    id: json['id'] as String,
    prefix: json['prefix'] as String,
    scopes: (json['scopes'] as List<dynamic>).cast<String>(),
    rateLimit: json['rate_limit'] as int,
    isActive: json['is_active'] as bool,
    lastUsed: json['last_used'] as String?,
    createdAt: json['created_at'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'prefix': prefix,
    'scopes': scopes,
    'rate_limit': rateLimit,
    'is_active': isActive,
    'last_used': lastUsed,
    'created_at': createdAt,
  };
}

class APIKeyCreated extends APIKeyOut {
  final String key;

  APIKeyCreated({
    required super.id,
    required super.prefix,
    required super.scopes,
    required super.rateLimit,
    required super.isActive,
    super.lastUsed,
    required super.createdAt,
    required this.key,
  });

  factory APIKeyCreated.fromJson(Map<String, dynamic> json) => APIKeyCreated(
    id: json['id'] as String,
    prefix: json['prefix'] as String,
    scopes: (json['scopes'] as List<dynamic>).cast<String>(),
    rateLimit: json['rate_limit'] as int,
    isActive: json['is_active'] as bool,
    lastUsed: json['last_used'] as String?,
    createdAt: json['created_at'] as String,
    key: json['key'] as String,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'key': key,
  };
}

class WebhookOut {
  final String id;
  final String url;
  final String secret;
  final List<String> events;
  final bool isActive;
  final int failureCount;
  final String createdAt;

  WebhookOut({
    required this.id,
    required this.url,
    required this.secret,
    required this.events,
    required this.isActive,
    required this.failureCount,
    required this.createdAt,
  });

  factory WebhookOut.fromJson(Map<String, dynamic> json) => WebhookOut(
    id: json['id'] as String,
    url: json['url'] as String,
    secret: json['secret'] as String,
    events: (json['events'] as List<dynamic>).cast<String>(),
    isActive: json['is_active'] as bool,
    failureCount: json['failure_count'] as int,
    createdAt: json['created_at'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'secret': secret,
    'events': events,
    'is_active': isActive,
    'failure_count': failureCount,
    'created_at': createdAt,
  };
}

class WebhookDelivery {
  final String id;
  final String event;
  final Map<String, dynamic> payload;
  final int? responseStatus;
  final bool success;
  final String createdAt;

  WebhookDelivery({
    required this.id,
    required this.event,
    required this.payload,
    this.responseStatus,
    required this.success,
    required this.createdAt,
  });

  factory WebhookDelivery.fromJson(Map<String, dynamic> json) => WebhookDelivery(
    id: json['id'] as String,
    event: json['event'] as String,
    payload: json['payload'] as Map<String, dynamic>,
    responseStatus: json['response_status'] as int?,
    success: json['success'] as bool,
    createdAt: json['created_at'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'event': event,
    'payload': payload,
    'response_status': responseStatus,
    'success': success,
    'created_at': createdAt,
  };
}

class UsageStats {
  final String appId;
  final int totalApiCalls;
  final int activeKeys;
  final int totalWebhooks;
  final int activeWebhooks;
  final int totalDeliveries;
  final int successfulDeliveries;
  final int failedDeliveries;

  UsageStats({
    required this.appId,
    required this.totalApiCalls,
    required this.activeKeys,
    required this.totalWebhooks,
    required this.activeWebhooks,
    required this.totalDeliveries,
    required this.successfulDeliveries,
    required this.failedDeliveries,
  });

  factory UsageStats.fromJson(Map<String, dynamic> json) => UsageStats(
    appId: json['app_id'] as String,
    totalApiCalls: json['total_api_calls'] as int,
    activeKeys: json['active_keys'] as int,
    totalWebhooks: json['total_webhooks'] as int,
    activeWebhooks: json['active_webhooks'] as int,
    totalDeliveries: json['total_deliveries'] as int,
    successfulDeliveries: json['successful_deliveries'] as int,
    failedDeliveries: json['failed_deliveries'] as int,
  );

  Map<String, dynamic> toJson() => {
    'app_id': appId,
    'total_api_calls': totalApiCalls,
    'active_keys': activeKeys,
    'total_webhooks': totalWebhooks,
    'active_webhooks': activeWebhooks,
    'total_deliveries': totalDeliveries,
    'successful_deliveries': successfulDeliveries,
    'failed_deliveries': failedDeliveries,
  };
}
