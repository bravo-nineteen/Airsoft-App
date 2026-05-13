import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/time/japan_time.dart';
import 'community_model.dart';
import 'community_image_service.dart';
import 'community_reaction_types.dart';
import '../notifications/notification_writer.dart';
import '../safety/safety_repository.dart';

class CommunityRepository {
  CommunityRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client,
      _notificationWriter = NotificationWriter(client: client),
      _imageService = CommunityImageService(client: client),
      _safetyRepository = SafetyRepository(client: client);

  final SupabaseClient _client;
  final NotificationWriter _notificationWriter;
  final CommunityImageService _imageService;
  final SafetyRepository _safetyRepository;

  String? get currentUserId => _client.auth.currentUser?.id;

  bool _isTransient(Object error) {
    final String text = error.toString().toLowerCase();
    if (error is SocketException) {
      return true;
    }
    return text.contains('502') ||
        text.contains('503') ||
        text.contains('gateway') ||
        text.contains('socketexception') ||
        text.contains('timeout') ||
        text.contains('failed host lookup') ||
        text.contains('no address associated with hostname') ||
        text.contains('network is unreachable') ||
        text.contains('clientexception');
  }

  Future<T> _withTransientRetry<T>(Future<T> Function() action) async {
    const List<Duration> retryDelays = <Duration>[
      Duration(milliseconds: 500),
      Duration(milliseconds: 1500),
      Duration(milliseconds: 3000),
    ];
    Object? lastError;
    for (int attempt = 0; attempt < retryDelays.length + 1; attempt++) {
      try {
        return await action();
      } catch (error) {
        lastError = error;
        if (!_isTransient(error) || attempt == retryDelays.length) {
          rethrow;
        }
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }
    throw lastError ?? Exception('Unknown community error');
  }

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

  Future<bool> _hasColumn(String tableName, String columnName) async {
    try {
      await _client.from(tableName).select(columnName).limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _normalizeReactionOrDefault(String? value) {
    return CommunityReactionTypes.normalizeNullable(value) ??
        CommunityReactionTypes.thumbsUp;
  }

  bool _isMissingTableError(PostgrestException error, String tableName) {
    if (error.code != '42P01' && error.code != 'PGRST205') {
      return false;
    }

    final String summary =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return summary.contains(tableName.toLowerCase());
  }

  Future<Map<String, dynamic>?> getPostDraft({
    required String draftKey,
    String postContext = 'community',
    String? targetUserId,
  }) async {
    final String? userId = currentUserId;
    if (userId == null) {
      return null;
    }

    try {
      final Map<String, dynamic>? response = await _client
          .from('post_drafts')
          .select()
          .eq('user_id', userId)
          .eq('draft_key', draftKey)
          .maybeSingle();

      if (response == null) {
        return null;
      }
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'post_drafts')) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> savePostDraft({
    required String draftKey,
    required String title,
    required String bodyText,
    required String plainText,
    required List<String> imageUrls,
    required String language,
    required String category,
    String postContext = 'community',
    String? targetUserId,
    String? pollQuestion,
    List<String>? pollOptions,
    bool pollAllowMultiple = false,
  }) async {
    final String? userId = currentUserId;
    if (userId == null) {
      return;
    }

    try {
      await _client.from('post_drafts').upsert(<String, dynamic>{
        'user_id': userId,
        'draft_key': draftKey,
        'post_context': postContext,
        'target_user_id': _nullIfEmpty(targetUserId),
        'title': title,
        'body_text': bodyText,
        'plain_text': plainText,
        'media_json': imageUrls,
        'poll_json': <String, dynamic>{
          'language': language,
          'category': category,
          'question': _nullIfEmpty(pollQuestion),
          'options': (pollOptions ?? <String>[])
              .map((String value) => value.trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
          'allow_multiple': pollAllowMultiple,
        },
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,draft_key');
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'post_drafts')) {
        return;
      }
      rethrow;
    }
  }

  Future<void> clearPostDraft({required String draftKey}) async {
    final String? userId = currentUserId;
    if (userId == null) {
      return;
    }

    try {
      await _client
          .from('post_drafts')
          .delete()
          .eq('user_id', userId)
          .eq('draft_key', draftKey);
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'post_drafts')) {
        return;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCommentDraft({
    required String threadType,
    required String threadId,
  }) async {
    final String? userId = currentUserId;
    if (userId == null) {
      return null;
    }

    try {
      final List<dynamic> response = await _client
          .from('comment_drafts')
          .select()
          .eq('user_id', userId)
          .eq('thread_type', threadType)
          .eq('thread_id', threadId)
          .order('updated_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return null;
      }
      return Map<String, dynamic>.from(response.first as Map);
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'comment_drafts')) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> saveCommentDraft({
    required String threadType,
    required String threadId,
    required String bodyText,
    String? parentCommentId,
  }) async {
    final String? userId = currentUserId;
    if (userId == null) {
      return;
    }

    try {
      final String? normalizedParent = _nullIfEmpty(parentCommentId);
      if (normalizedParent == null) {
        await _client
            .from('comment_drafts')
            .delete()
            .eq('user_id', userId)
            .eq('thread_type', threadType)
            .eq('thread_id', threadId)
            .not('parent_comment_id', 'is', null);
      }

      await _client.from('comment_drafts').upsert(<String, dynamic>{
        'user_id': userId,
        'thread_type': threadType,
        'thread_id': threadId,
        'parent_comment_id': normalizedParent,
        'body_text': bodyText,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'comment_drafts')) {
        return;
      }
      rethrow;
    }
  }

  Future<void> clearCommentDraft({
    required String threadType,
    required String threadId,
  }) async {
    final String? userId = currentUserId;
    if (userId == null) {
      return;
    }

    try {
      await _client
          .from('comment_drafts')
          .delete()
          .eq('user_id', userId)
          .eq('thread_type', threadType)
          .eq('thread_id', threadId);
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'comment_drafts')) {
        return;
      }
      rethrow;
    }
  }

  Future<int> _countRows(
    String tableName,
    String foreignKey,
    String foreignId,
  ) async {
    try {
      final response = await _client
          .from(tableName)
          .select('id')
          .eq(foreignKey, foreignId);
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

  Future<String?> _reactionForCurrentUser(
    String tableName,
    String foreignKey,
    String foreignId,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    final bool hasReactionColumn = await _hasColumn(tableName, 'reaction');
    try {
      final String selectColumns = hasReactionColumn ? 'id,reaction' : 'id';
      final Map<String, dynamic>? response = await _client
          .from(tableName)
          .select(selectColumns)
          .eq(foreignKey, foreignId)
          .eq('user_id', user.id)
          .maybeSingle();
      if (response == null) {
        return null;
      }
      if (!hasReactionColumn) {
        return CommunityReactionTypes.thumbsUp;
      }
      return _normalizeReactionOrDefault(response['reaction']?.toString());
    } catch (_) {
      return null;
    }
  }

  Future<List<CommunityPostModel>> fetchPosts({
    String query = '',
    String category = 'All',
    String preferredLanguage = 'english',
  }) async {
    final CommunityPostsPage page = await fetchPostsPage(
      query: query,
      category: category,
      preferredLanguage: preferredLanguage,
      offset: 0,
      limit: 200,
    );
    return page.items;
  }

  Future<CommunityPostsPage> fetchPostsPage({
    String query = '',
    String category = 'All',
    String preferredLanguage = 'english',
    required int offset,
    int limit = 20,
  }) async {
    dynamic request = _client
        .from('community_posts')
        .select()
        .eq('is_deleted', false)
        .eq('post_context', 'community');

    final String trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty) {
      final String escaped = trimmedQuery
          .replaceAll(',', ' ')
          .replaceAll('%', '');
      request = request.or(
        'title.ilike.%$escaped%,plain_text.ilike.%$escaped%,body_text.ilike.%$escaped%,author_name.ilike.%$escaped%,category.ilike.%$escaped%',
      );
    }

    if (category != 'All') {
      request = request.eq('category', category);
    }

    final String normalizedLanguage = _normalizePostLanguage(preferredLanguage);
    if (normalizedLanguage == 'english') {
      request = request.eq('language', 'english');
    } else if (normalizedLanguage == 'japanese') {
      request = request.eq('language', 'japanese');
    }

    final dynamic response = await _withTransientRetry(
      () => request
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + limit - 1),
    );

    List<CommunityPostModel> posts = (response as List<dynamic>)
        .map(
          (dynamic e) =>
              CommunityPostModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    final String? viewerUserId = currentUserId;
    if (viewerUserId != null) {
      final Set<String> hiddenUserIds = await _safetyRepository
          .getHiddenAuthorIds();
      posts = posts.where((CommunityPostModel post) {
        return !hiddenUserIds.contains(post.authorId ?? '');
      }).toList();
    }

    if (posts.isNotEmpty) {
      final List<String> postIds = posts
          .map((CommunityPostModel p) => p.id)
          .toList();
      final dynamic commentsResponse = await _withTransientRetry(
        () => _client
            .from('community_comments')
            .select('id, post_id')
            .inFilter('post_id', postIds)
            .eq('is_deleted', false),
      );

      final Map<String, int> commentCountByPostId = <String, int>{};
      for (final dynamic row in (commentsResponse as List<dynamic>)) {
        final String postId = row['post_id']?.toString() ?? '';
        if (postId.isEmpty) {
          continue;
        }
        commentCountByPostId[postId] = (commentCountByPostId[postId] ?? 0) + 1;
      }

      for (int i = 0; i < posts.length; i++) {
        final CommunityPostModel current = posts[i];
        posts[i] = current.copyWith(
          commentCount: commentCountByPostId[current.id] ?? 0,
        );
      }

      final bool hasPostLikesTable = await _hasTable('community_post_likes');
      if (hasPostLikesTable) {
        final bool hasReactionColumn = await _hasColumn(
          'community_post_likes',
          'reaction',
        );

        final String selectColumns = hasReactionColumn
            ? 'post_id,user_id,reaction'
            : 'post_id,user_id';
        final List<dynamic> rows = await _client
            .from('community_post_likes')
            .select(selectColumns)
            .inFilter('post_id', postIds);

        final Map<String, int> countByPostId = <String, int>{};
        final Map<String, String> myReactionByPostId = <String, String>{};
        final String? viewerId = currentUserId;

        for (final dynamic row in rows) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(row as Map);
          final String postId = map['post_id']?.toString() ?? '';
          if (postId.isEmpty) {
            continue;
          }
          countByPostId[postId] = (countByPostId[postId] ?? 0) + 1;

          if (viewerId != null && map['user_id']?.toString() == viewerId) {
            final String reaction = hasReactionColumn
                ? _normalizeReactionOrDefault(map['reaction']?.toString())
                : CommunityReactionTypes.thumbsUp;
            myReactionByPostId[postId] = reaction;
          }
        }

        for (int i = 0; i < posts.length; i++) {
          final CommunityPostModel current = posts[i];
          final String? myReaction = myReactionByPostId[current.id];
          posts[i] = current.copyWith(
            likeCount: countByPostId[current.id] ?? 0,
            isLikedByMe: myReaction != null,
            myReaction: myReaction,
          );
        }
      }
    }

    return CommunityPostsPage(
      items: posts,
      nextOffset: offset + posts.length,
      hasMore: posts.length >= limit,
    );
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
          (dynamic e) =>
              CommunityPostModel.fromJson(Map<String, dynamic>.from(e as Map)),
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
          (dynamic e) =>
              CommunityPostModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<CommunityPostModel>> fetchMergedTimelinePosts(
    String userId, {
    int? limit,
  }) async {
    dynamic query = _client
        .from('community_posts')
        .select()
        .eq('is_deleted', false)
        .or(
          'and(post_context.eq.profile,target_user_id.eq.$userId),and(post_context.eq.community,author_id.eq.$userId)',
        )
        .order('created_at', ascending: false);

    if (limit != null) {
      query = query.limit(limit);
    }

    final response = await query;

    return (response as List<dynamic>)
        .map(
          (dynamic e) =>
              CommunityPostModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<CommunityPostModel>> fetchFriendsTimelinePosts({
    int limit = 6,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      return <CommunityPostModel>[];
    }

    final List<dynamic> contacts = await _client
        .from('user_contacts')
        .select('requester_id, addressee_id')
        .or('requester_id.eq.${user.id},addressee_id.eq.${user.id}')
        .eq('status', 'accepted');

    final Set<String> friendIds = <String>{};
    for (final dynamic row in contacts) {
      final String requesterId = row['requester_id'].toString();
      final String addresseeId = row['addressee_id'].toString();
      if (requesterId == user.id) {
        friendIds.add(addresseeId);
      } else {
        friendIds.add(requesterId);
      }
    }

    friendIds.add(user.id);

    if (friendIds.isEmpty) {
      return <CommunityPostModel>[];
    }

    final dynamic response = await _client
        .from('community_posts')
        .select()
        .eq('is_deleted', false)
        .eq('post_context', 'profile')
        .inFilter('target_user_id', friendIds.toList())
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map(
          (dynamic e) =>
              CommunityPostModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<CommunityPostModel> fetchPostById(String postId) async {
    final response = await _withTransientRetry(
      () => _client
          .from('community_posts')
          .select()
          .eq('id', postId)
          .maybeSingle(),
    );

    if (response == null) {
      throw Exception('Post no longer exists.');
    }

    var post = CommunityPostModel.fromJson(Map<String, dynamic>.from(response));

    final hasLikesTable = await _hasTable('community_post_likes');
    if (hasLikesTable) {
      final int likeCount = await _countRows(
        'community_post_likes',
        'post_id',
        postId,
      );
      final String? myReaction = await _reactionForCurrentUser(
        'community_post_likes',
        'post_id',
        postId,
      );

      post = post.copyWith(
        likeCount: likeCount,
        isLikedByMe: myReaction != null,
        myReaction: myReaction,
      );
    }

    return post;
  }

  Future<List<CommunityCommentModel>> fetchComments(String postId) async {
    final response = await _withTransientRetry(
      () => _client
          .from('community_comments')
          .select(
            'id, created_at, post_id, author_id, user_id, author_name, author_avatar_url, message, body, image_url, like_count, parent_comment_id',
          )
          .eq('post_id', postId)
          .eq('is_deleted', false)
          .order('created_at', ascending: true),
    );

    List<CommunityCommentModel> comments = (response as List<dynamic>)
        .map(
          (dynamic e) => CommunityCommentModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    final String? viewerUserId = currentUserId;
    if (viewerUserId != null) {
      final Set<String> hiddenUserIds = await _safetyRepository
          .getHiddenAuthorIds();
      comments = comments.where((CommunityCommentModel comment) {
        return !hiddenUserIds.contains(comment.authorId ?? '');
      }).toList();
    }

    final bool hasLikesTable = await _hasTable('community_comment_likes');
    if (!hasLikesTable) {
      return comments;
    }

    final List<String> commentIds = comments
        .map((CommunityCommentModel comment) => comment.id)
        .toList();
    if (commentIds.isEmpty) {
      return comments;
    }

    final bool hasReactionColumn = await _hasColumn(
      'community_comment_likes',
      'reaction',
    );
    final String selectColumns = hasReactionColumn
        ? 'comment_id,user_id,reaction'
        : 'comment_id,user_id';
    final List<dynamic> rows = await _client
        .from('community_comment_likes')
        .select(selectColumns)
        .inFilter('comment_id', commentIds);

    final Map<String, int> countByCommentId = <String, int>{};
    final Map<String, String> myReactionByCommentId = <String, String>{};
    final String? viewerId = currentUserId;

    for (final dynamic row in rows) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(row as Map);
      final String commentId = map['comment_id']?.toString() ?? '';
      if (commentId.isEmpty) {
        continue;
      }
      countByCommentId[commentId] = (countByCommentId[commentId] ?? 0) + 1;

      if (viewerId != null && map['user_id']?.toString() == viewerId) {
        final String reaction = hasReactionColumn
            ? _normalizeReactionOrDefault(map['reaction']?.toString())
            : CommunityReactionTypes.thumbsUp;
        myReactionByCommentId[commentId] = reaction;
      }
    }

    final List<CommunityCommentModel> enriched = comments
        .map((CommunityCommentModel comment) {
          final String? myReaction = myReactionByCommentId[comment.id];
          return comment.copyWith(
            likeCount: countByCommentId[comment.id] ?? 0,
            likedByMe: myReaction != null,
            myReaction: myReaction,
          );
        })
        .toList();

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
    String? pollQuestion,
    List<String>? pollOptions,
    bool pollAllowMultiple = false,
    DateTime? pollExpiresAt,
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
    final authorName = (profile?['call_sign'] ?? user.email ?? 'Unknown')
        .toString();
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
      'category':
          category ?? (postContext == 'profile' ? 'Timeline' : 'General'),
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

    final String postId = response['id'].toString();
    await _createPollForPost(
      postId: postId,
      question: pollQuestion,
      options: pollOptions,
      allowMultiple: pollAllowMultiple,
      expiresAt: pollExpiresAt,
    );

    return postId;
  }

  Future<String> createProfileTimelinePost({
    required String targetUserId,
    required String title,
    required String bodyText,
    required String plainText,
    required List<String> imageUrls,
    String language = 'english',
    String? pollQuestion,
    List<String>? pollOptions,
    bool pollAllowMultiple = false,
    DateTime? pollExpiresAt,
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
      pollQuestion: pollQuestion,
      pollOptions: pollOptions,
      pollAllowMultiple: pollAllowMultiple,
      pollExpiresAt: pollExpiresAt,
    );
  }

  Future<void> _createPollForPost({
    required String postId,
    required String? question,
    required List<String>? options,
    required bool allowMultiple,
    required DateTime? expiresAt,
  }) async {
    final String trimmedQuestion = (question ?? '').trim();
    final List<String> trimmedOptions = (options ?? <String>[])
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList();

    if (trimmedQuestion.isEmpty || trimmedOptions.length < 2) {
      return;
    }

    try {
      final bool hasPollTable = await _hasTable('post_polls');
      final bool hasPollOptionsTable = await _hasTable('post_poll_options');
      if (!hasPollTable || !hasPollOptionsTable) {
        return;
      }

      final Map<String, dynamic> pollRow = await _client
          .from('post_polls')
          .insert(<String, dynamic>{
            'post_id': postId,
            'question': trimmedQuestion,
            'allow_multiple': allowMultiple,
            'expires_at': expiresAt?.toUtc().toIso8601String(),
          })
          .select('id')
          .single();

      final String pollId = pollRow['id'].toString();
      final List<Map<String, dynamic>> optionRows = <Map<String, dynamic>>[];
      for (int i = 0; i < trimmedOptions.length; i++) {
        optionRows.add(<String, dynamic>{
          'poll_id': pollId,
          'option_text': trimmedOptions[i],
          'sort_order': i,
        });
      }
      await _client.from('post_poll_options').insert(optionRows);
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'post_polls') ||
          _isMissingTableError(error, 'post_poll_options')) {
        return;
      }
      rethrow;
    }
  }

  Future<CommunityPostPoll?> fetchPostPoll(String postId) async {
    try {
      final bool hasPollTable = await _hasTable('post_polls');
      final bool hasPollOptionsTable = await _hasTable('post_poll_options');
      final bool hasPollVotesTable = await _hasTable('post_poll_votes');
      if (!hasPollTable || !hasPollOptionsTable || !hasPollVotesTable) {
        return null;
      }

      final Map<String, dynamic>? pollRow = await _client
          .from('post_polls')
          .select('id, post_id, question, allow_multiple, expires_at')
          .eq('post_id', postId)
          .maybeSingle();
      if (pollRow == null) {
        return null;
      }

      final String pollId = pollRow['id'].toString();
      final List<dynamic> optionsResponse = await _client
          .from('post_poll_options')
          .select('id, poll_id, option_text, sort_order')
          .eq('poll_id', pollId)
          .order('sort_order', ascending: true);

      final List<dynamic> votesResponse = await _client
          .from('post_poll_votes')
          .select('option_id, user_id')
          .eq('poll_id', pollId);

      final Map<String, int> voteCountByOptionId = <String, int>{};
      final Set<String> selectedOptionIds = <String>{};
      final String? viewerId = currentUserId;

      for (final dynamic row in votesResponse) {
        final String optionId = row['option_id']?.toString() ?? '';
        if (optionId.isEmpty) {
          continue;
        }
        voteCountByOptionId[optionId] =
            (voteCountByOptionId[optionId] ?? 0) + 1;
        if (viewerId != null && row['user_id']?.toString() == viewerId) {
          selectedOptionIds.add(optionId);
        }
      }

      final List<CommunityPostPollOption> options = optionsResponse
          .map<CommunityPostPollOption>((dynamic row) {
            final String optionId = row['id']?.toString() ?? '';
            return CommunityPostPollOption(
              id: optionId,
              pollId: row['poll_id']?.toString() ?? pollId,
              optionText: row['option_text']?.toString() ?? '',
              sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
              voteCount: voteCountByOptionId[optionId] ?? 0,
            );
          })
          .toList();

      final int totalVotes = voteCountByOptionId.values.fold<int>(
        0,
        (int sum, int value) => sum + value,
      );

      return CommunityPostPoll(
        id: pollId,
        postId: pollRow['post_id']?.toString() ?? postId,
        question: pollRow['question']?.toString() ?? '',
        allowMultiple: pollRow['allow_multiple'] == true,
        options: options,
        selectedOptionIds: selectedOptionIds,
        totalVotes: totalVotes,
        expiresAt: JapanTime.parseServerTimestamp(pollRow['expires_at']),
      );
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'post_polls') ||
          _isMissingTableError(error, 'post_poll_options') ||
          _isMissingTableError(error, 'post_poll_votes')) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> voteOnPostPoll({
    required CommunityPostPoll poll,
    required Set<String> optionIds,
  }) async {
    final String? userId = currentUserId;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    if (!poll.allowMultiple && optionIds.length > 1) {
      throw Exception('Only one option is allowed for this poll.');
    }

    final Set<String> normalizedOptionIds = optionIds
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet();

    try {
      await _client
          .from('post_poll_votes')
          .delete()
          .eq('poll_id', poll.id)
          .eq('user_id', userId);

      if (normalizedOptionIds.isEmpty) {
        return;
      }

      final List<Map<String, dynamic>> rows = normalizedOptionIds
          .map(
            (String optionId) => <String, dynamic>{
              'poll_id': poll.id,
              'option_id': optionId,
              'user_id': userId,
            },
          )
          .toList();

      await _client.from('post_poll_votes').insert(rows);
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'post_poll_votes')) {
        return;
      }
      rethrow;
    }
  }

  Future<void> incrementPostView(String postId) async {
    final post = await fetchPostById(postId);

    await _client
        .from('community_posts')
        .update({
          'view_count': post.viewCount + 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', postId);
  }

  Future<void> addComment({
    required String postId,
    required String message,
    String? parentCommentId,
    String? imageUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final profile = await _fetchCurrentUserProfile();
    final authorName = (profile?['call_sign'] ?? user.email ?? 'Unknown')
        .toString();
    final authorAvatarUrl = profile?['avatar_url']?.toString();
    final now = DateTime.now().toUtc().toIso8601String();
    final Map<String, dynamic>? postRecord = await _client
        .from('community_posts')
        .select('id, title, author_id, user_id, comment_count')
        .eq('id', postId)
        .maybeSingle();
    final Map<String, dynamic>? parentCommentRecord =
        parentCommentId == null || parentCommentId.trim().isEmpty
        ? null
        : await _client
              .from('community_comments')
              .select('id, author_id, user_id')
              .eq('id', parentCommentId)
              .maybeSingle();

    final payload = <String, dynamic>{
      'post_id': postId,
      'author_id': user.id,
      'user_id': user.id,
      'author_name': authorName,
      'author_avatar_url': authorAvatarUrl ?? '',
      'message': message,
      'body': message,
      'image_url': _nullIfEmpty(imageUrl),
      'language': 'english',
      'is_deleted': false,
      'is_locked': false,
      'updated_at': now,
      'parent_comment_id': _nullIfEmpty(parentCommentId),
    };

    final Map<String, dynamic> insertedComment = await _client
        .from('community_comments')
        .insert(payload)
        .select('id')
        .single();

    final int currentCommentCount =
        (postRecord?['comment_count'] as num?)?.toInt() ?? 0;
    await _client
        .from('community_posts')
        .update({'comment_count': currentCommentCount + 1, 'updated_at': now})
        .eq('id', postId);

    final String postTitle =
        _nullIfEmpty(postRecord?['title']?.toString()) ?? 'your post';
    if (parentCommentRecord != null) {
      await _notificationWriter.safeCreateNotification(
        userId:
            _nullIfEmpty(
              parentCommentRecord['author_id']?.toString() ??
                  parentCommentRecord['user_id']?.toString(),
            ) ??
            '',
        type: 'community_comment_reply',
        entityId: insertedComment['id']?.toString(),
        title: authorName,
        body: 'replied to your comment on $postTitle.',
      );
      return;
    }

    await _notificationWriter.safeCreateNotification(
      userId:
          _nullIfEmpty(
            postRecord?['author_id']?.toString() ??
                postRecord?['user_id']?.toString(),
          ) ??
          '',
      type: 'community_post_comment',
      entityId: postId,
      title: authorName,
      body: 'commented on $postTitle.',
    );
  }

  String? _nullIfEmpty(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> updatePost({
    required String postId,
    required String title,
    required String bodyText,
    String? language,
    String? category,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final String trimmedTitle = title.trim();
    final String trimmedBody = bodyText.trim();

    if (trimmedTitle.isEmpty || trimmedBody.isEmpty) {
      throw Exception('Title and content are required');
    }

    final String now = DateTime.now().toUtc().toIso8601String();
    final String normalizedLanguage = _normalizePostLanguage(language);

    await _client
        .from('community_posts')
        .update({
          'title': trimmedTitle,
          'body_text': trimmedBody,
          'plain_text': trimmedBody,
          'language': normalizedLanguage,
          'language_code': _languageCodeFor(normalizedLanguage),
          'category': category,
          'updated_at': now,
        })
        .eq('id', postId);
  }

  Future<void> softDeletePost(String postId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final Map<String, dynamic>? existingPost = await _client
        .from('community_posts')
        .select('image_url, image_urls')
        .eq('id', postId)
        .maybeSingle();

    final List<String> imageUrls = <String>[
      _nullIfEmpty(existingPost?['image_url']?.toString()) ?? '',
      ...((existingPost?['image_urls'] as List<dynamic>? ?? <dynamic>[]).map(
        (dynamic e) => _nullIfEmpty(e.toString()) ?? '',
      )),
    ].where((String value) => value.isNotEmpty).toSet().toList();

    await _client
        .from('community_posts')
        .update({
          'is_deleted': true,
          'image_url': null,
          'image_urls': <String>[],
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', postId);

    for (final String imageUrl in imageUrls) {
      await _imageService.deleteUploadedImageByPublicUrl(imageUrl);
    }
  }

  Future<void> setPostReaction(String postId, String reaction) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final String normalizedReaction = _normalizeReactionOrDefault(reaction);
    final bool hasReactionColumn = await _hasColumn(
      'community_post_likes',
      'reaction',
    );

    final Map<String, dynamic>? existing = await _client
        .from('community_post_likes')
        .select(hasReactionColumn ? 'id,reaction' : 'id')
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();

    final Map<String, dynamic>? postRecord = await _client
        .from('community_posts')
        .select('id, title, author_id, user_id')
        .eq('id', postId)
        .maybeSingle();

    if (existing == null) {
      final Map<String, dynamic> payload = <String, dynamic>{
        'post_id': postId,
        'user_id': user.id,
      };
      if (hasReactionColumn) {
        payload['reaction'] = normalizedReaction;
      }
      await _client.from('community_post_likes').insert(payload);
    } else {
      final String existingReaction = hasReactionColumn
          ? _normalizeReactionOrDefault(existing['reaction']?.toString())
          : CommunityReactionTypes.thumbsUp;
      if (existingReaction == normalizedReaction) {
        await _client
            .from('community_post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id);
      } else if (hasReactionColumn) {
        await _client
            .from('community_post_likes')
            .update({'reaction': normalizedReaction})
            .eq('post_id', postId)
            .eq('user_id', user.id);
      }
    }

    final likeCount = await _countRows(
      'community_post_likes',
      'post_id',
      postId,
    );

    await _client
        .from('community_posts')
        .update({
          'like_count': likeCount,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', postId);

    if (existing == null) {
      final String actorName = await _notificationWriter.getCurrentActorName();
      await _notificationWriter.safeCreateNotification(
        userId:
            _nullIfEmpty(
              postRecord?['author_id']?.toString() ??
                  postRecord?['user_id']?.toString(),
            ) ??
            '',
        type: 'community_post_like',
        entityId: postId,
        title: actorName,
        body:
            'liked ${_nullIfEmpty(postRecord?['title']?.toString()) ?? 'your post'}.',
      );
    }
  }

  Future<void> clearPostReaction(String postId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    await _client
        .from('community_post_likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', user.id);

    final int likeCount = await _countRows(
      'community_post_likes',
      'post_id',
      postId,
    );
    await _client
        .from('community_posts')
        .update({
          'like_count': likeCount,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', postId);
  }

  Future<void> toggleLikePost(String postId) async {
    await setPostReaction(postId, CommunityReactionTypes.thumbsUp);
  }

  Future<void> setCommentReaction(String commentId, String reaction) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final String normalizedReaction = _normalizeReactionOrDefault(reaction);
    final bool hasReactionColumn = await _hasColumn(
      'community_comment_likes',
      'reaction',
    );

    final Map<String, dynamic>? existing = await _client
        .from('community_comment_likes')
        .select(hasReactionColumn ? 'id,reaction' : 'id')
        .eq('comment_id', commentId)
        .eq('user_id', user.id)
        .maybeSingle();

    final Map<String, dynamic>? commentRecord = await _client
        .from('community_comments')
        .select('id, author_id, user_id')
        .eq('id', commentId)
        .maybeSingle();

    if (existing == null) {
      final Map<String, dynamic> payload = <String, dynamic>{
        'comment_id': commentId,
        'user_id': user.id,
      };
      if (hasReactionColumn) {
        payload['reaction'] = normalizedReaction;
      }
      await _client.from('community_comment_likes').insert(payload);
    } else {
      final String existingReaction = hasReactionColumn
          ? _normalizeReactionOrDefault(existing['reaction']?.toString())
          : CommunityReactionTypes.thumbsUp;
      if (existingReaction == normalizedReaction) {
        await _client
            .from('community_comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', user.id);
      } else if (hasReactionColumn) {
        await _client
            .from('community_comment_likes')
            .update({'reaction': normalizedReaction})
            .eq('comment_id', commentId)
            .eq('user_id', user.id);
      }
    }

    final int likeCount = await _countRows(
      'community_comment_likes',
      'comment_id',
      commentId,
    );
    await _client
        .from('community_comments')
        .update({
          'like_count': likeCount,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', commentId);

    if (existing == null) {
      final String actorName = await _notificationWriter.getCurrentActorName();
      await _notificationWriter.safeCreateNotification(
        userId:
            _nullIfEmpty(
              commentRecord?['author_id']?.toString() ??
                  commentRecord?['user_id']?.toString(),
            ) ??
            '',
        type: 'community_comment_like',
        entityId: commentId,
        title: actorName,
        body: 'liked your comment.',
      );
    }
  }

  Future<void> clearCommentReaction(String commentId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    await _client
        .from('community_comment_likes')
        .delete()
        .eq('comment_id', commentId)
        .eq('user_id', user.id);

    final int likeCount = await _countRows(
      'community_comment_likes',
      'comment_id',
      commentId,
    );
    await _client
        .from('community_comments')
        .update({
          'like_count': likeCount,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', commentId);
  }

  Future<void> toggleLikeComment(String commentId) async {
    await setCommentReaction(commentId, CommunityReactionTypes.thumbsUp);
  }

  Future<void> updateComment({
    required String commentId,
    required String message,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final String trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw Exception('Comment cannot be empty');
    }

    await _client
        .from('community_comments')
        .update({
          'message': trimmedMessage,
          'body': trimmedMessage,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', commentId);
  }

  Future<void> softDeleteComment({
    required String commentId,
    required String postId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final Map<String, dynamic>? existingComment = await _client
        .from('community_comments')
        .select('image_url')
        .eq('id', commentId)
        .maybeSingle();
    final String? commentImageUrl = _nullIfEmpty(
      existingComment?['image_url']?.toString(),
    );

    final String now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('community_comments')
        .update({'is_deleted': true, 'image_url': null, 'updated_at': now})
        .eq('id', commentId);

    await _imageService.deleteUploadedImageByPublicUrl(commentImageUrl);

    final commentsResponse = await _client
        .from('community_comments')
        .select('id')
        .eq('post_id', postId)
        .eq('is_deleted', false);

    await _client
        .from('community_posts')
        .update({
          'comment_count': (commentsResponse as List).length,
          'updated_at': now,
        })
        .eq('id', postId);
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
    final bool hasCommentLikesTable = await _hasTable(
      'community_comment_likes',
    );

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

    if (!areFriends &&
        !outgoingPending &&
        !incomingPending &&
        hasRequestsTable) {
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
