import 'package:supabase_flutter/supabase_flutter.dart';

import 'direct_message_thread_model.dart';

class DirectMessageThreadRepository {
  DirectMessageThreadRepository();

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<DirectMessageThreadModel>> getThreads() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in.');
    }

    final response = await _client
        .from('direct_message_threads')
        .select()
        .eq('current_user_id', user.id)
        .order('last_message_at', ascending: false);

    return response
        .map<DirectMessageThreadModel>(
          (e) => DirectMessageThreadModel.fromJson(e),
        )
        .toList();
  }
}