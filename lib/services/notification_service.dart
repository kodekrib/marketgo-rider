import 'api_client.dart';

/// An in-app notification returned by the backend.
class RiderNotification {
  const RiderNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.referenceId,
    this.referenceType,
  });

  final int id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final int? referenceId;
  final String? referenceType;

  factory RiderNotification.fromJson(Map<String, dynamic> json) {
    return RiderNotification(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      referenceId: (json['reference_id'] as num?)?.toInt(),
      referenceType: json['reference_type'] as String?,
    );
  }
}

/// Thin client over the notification endpoints for the rider app.
class RiderNotificationService {
  RiderNotificationService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Map<String, String> _auth(String token) =>
      {'Authorization': 'Bearer $token'};

  Future<List<RiderNotification>> list(String token, {int limit = 20, int offset = 0}) async {
    final data = await api.get(
      '/api/v1/notifications?limit=$limit&offset=$offset',
      headers: _auth(token),
    );
    final list = data['notifications'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(RiderNotification.fromJson)
        .toList();
  }

  Future<int> unreadCount(String token) async {
    final data = await api.get(
      '/api/v1/notifications/unread',
      headers: _auth(token),
    );
    return (data['unread_count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String token, int id) async {
    await api.post('/api/v1/notifications/$id/read', headers: _auth(token));
  }

  Future<void> markAllRead(String token) async {
    await api.post('/api/v1/notifications/read-all', headers: _auth(token));
  }
}
