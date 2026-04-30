import 'package:supabase_flutter/supabase_flutter.dart';

class AdAccessRepository {
  AdAccessRepository();

  final SupabaseClient _client = Supabase.instance.client;

  Future<bool> shouldShowAds() async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      return true;
    }

    final DateTime nowUtc = DateTime.now().toUtc();

    final List<dynamic> rows = await _client
        .from('ad_free_membership_requests')
        .select('status, expires_at')
        .eq('requester_user_id', user.id)
        .order('created_at', ascending: false)
        .limit(5);

    for (final dynamic row in rows) {
      if (row is! Map) {
        continue;
      }
      final Map<String, dynamic> record = Map<String, dynamic>.from(row);
      final String status = (record['status'] ?? '').toString().toLowerCase();
      if (status != 'active') {
        continue;
      }
      final DateTime? expiresAt = DateTime.tryParse(
        (record['expires_at'] ?? '').toString(),
      )?.toUtc();
      if (expiresAt != null && expiresAt.isAfter(nowUtc)) {
        return false;
      }
    }

    return true;
  }
}
