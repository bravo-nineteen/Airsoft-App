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
        .map((e) => CommunityPostModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      posts = posts.where((post) {
        return post.title.toLowerCase().contains(normalizedQuery) ||
            post.plainText.toLowerCase().contains(normalizedQuery) ||
            (post.category ?? '').toLowerCase().contains(normalizedQuery) ||
            post.authorName.toLowerCase().contains(normalizedQuery);
      }).toList();
    }

    if (category != 'All') {
      posts = posts.where((post) => (post.category ?? 'General') == category).toList();
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

  Future<String> createPost({
    required String authorId,
    required String authorName,
    required String? authorAvatarUrl,
    required String title,
    required String plainText,
    required String bodyDeltaJson,
    required List<String> imageUrls,
    required String? category,
  }) async {
    final response = await _client
        .from('community_posts')
        .insert(<String, dynamic>{
          'author_id': authorId,
          'author_name': authorName,
          'author_avatar_url': authorAvatarUrl,
          'title': title,
          'plain_text': plainText,
          'body_delta_json': bodyDeltaJson,
          'image_urls': imageUrls,
          'category': category,
          'comment_count': 0,
          'like_count': 0,
          'view_count': 0,
          'is_pinned': false,
        })
        .select('id')
        .single();

    return response['id'].toString();
  }

  Future<void> incrementPostView(String postId) async {
    final post = await fetchPostById(postId);
    await _client.from('community_posts').update(<String, dynamic>{
      'view_count': post.viewCount + 1,
    }).eq('id', postId);
  }

  Future<List<CommunityCommentModel>> fetchComments(String postId) async {
    final response = await _client
        .from('community_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return (response as List<dynamic>)
        .map((e) => CommunityCommentModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String? authorAvatarUrl,
    required String message,
  }) async {
    await _client.from('community_comments').insert(<String, dynamic>{
      'post_id': postId,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar_url': authorAvatarUrl,
      'message': message,
    });

    final post = await fetchPostById(postId);
    await _client.from('community_posts').update(<String, dynamic>{
      'comment_count': post.commentCount + 1,
    }).eq('id', postId);
  }

  Future<void> bumpUpdatedAt(String postId) async {
    await _client.from('community_posts').update(<String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', postId);
  }
}