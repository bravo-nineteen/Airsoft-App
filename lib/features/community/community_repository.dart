import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_model.dart';

class CommunityRepository {
  CommunityRepository();

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<CommunityModel>> getPosts() async {
    final response = await _client
        .from('community_posts')
        .select()
        .order('created_at', ascending: false);

    return response.map<CommunityModel>((e) => CommunityModel.fromJson(e)).toList();
  }

  Future<void> createPost({
    required String title,
    required String body,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated.');

    await _client.from('community_posts').insert({
      'user_id': user.id,
      'title': title,
      'body': body,
    });
  }
}
