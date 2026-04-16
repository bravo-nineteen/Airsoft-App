import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_model.dart';

class CommunityRepository {
  CommunityRepository({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<CommunityPostModel>> fetchPosts({
    String query = '',
    String category = 'All',
  }) async {
    final response = await _client
        .from('community_posts')
        .select()
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);

    var posts = (response as List<dynamic>)
        .map(
          (e) => CommunityPostModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      posts = posts.where((post) {
        return post.title.toLowerCase().contains(normalizedQuery) ||
            post.plainText.toLowerCase().contains(normalizedQuery) ||
            post.bodyText.toLowerCase().contains(normalizedQuery) ||
            (post.category ?? '').toLowerCase().contains(normalizedQuery) ||
            post.authorName.toLowerCase().contains(normalizedQuery);
      }).toList();
    }

    if (category != 'All') {
      posts = posts
          .where((post) => (post.category ?? 'General') == category)
          .toList();
    }

    return posts;
  }

  Future<CommunityPostModel> fetchPostById(String postId) async {
    final response = await _client
        .from('community_posts')
        .select()
        .eq('id', postId)
        .single();

    return CommunityPostModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<Map<String, dynamic>?> _fetchCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('profiles')
        .select('id, call_sign, avatar_url')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;

    return Map<String, dynamic>.from(response);
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

  Future<List<CommunityCommentModel>> fetchComments(String postId) async {
    final response = await _client
        .from('community_comments')
        .select(
          'id, created_at, post_id, author_id, author_name, author_avatar_url, message, body',
        )
        .eq('post_id', postId)
        .eq('is_deleted', false)
        .order('created_at', ascending: true);

    return (response as List<dynamic>)
        .map(
          (e) => CommunityCommentModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
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
    throw UnimplementedError('Post likes are not wired yet.');
  }
}