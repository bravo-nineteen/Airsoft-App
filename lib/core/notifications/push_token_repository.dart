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

    await _client.from('user_devices').upsert(
      {
        'user_id': user.id,
        'fcm_token': token,
        'platform': platform,
        'device_name': deviceName,
        'is_active': true,
        'last_seen_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'fcm_token',
    );
  }

  Future<void> deactivateToken(String token) async {
    await _client
        .from('user_devices')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('fcm_token', token);
  }

  Future<void> debugPrintMyTokens() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final rows = await _client.from('user_devices').select().eq('user_id', user.id);
    debugPrint('Saved tokens: $rows');
  }
}
