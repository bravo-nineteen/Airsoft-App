import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_model.dart';

class NotificationRepository {
  NotificationRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  String get _currentUserId {
    final user = _resolvedClient.auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in.');
    }
    return user.id;
  }

  Future<List<AppNotificationModel>> getNotifications() async {
    final response = await _resolvedClient
        .from('notifications')
        .select()
        .eq('user_id', _currentUserId)
        .neq('type', 'direct_message')
        .order('created_at', ascending: false);

    return response
        .map<AppNotificationModel>((e) => AppNotificationModel.fromJson(e))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _resolvedClient
        .from('notifications')
        .select('id')
        .eq('user_id', _currentUserId)
        .neq('type', 'direct_message')
        .eq('is_read', false);

    return response.length;
  }

  Future<void> markAllRead() async {
    try {
      await _resolvedClient
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _currentUserId)
          .neq('type', 'direct_message')
          .eq('is_read', false);
    } on PostgrestException catch (error) {
      if (!_isMissingUpdatedAtTriggerError(error)) {
        rethrow;
      }

      // Older schemas can keep a trigger bound to `updated_at` before the
      // column exists. In that case, keep navigation usable and leave unread
      // state unchanged instead of hard-failing UI interactions.
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _resolvedClient.from('notifications').update({
        'is_read': true,
      }).eq('id', id);
    } on PostgrestException catch (error) {
      if (!_isMissingUpdatedAtTriggerError(error)) {
        rethrow;
      }
    }
  }

  Future<void> deleteNotification(String id) async {
    await _resolvedClient
        .from('notifications')
        .delete()
        .eq('id', id)
        .eq('user_id', _currentUserId);
  }

  RealtimeChannel subscribeToNotifications({
    required VoidCallback onNotification,
  }) {
    final channel = _resolvedClient.channel('notifications-$_currentUserId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final row = payload.newRecord;
            if (row['user_id']?.toString() == _currentUserId &&
                row['type']?.toString() != 'direct_message') {
              onNotification();
            }
          },
        )
        .subscribe();

    return channel;
  }

  bool _isMissingUpdatedAtTriggerError(PostgrestException error) {
    if (error.code != '42703' && error.code != 'PGRST204') {
      return false;
    }

    final String summary =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return summary.contains('updated_at') && summary.contains('new');
  }
}