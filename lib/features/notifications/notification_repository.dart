import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_model.dart';

class NotificationRepository {
  NotificationRepository();

  final SupabaseClient _client = Supabase.instance.client;

  String get _currentUserId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in.');
    }
    return user.id;
  }

  Future<List<AppNotificationModel>> getNotifications() async {
    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', _currentUserId)
        .order('created_at', ascending: false);

    return response
        .map<AppNotificationModel>((e) => AppNotificationModel.fromJson(e))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', _currentUserId)
        .eq('is_read', false);

    return response.length;
  }

  Future<void> markAllRead() async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _currentUserId)
        .eq('is_read', false);
  }

  Future<void> markRead(String id) async {
    await _client.from('notifications').update({
      'is_read': true,
    }).eq('id', id);
  }

  RealtimeChannel subscribeToNotifications({
    required VoidCallback onNotification,
  }) {
    final channel = _client.channel('notifications-$_currentUserId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final row = payload.newRecord;
            if (row['user_id']?.toString() == _currentUserId) {
              onNotification();
            }
          },
        )
        .subscribe();

    return channel;
  }
}