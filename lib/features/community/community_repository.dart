import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_model.dart';

class CommunityRepository {
  CommunityRepository({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> _fetchCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    final response = await _client
        .from('profiles')
        .select('id, call_sign, avatar_url, bio')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  Future<bool> _hasTable(String tableName) async {
    try {
      await _client.from(tableName).select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> _countRows(
    String tableName,
    String foreignKey,
    String foreignId,
  ) async {
    try {
      final response =
          await _client.from(tableName).select('id').eq(foreignKey, foreignId);
      return (response as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> _isLikedByCurrentUser(
    String tableName,
    String foreignKey,
    String foreignId,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return false;
    }

    try {
      final response = await _client
          .from(tableName)
          .select('id')
          .eq(foreignKey, foreignId)
          .eq('user_id', user.id)
          .maybeSingle();

      return response != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<CommunityPostModel>> fetchPosts({
    String query = '',
    String category = 'All',
  }) async {
    final response = await _client
        .from('community_posts')
        .select()
        .eq('is_deleted', false)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);

    var posts = (response as List<dynamic>)
        .map(
          (dynamic e) => CommunityPostModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      posts = posts.where((CommunityPostModel post) {
        return post.title.toLowerCase().contains(normalizedQuery) ||
            post.plainText.toLowerCase().contains(normalizedQuery) ||
            post.bodyText.toLowerCase().contains(normalizedQuery) ||
            (post.category ?? '').toLowerCase().contains(normalizedQuery) ||
            post.authorName.toLowerCase().contains(normalizedQuery);
      }).toList();
    }

    if (category != 'All') {
      posts = posts
          .where(
            (CommunityPostModel post) => (post.category ?? 'General') == category,
          )
          .toList();
    }

    return posts;
  }

  Future<List<CommunityPostModel>> fetchPostsByAuthor(String userId) async {
    final response = await _client
        .from('community_posts')
        .select()
        .eq('is_deleted', false)
        .or('author_id.eq.$userId,user_id.eq.$userId')
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map(
          (dynamic e) => CommunityPostModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<CommunityPostModel> fetchPostById(String postId) async {
    final response = await _client
        .from('community_posts')
        .select()
        .eq('id', postId)
        .single();

    var post = CommunityPostModel.fromJson(Map<String, dynamic>.from(response));

    final hasLikesTable = await _hasTable('community_post_likes');
    if (hasLikesTable) {
      final likeCount =
          await _countRows('community_post_likes', 'post_id', postId);
      final isLikedByMe =
          await _isLikedByCurrentUser('community_post_likes', 'post_id', postId);

      post = post.copyWith(
        likeCount: likeCount,
        isLikedByMe: isLikedByMe,
      );
    }

    return post;
  }

  Future<List<CommunityCommentModel>> fetchComments(String postId) async {
    final response = await _client
        .from('community_comments')
        .select(
          'id, created_at, post_id, author_id, user_id, author_name, author_avatar_url, message, body, like_count',
        )
        .eq('post_id', postId)
        .eq('is_deleted', false)
        .order('created_at', ascending: true);

    final comments = (response as List<dynamic>)
        .map(
          (dynamic e) => CommunityCommentModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    final hasLikesTable = await _hasTable('community_comment_likes');
    if (!hasLikesTable) {
      return comments;
    }

    final List<CommunityCommentModel> enriched =
        await Future.wait<CommunityCommentModel>(
      comments.map((CommunityCommentModel comment) async {
        final likeCount = await _countRows(
          'community_comment_likes',
          'comment_id',
          comment.id,
        );
        final isLikedByMe = await _isLikedByCurrentUser(
          'community_comment_likes',
          'comment_id',
          comment.id,
        );

        return comment.copyWith(
          likeCount: likeCount,
          likedByMe: isLikedByMe,
        );
      }),
    );

    return enriched;
  }

  Future<String> createPost({
    required String title,
    required String bodyText,
    required String plainText,
    required List<String> imageUrls,
    required String? category,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final profile = await _fetchCurrentUserProfile();
    final authorName =
        (profile?['call_sign'] ?? user.email ?? 'Unknown').toString();
    final authorAvatarUrl = profile?['avatar_url']?.toString();

    final payload = <String, dynamic>{
      'author_id': user.id,
      'user_id': user.id,
      'author_name': authorName,
      'author_avatar_url': authorAvatarUrl ?? '',
      'title': title,
      'language': 'english',
      'is_bulletin': false,
      'is_pinned': false,
      'is_locked': false,
      'is_deleted': false,
      'visibility': 'public',
      'language_code': 'en',
      'category': category ?? 'General',
      'image_url': imageUrls.isNotEmpty ? imageUrls.first : null,
      'image_urls': imageUrls,
      'plain_text': plainText,
      'body_text': bodyText,
      'body_delta_json': null,
      'comment_count': 0,
      'like_count': 0,
      'view_count': 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final response = await _client
        .from('community_posts')
        .insert(payload)
        .select('id')
        .single();

    return response['id'].toString();
  }

  Future<void> incrementPostView(String postId) async {
    final post = await fetchPostById(postId);

    await _client.from('community_posts').update({
      'view_count': post.viewCount + 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', postId);
  }

  Future<void> addComment({
    required String postId,
    required String message,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final profile = await _fetchCurrentUserProfile();
    final authorName =
        (profile?['call_sign'] ?? user.email ?? 'Unknown').toString();
    final authorAvatarUrl = profile?['avatar_url']?.toString();
    final now = DateTime.now().toUtc().toIso8601String();

    final payload = <String, dynamic>{
      'post_id': postId,
      'author_id': user.id,
      'user_id': user.id,
      'author_name': authorName,
      'author_avatar_url': authorAvatarUrl ?? '',
      'message': message,
      'body': message,
      'language': 'english',
      'is_deleted': false,
      'is_locked': false,
      'updated_at': now,
    };

    await _client.from('community_comments').insert(payload);

    final post = await fetchPostById(postId);
    await _client.from('community_posts').update({
      'comment_count': post.commentCount + 1,
      'updated_at': now,
    }).eq('id', postId);
  }

  Future<void> toggleLikePost(String postId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final existing = await _client
        .from('community_post_likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing == null) {
      await _client.from('community_post_likes').insert({
        'post_id': postId,
        'user_id': user.id,
      });
    } else {
      await _client
          .from('community_post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', user.id);
    }

    final likeCount =
        await _countRows('community_post_likes', 'post_id', postId);

    await _client.from('community_posts').update({
      'like_count': likeCount,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', postId);
  }

  Future<void> toggleLikeComment(String commentId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final existing = await _client
        .from('community_comment_likes')
        .select('id')
        .eq('comment_id', commentId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing == null) {
      await _client.from('community_comment_likes').insert({
        'comment_id': commentId,
        'user_id': user.id,
      });
    } else {
      await _client
          .from('community_comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', user.id);
    }
  }

  Future<Map<String, dynamic>?> fetchProfileByUserId(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }
}
