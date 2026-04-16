import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_comment_model.dart';
import 'community_repository.dart';

class CommunityCommentRepository {
  CommunityCommentRepository();

  final SupabaseClient _client = Supabase.instance.client;
  final CommunityRepository _communityRepository = CommunityRepository();

  Future<List<CommunityCommentModel>> getComments(String postId) async {
    final safePostId = _sanitizeUuid(postId);
    if (safePostId == null) {
      return [];
    }

    final response = await _client
        .from('community_comments')
        .select()
        .eq('post_id', safePostId)
        .order('created_at', ascending: true);

    var comments = response
        .map<CommunityCommentModel>((row) => CommunityCommentModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .where((comment) => comment.id.isNotEmpty)
        .toList();

    if (comments.isEmpty) {
      return comments;
    }

    final userIds = comments
        .map((comment) => _sanitizeUuid(comment.userId))
        .whereType<String>()
        .toSet()
        .toList();

    if (userIds.isEmpty) {
      return comments;
    }

    final profilesResponse = await _client
        .from('profiles')
        .select('id, call_sign, avatar_url')
        .inFilter('id', userIds);

    final profiles = <String, Map<String, dynamic>>{};
    for (final row in profilesResponse) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = _sanitizeUuid(map['id']?.toString());
      if (id != null) {
        profiles[id] = map;
      }
    }

    comments = comments.map((comment) {
      final profile = profiles[comment.userId];
      if (profile == null) {
        return comment;
      }

      return CommunityCommentModel.fromJson({
        'id': comment.id,
        'post_id': comment.postId,
        'user_id': comment.userId,
        'body': comment.body,
        'created_at': comment.createdAt.toIso8601String(),
        'call_sign': profile['call_sign'],
        'avatar_url': profile['avatar_url'],
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

    final safePostId = _sanitizeUuid(postId);
    if (safePostId == null) {
      throw Exception('Invalid post id.');
    }

    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      throw Exception('Comment cannot be empty.');
    }

    final safeParentCommentId = _sanitizeUuid(parentCommentId);

    await _client.from('community_comments').insert({
      'post_id': safePostId,
      'user_id': user.id,
      'body': trimmedBody,
      'parent_comment_id': safeParentCommentId,
    });

    await _communityRepository.bumpUpdatedAt(safePostId);
  }

  String? _sanitizeUuid(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase() == 'null') return null;
    if (!_isValidUuid(trimmed)) return null;
    return trimmed;
  }

  bool _isValidUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}
