import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushTokenRepository {
  PushTokenRepository();

  final SupabaseClient _client = Supabase.instance.client;

  Future<void> upsertToken({
    required String token,
    required String platform,
    String? deviceName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }

    final String now = DateTime.now().toIso8601String();
    final Map<String, dynamic> fullPayload = <String, dynamic>{
      'user_id': user.id,
      'token': token,
      'platform': platform,
      'device_name': deviceName,
      'is_active': true,
      'last_seen_at': now,
      'updated_at': now,
    };

    try {
      await _client.from('device_tokens').upsert(
            fullPayload,
            onConflict: 'token',
          );
      return;
    } on PostgrestException {
      // Fallback for older schemas that only include a subset of columns.
      await _client.from('device_tokens').upsert(
            {
              'user_id': user.id,
              'token': token,
              'platform': platform,
              'updated_at': now,
            },
            onConflict: 'token',
          );
    }
  }

  Future<void> deactivateToken(String token) async {
    final String now = DateTime.now().toIso8601String();
    try {
      await _client
          .from('device_tokens')
          .update({
            'is_active': false,
            'updated_at': now,
          })
          .eq('token', token);
    } on PostgrestException {
      // Fallback for schemas without is_active.
      await _client
          .from('device_tokens')
          .update({'updated_at': now})
          .eq('token', token);
    }
  }

  Future<void> debugPrintMyTokens() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final rows = await _client
        .from('device_tokens')
        .select()
        .eq('user_id', user.id);
    debugPrint('Saved tokens: $rows');
  }
}
