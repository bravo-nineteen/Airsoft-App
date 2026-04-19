import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationWriter {
  NotificationWriter({SupabaseClient? client})
    : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  Future<String> getCurrentActorName() async {
    final User? user = _resolvedClient.auth.currentUser;
    if (user == null) {
      return 'Someone';
    }

    try {
      final Map<String, dynamic>? profile = await _resolvedClient
          .from('profiles')
          .select('call_sign')
          .eq('id', user.id)
          .maybeSingle();
      final String? callSign = _readNullableString(profile?['call_sign']);
      if (callSign != null) {
        return callSign;
      }
    } catch (_) {}

    final String? email = _readNullableString(user.email);
    return email ?? 'Someone';
  }

  Future<void> safeCreateNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? entityId,
    String? actorUserId,
  }) async {
    try {
      await createNotification(
        userId: userId,
        type: type,
        title: title,
        body: body,
        entityId: entityId,
        actorUserId: actorUserId,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to create notification: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? entityId,
    String? actorUserId,
  }) async {
    final String? recipientId = _readNullableString(userId);
    if (recipientId == null) {
      return;
    }

    final String? currentUserId = _resolvedClient.auth.currentUser?.id;
    if (currentUserId != null && currentUserId == recipientId) {
      return;
    }

    await _resolvedClient.from('notifications').insert({
      'user_id': recipientId,
      'actor_user_id': _readNullableString(actorUserId) ?? currentUserId,
      'type': type.trim(),
      'entity_id': _readNullableString(entityId),
      'title': title.trim().isEmpty ? 'Notification' : title.trim(),
      'body': body.trim().isEmpty ? 'Open the app to view details.' : body.trim(),
      'is_read': false,
    });
  }

  String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}