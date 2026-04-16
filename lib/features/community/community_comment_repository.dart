import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_comment_model.dart';
import 'community_repository.dart';

class CommunityCommentRepository {
  CommunityCommentRepository();

  final SupabaseClient _client = Supabase.instance.client;
  final CommunityRepository _communityRepository = CommunityRepository();

  Future<List<CommunityCommentModel>> getComments(String postId) async {
    final response = await _client
        .from('community_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    var comments = response
        .map<CommunityCommentModel>((e) => CommunityCommentModel.fromJson(e))
        .toList();

    if (comments.isEmpty) return comments;

    final userIds = comments.map((e) => e.userId).toSet().toList();

    final profilesResponse = await _client
        .from('profiles')
        .select('id, call_sign, avatar_url')
        .inFilter('id', userIds);

    final profiles = <String, Map<String, dynamic>>{
      for (final row in profilesResponse) row['id'].toString(): row,
    };

    comments = comments.map((comment) {
      final profile = profiles[comment.userId];
      return CommunityCommentModel.fromJson({
        'id': comment.id,
        'post_id': comment.postId,
        'user_id': comment.userId,
        'body': comment.body,
        'created_at': comment.createdAt.toIso8601String(),
        'call_sign': profile?['call_sign'],
        'avatar_url': profile?['avatar_url'],
        'parent_comment_id': comment.parentCommentId,
      });
    }).toList();

    return comments;
  }

  Future<void> addComment({
  required String postId,
  required String body,
  String? parentCommentId,
}) async {
  final user = _client.auth.currentUser;
  if (user == null) {
    throw Exception('You must be logged in to comment.');
  }

  final trimmedBody = body.trim();
  if (trimmedBody.isEmpty) {
    throw Exception('Comment cannot be empty.');
  }

  if (postId.isEmpty) {
    throw Exception('Invalid postId');
  }

  // Critical fix: ensure UUID or null
  String? safeParentId;
  if (parentCommentId != null && parentCommentId.trim().isNotEmpty) {
    safeParentId = parentCommentId;
  } else {
    safeParentId = null;
  }

  await _client.from('community_comments').insert({
    'post_id': postId,
    'user_id': user.id,
    'body': trimmedBody,
    'parent_comment_id': safeParentId,
  });

  await _communityRepository.bumpUpdatedAt(postId);
}
}