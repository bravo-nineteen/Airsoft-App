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
        .order('created_at', ascending: false);

    var posts =
        response.map<CommunityModel>((e) => CommunityModel.fromJson(e)).toList();

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
            (post.callSign ?? '').toLowerCase().contains(trimmedSearch);
      }).toList();
    }

    return posts;
  }

  Future<void> createPost({
    required String title,
    required String body,
    required String languageCode,
    required String category,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated.');

    await _client.from('community_posts').insert({
      'user_id': user.id,
      'title': title,
      'body': body,
      'language_code': languageCode,
      'category': category,
    });
  }
}