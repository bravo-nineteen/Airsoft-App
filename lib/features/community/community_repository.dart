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
    String preferredLanguage = 'english',
  }) async {
    final response = await _client
        .from('community_posts')
        .select()
        .eq('is_deleted', false)
        .eq('post_context', 'community')
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

    final String normalizedLanguage = _normalizePostLanguage(preferredLanguage);
    if (normalizedLanguage != 'all') {
      posts = posts.where((CommunityPostModel post) {
        final String postLanguage = _normalizePostLanguage(post.language);
        if (normalizedLanguage == 'bilingual') {
          return true;
        }
        return postLanguage == normalizedLanguage || postLanguage == 'bilingual';
      }).toList();
    }

    return posts;
  }

  Future<List<CommunityPostModel>> fetchPostsByAuthor(
    String userId, {
    int? limit,
  }) async {
    dynamic query = _client
        .from('community_posts')
        .select()
        .eq('is_deleted', false)
        .eq('post_context', 'community')
        .or('author_id.eq.$userId,user_id.eq.$userId')
        .order('created_at', ascending: false);

    if (limit != null) {
      query = query.limit(limit);
    }

    final response = await query;

    return (response as List<dynamic>)
        .map(
          (dynamic e) => CommunityPostModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<CommunityPostModel>> fetchProfileTimelinePosts(
    String userId, {
    int? limit,
  }) async {
    dynamic query = _client
        .from('community_posts')
        .select()
        .eq('is_deleted', false)
        .eq('post_context', 'profile')
        .eq('target_user_id', userId)
        .order('created_at', ascending: false);

    if (limit != null) {
      query = query.limit(limit);
    }

    final response = await query;

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
    String language = 'english',
    String postContext = 'community',
    String? targetUserId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    if (postContext == 'profile' &&
        (targetUserId == null || targetUserId.trim().isEmpty)) {
      throw Exception('Profile target is required');
    }

    final profile = await _fetchCurrentUserProfile();
    final authorName =
        (profile?['call_sign'] ?? user.email ?? 'Unknown').toString();
    final authorAvatarUrl = profile?['avatar_url']?.toString();
    final String normalizedLanguage = _normalizePostLanguage(language);

    final payload = <String, dynamic>{
      'author_id': user.id,
      'user_id': user.id,
      'author_name': authorName,
      'author_avatar_url': authorAvatarUrl ?? '',
      'title': title,
      'language': normalizedLanguage,
      'is_bulletin': false,
      'is_pinned': false,
      'is_locked': false,
      'is_deleted': false,
      'visibility': 'public',
      'language_code': _languageCodeFor(normalizedLanguage),
      'category': category ?? (postContext == 'profile' ? 'Timeline' : 'General'),
      'image_url': imageUrls.isNotEmpty ? imageUrls.first : null,
      'image_urls': imageUrls,
      'plain_text': plainText,
      'body_text': bodyText,
      'body_delta_json': null,
      'comment_count': 0,
      'like_count': 0,
      'view_count': 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'post_context': postContext,
      'target_user_id': targetUserId,
    };

    final response = await _client
        .from('community_posts')
        .insert(payload)
        .select('id')
        .single();

    return response['id'].toString();
  }

  Future<String> createProfileTimelinePost({
    required String targetUserId,
    required String title,
    required String bodyText,
    required String plainText,
    required List<String> imageUrls,
    String language = 'english',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    if (user.id != targetUserId) {
      throw Exception('Only the profile owner can post to this timeline');
    }

    return createPost(
      title: title,
      bodyText: bodyText,
      plainText: plainText,
      imageUrls: imageUrls,
      language: language,
      category: 'Timeline',
      postContext: 'profile',
      targetUserId: targetUserId,
    );
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

  Future<List<CommunityCommentModel>> fetchCommentsByAuthor(
    String userId, {
    int? limit,
  }) async {
    dynamic query = _client
        .from('community_comments')
        .select(
          'id, created_at, post_id, author_id, user_id, author_name, author_avatar_url, message, body, like_count',
        )
        .eq('is_deleted', false)
        .or('author_id.eq.$userId,user_id.eq.$userId')
        .order('created_at', ascending: false);

    if (limit != null) {
      query = query.limit(limit);
    }

    final response = await query;

    return (response as List<dynamic>)
        .map(
          (dynamic e) => CommunityCommentModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<int> fetchUserReceivedLikesCount(String userId) async {
    final bool hasPostLikesTable = await _hasTable('community_post_likes');
    final bool hasCommentLikesTable =
        await _hasTable('community_comment_likes');

    if (!hasPostLikesTable && !hasCommentLikesTable) {
      return 0;
    }

    final List<String> postIds = await _fetchAuthorPostIds(userId);
    final List<String> commentIds = await _fetchAuthorCommentIds(userId);

    int postLikes = 0;
    int commentLikes = 0;

    if (hasPostLikesTable && postIds.isNotEmpty) {
      final postLikesResponse = await _client
          .from('community_post_likes')
          .select('id')
          .inFilter('post_id', postIds);
      postLikes = (postLikesResponse as List).length;
    }

    if (hasCommentLikesTable && commentIds.isNotEmpty) {
      final commentLikesResponse = await _client
          .from('community_comment_likes')
          .select('id')
          .inFilter('comment_id', commentIds);
      commentLikes = (commentLikesResponse as List).length;
    }

    return postLikes + commentLikes;
  }

  Future<List<String>> _fetchAuthorPostIds(String userId) async {
    final response = await _client
        .from('community_posts')
        .select('id')
        .eq('is_deleted', false)
        .or('author_id.eq.$userId,user_id.eq.$userId');

    return (response as List<dynamic>)
        .map((dynamic e) => e['id'].toString())
        .toList();
  }

  Future<List<String>> _fetchAuthorCommentIds(String userId) async {
    final response = await _client
        .from('community_comments')
        .select('id')
        .eq('is_deleted', false)
        .or('author_id.eq.$userId,user_id.eq.$userId');

    return (response as List<dynamic>)
        .map((dynamic e) => e['id'].toString())
        .toList();
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

  Future<Map<String, dynamic>> fetchFriendshipState(String otherUserId) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return <String, dynamic>{
        'isSelf': false,
        'isLoggedIn': false,
        'areFriends': false,
        'outgoingPending': false,
        'incomingPending': false,
        'canMessage': false,
      };
    }

    if (user.id == otherUserId) {
      return <String, dynamic>{
        'isSelf': true,
        'isLoggedIn': true,
        'areFriends': false,
        'outgoingPending': false,
        'incomingPending': false,
        'canMessage': false,
      };
    }

    final hasContactsTable = await _hasTable('user_contacts');
    final hasFriendshipsTable = await _hasTable('friendships');
    final hasRequestsTable = await _hasTable('friend_requests');

    bool areFriends = false;
    bool outgoingPending = false;
    bool incomingPending = false;

    if (hasContactsTable) {
      try {
        final accepted = await _client
            .from('user_contacts')
            .select('id')
            .or(
              'and(requester_id.eq.${user.id},addressee_id.eq.$otherUserId),and(requester_id.eq.$otherUserId,addressee_id.eq.${user.id})',
            )
            .eq('status', 'accepted')
            .maybeSingle();

        areFriends = accepted != null;
      } catch (_) {}
    }

    if (!areFriends && hasFriendshipsTable) {
      try {
        final friendship = await _client
            .from('friendships')
            .select('id')
            .or(
              'and(user_id.eq.${user.id},friend_id.eq.$otherUserId),and(user_id.eq.$otherUserId,friend_id.eq.${user.id})',
            )
            .maybeSingle();

        areFriends = friendship != null;
      } catch (_) {}
    }

    if (!areFriends && hasContactsTable) {
      try {
        final outgoing = await _client
            .from('user_contacts')
            .select('id')
            .eq('requester_id', user.id)
            .eq('addressee_id', otherUserId)
            .eq('status', 'pending')
            .maybeSingle();

        outgoingPending = outgoing != null;
      } catch (_) {}

      try {
        final incoming = await _client
            .from('user_contacts')
            .select('id')
            .eq('requester_id', otherUserId)
            .eq('addressee_id', user.id)
            .eq('status', 'pending')
            .maybeSingle();

        incomingPending = incoming != null;
      } catch (_) {}
    }

    if (!areFriends && !outgoingPending && !incomingPending && hasRequestsTable) {
      try {
        final outgoing = await _client
            .from('friend_requests')
            .select('id, status')
            .eq('sender_id', user.id)
            .eq('receiver_id', otherUserId)
            .eq('status', 'pending')
            .maybeSingle();

        outgoingPending = outgoing != null;
      } catch (_) {}

      try {
        final incoming = await _client
            .from('friend_requests')
            .select('id, status')
            .eq('sender_id', otherUserId)
            .eq('receiver_id', user.id)
            .eq('status', 'pending')
            .maybeSingle();

        incomingPending = incoming != null;
      } catch (_) {}
    }

    return <String, dynamic>{
      'isSelf': false,
      'isLoggedIn': true,
      'areFriends': areFriends,
      'outgoingPending': outgoingPending,
      'incomingPending': incomingPending,
      'canMessage': areFriends,
    };
  }

  String _normalizePostLanguage(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'ja':
      case 'jp':
      case 'japanese':
        return 'japanese';
      case 'bi':
      case 'both':
      case 'bilingual':
      case 'english / japanese':
      case 'japanese / english':
        return 'bilingual';
      case 'all':
        return 'all';
      case 'en':
      case 'english':
      default:
        return 'english';
    }
  }

  String _languageCodeFor(String language) {
    switch (language) {
      case 'japanese':
        return 'ja';
      case 'bilingual':
        return 'bi';
      case 'english':
      default:
        return 'en';
    }
  }

  Future<void> sendFriendRequest(String otherUserId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    if (user.id == otherUserId) {
      throw Exception('You cannot add yourself');
    }

    final hasContactsTable = await _hasTable('user_contacts');
    final hasRequestsTable = await _hasTable('friend_requests');

    if (!hasContactsTable && !hasRequestsTable) {
      throw Exception('No request table is available');
    }

    final state = await fetchFriendshipState(otherUserId);
    if (state['areFriends'] == true) {
      return;
    }
    if (state['outgoingPending'] == true) {
      return;
    }

    if (hasContactsTable) {
      await _client.from('user_contacts').insert({
        'requester_id': user.id,
        'addressee_id': otherUserId,
        'status': 'pending',
      });
      return;
    }

    await _client.from('friend_requests').insert({
      'sender_id': user.id,
      'receiver_id': otherUserId,
      'status': 'pending',
    });
  }
}
