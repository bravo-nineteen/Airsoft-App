import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_preferences_model.dart';

class NotificationRepository {
  NotificationRepository();

  final SupabaseClient _client = Supabase.instance.client;

  Future<NotificationPreferencesModel> getOrCreatePreferences() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }

    final existing = await _client
        .from('notification_preferences')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing != null) {
      return NotificationPreferencesModel.fromJson(existing);
    }

    final inserted = await _client
        .from('notification_preferences')
        .insert({
          'user_id': user.id,
          'event_notifications': true,
          'meetup_notifications': true,
          'direct_message_notifications': true,
          'field_update_notifications': true,
        })
        .select()
        .single();

    return NotificationPreferencesModel.fromJson(inserted);
  }

  Future<NotificationPreferencesModel> updatePreferences(
    NotificationPreferencesModel preferences,
  ) async {
    final updated = await _client
        .from('notification_preferences')
        .upsert({
          ...preferences.toJson(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return NotificationPreferencesModel.fromJson(updated);
  }
}
