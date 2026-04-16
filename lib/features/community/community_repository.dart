import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_model.dart';

class CommunityRepository {
  CommunityRepository();

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<CommunityModel>> getPosts({
    String languageCode = 'en',
    String category = 'all',
    String search = '',
  }) async {
    final response = await _client
        .from('community_posts')
        .select()
        .order('updated_at', ascending: false);

    var posts =
        response.map<CommunityModel>((e) => CommunityModel.fromJson(e)).toList();

    final enriched = await _attachProfileData(posts);

    if (languageCode != 'all') {
      posts = enriched.where((post) => post.languageCode == languageCode).toList();
    } else {
      posts = enriched;
    }

    if (category != 'all') {
      posts = posts.where((post) => post.category == category).toList();
    }

    final trimmedSearch = search.trim().toLowerCase();
    if (trimmedSearch.isNotEmpty) {
      posts = posts.where((post) {
        return post.title.toLowerCase().contains(trimmedSearch) ||
            post.body.toLowerCase().contains(trimmedSearch) ||
            post.displayName.toLowerCase().contains(trimmedSearch);
      }).toList();
    }

    return posts;
  }

  Future<void> createPost({
    required String title,
    required String body,
    required String languageCode,
    required String category,
    String? imageUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to create a post.');
    }

    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();

    if (trimmedTitle.isEmpty) {
      throw Exception('Title is required.');
    }

    if (trimmedBody.isEmpty) {
      throw Exception('Body is required.');
    }

    await _client.from('community_posts').insert({
      'user_id': user.id,
      'title': trimmedTitle,
      'body': trimmedBody,
      'language_code': languageCode,
      'category': category,
      'image_url': imageUrl,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> bumpUpdatedAt(String postId) async {
    await _client.from('community_posts').update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', postId);
  }

  Future<List<CommunityModel>> _attachProfileData(List<CommunityModel> posts) async {
    if (posts.isEmpty) return posts;

    final userIds = posts.map((e) => e.userId).toSet().toList();

    final profilesResponse = await _client
        .from('profiles')
        .select('id, call_sign, avatar_url')
        .inFilter('id', userIds);

    final profiles = <String, Map<String, dynamic>>{
      for (final row in profilesResponse) row['id'].toString(): row,
    };

    return posts.map((post) {
      final profile = profiles[post.userId];
      return CommunityModel.fromJson({
        ...postToJson(post),
        'call_sign': profile?['call_sign'],
        'avatar_url': profile?['avatar_url'],
      });
    }).toList();
  }

  Map<String, dynamic> postToJson(CommunityModel post) {
    return {
      'id': post.id,
      'user_id': post.userId,
      'title': post.title,
      'body': post.body,
      'created_at': post.createdAt.toIso8601String(),
      'updated_at': post.updatedAt.toIso8601String(),
      'language_code': post.languageCode,
      'category': post.category,
      'call_sign': post.callSign,
      'avatar_url': post.avatarUrl,
      'image_url': post.imageUrl,
    };
  }
}