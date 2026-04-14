import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_comment_model.dart';

class CommunityCommentRepository {
  CommunityCommentRepository();

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<CommunityCommentModel>> getComments(String postId) async {
    final response = await _client
        .from('community_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return response
        .map<CommunityCommentModel>((e) => CommunityCommentModel.fromJson(e))
        .toList();
  }

  Future<void> addComment({
    required String postId,
    required String body,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated.');

    await _client.from('community_comments').insert({
      'post_id': postId,
      'user_id': user.id,
      'body': body,
    });
  }
}
