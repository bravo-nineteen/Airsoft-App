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

    var posts = response
        .map<CommunityModel>((row) => CommunityModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();

    posts = await _attachProfileData(posts);

    if (languageCode != 'all') {
      posts = posts.where((post) => post.languageCode == languageCode).toList();
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
    final safeImageUrl = _sanitizeNullableString(imageUrl);

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
      'language_code': languageCode.trim().isEmpty ? 'en' : languageCode.trim(),
      'category': category.trim().isEmpty ? 'off-topic' : category.trim(),
      'image_url': safeImageUrl,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> bumpUpdatedAt(String postId) async {
    final safePostId = _sanitizeUuid(postId);
    if (safePostId == null) {
      throw Exception('Invalid post id.');
    }

    await _client.from('community_posts').update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', safePostId);
  }

  Future<List<CommunityModel>> _attachProfileData(List<CommunityModel> posts) async {
    if (posts.isEmpty) return posts;

    final userIds = posts
        .map((post) => _sanitizeUuid(post.userId))
        .whereType<String>()
        .toSet()
        .toList();

    if (userIds.isEmpty) {
      return posts;
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

    return posts.map((post) {
      final profile = profiles[post.userId];
      if (profile == null) {
        return post;
      }

      return CommunityModel.fromJson({
        ...postToJson(post),
        'call_sign': profile['call_sign'],
        'avatar_url': profile['avatar_url'],
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

  String? _sanitizeNullableString(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase() == 'null') return null;
    return trimmed;
  }

  String? _sanitizeUuid(String? value) {
    final trimmed = _sanitizeNullableString(value);
    if (trimmed == null) return null;
    if (!_isValidUuid(trimmed)) return null;
    return trimmed;
  }

  bool _isValidUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}
