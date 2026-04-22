import '../../core/time/japan_time.dart';

class CommunityPostModel {
  final String id;
  final String? authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String title;
  final String bodyText;
  final String plainText;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? category;
  final String? language;
  final String? languageCode;
  final int commentCount;
  final int likeCount;
  final int viewCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPinned;
  final String postContext;
  final String? targetUserId;
  final bool isLikedByMe;

  const CommunityPostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.title,
    required this.bodyText,
    required this.plainText,
    required this.imageUrl,
    required this.imageUrls,
    required this.category,
    required this.language,
    required this.languageCode,
    required this.commentCount,
    required this.likeCount,
    required this.viewCount,
    required this.createdAt,
    required this.updatedAt,
    required this.isPinned,
    required this.postContext,
    required this.targetUserId,
    this.isLikedByMe = false,
  });

  CommunityPostModel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatarUrl,
    String? title,
    String? bodyText,
    String? plainText,
    Object? imageUrl = _communityPostNoChange,
    List<String>? imageUrls,
    Object? category = _communityPostNoChange,
    Object? language = _communityPostNoChange,
    Object? languageCode = _communityPostNoChange,
    int? likeCount,
    int? commentCount,
    int? viewCount,
    DateTime? createdAt,
    Object? updatedAt = _communityPostNoChange,
    bool? isPinned,
    String? postContext,
    Object? targetUserId = _communityPostNoChange,
    bool? isLikedByMe,
  }) {
    return CommunityPostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      title: title ?? this.title,
      bodyText: bodyText ?? this.bodyText,
      plainText: plainText ?? this.plainText,
      imageUrl:
          imageUrl == _communityPostNoChange ? this.imageUrl : imageUrl as String?,
      imageUrls: imageUrls ?? this.imageUrls,
      category: category == _communityPostNoChange
          ? this.category
          : category as String?,
      language: language == _communityPostNoChange
          ? this.language
          : language as String?,
      languageCode: languageCode == _communityPostNoChange
          ? this.languageCode
          : languageCode as String?,
      commentCount: commentCount ?? this.commentCount,
      likeCount: likeCount ?? this.likeCount,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt == _communityPostNoChange
          ? this.updatedAt
          : updatedAt as DateTime?,
      isPinned: isPinned ?? this.isPinned,
      postContext: postContext ?? this.postContext,
      targetUserId: targetUserId == _communityPostNoChange
          ? this.targetUserId
          : targetUserId as String?,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }

  String get excerpt {
    final source = bodyText.isNotEmpty ? bodyText : plainText;
    final normalized = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 160) {
      return normalized;
    }
    return '${normalized.substring(0, 157)}...';
  }

  String? get primaryImageUrl {
    if (imageUrls.isNotEmpty) {
      return imageUrls.first;
    }
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return imageUrl;
    }
    return null;
  }

  bool get isProfilePost => postContext == 'profile';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar_url': authorAvatarUrl,
      'title': title,
      'body_text': bodyText,
      'plain_text': plainText,
      'image_url': imageUrl,
      'image_urls': imageUrls,
      'category': category,
      'language': language,
      'language_code': languageCode,
      'comment_count': commentCount,
      'like_count': likeCount,
      'view_count': viewCount,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
      'is_pinned': isPinned,
      'is_liked_by_me': isLikedByMe,
      'post_context': postContext,
      'target_user_id': targetUserId,
    };
  }

  factory CommunityPostModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawImageUrls = json['image_urls'];
    final List<String> parsedImageUrls;

    if (rawImageUrls is List) {
      parsedImageUrls = rawImageUrls
          .map((dynamic e) => e.toString().trim())
          .where((String e) => e.isNotEmpty)
          .toList();
    } else {
      parsedImageUrls = <String>[];
    }

    final authorId = _readNullableString(json['author_id']) ??
        _readNullableString(json['user_id']);

    return CommunityPostModel(
      id: (json['id'] ?? '').toString(),
      authorId: authorId,
      authorName: _readNullableString(json['author_name']) ?? 'Unknown',
      authorAvatarUrl: _readNullableString(json['author_avatar_url']),
      title: _readNullableString(json['title']) ?? '',
      bodyText: _readNullableString(json['body_text']) ?? '',
      plainText: _readNullableString(json['plain_text']) ?? '',
      imageUrl: _readNullableString(json['image_url']),
      imageUrls: parsedImageUrls,
      category: _readNullableString(json['category']),
      language: _readNullableString(json['language']),
      languageCode: _readNullableString(json['language_code']),
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
        createdAt: JapanTime.parseServerTimestamp(json['created_at']) ??
          DateTime.now(),
        updatedAt: JapanTime.parseServerTimestamp(json['updated_at']),
      isPinned: json['is_pinned'] == true,
      postContext: _readNullableString(json['post_context']) ?? 'community',
      targetUserId: _readNullableString(json['target_user_id']),
      isLikedByMe:
          json['is_liked_by_me'] == true || json['liked_by_me'] == true,
    );
  }
}

class CommunityCommentModel {
  final String id;
  final String postId;
  final String? authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String message;
  final String? imageUrl;
  final int likeCount;
  final bool likedByMe;
  final DateTime createdAt;
  final String? parentCommentId;

  const CommunityCommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.message,
    required this.imageUrl,
    required this.likeCount,
    required this.likedByMe,
    required this.createdAt,
    this.parentCommentId,
  });

  CommunityCommentModel copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorAvatarUrl,
    String? message,
    Object? imageUrl = _communityCommentNoChange,
    int? likeCount,
    bool? likedByMe,
    DateTime? createdAt,
    Object? parentCommentId = _communityCommentNoChange,
  }) {
    return CommunityCommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      message: message ?? this.message,
        imageUrl: imageUrl == _communityCommentNoChange
          ? this.imageUrl
          : imageUrl as String?,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      createdAt: createdAt ?? this.createdAt,
      parentCommentId: parentCommentId == _communityCommentNoChange
          ? this.parentCommentId
          : parentCommentId as String?,
    );
  }

  factory CommunityCommentModel.fromJson(Map<String, dynamic> json) {
    final authorId = _readNullableString(json['author_id']) ??
        _readNullableString(json['user_id']);

    return CommunityCommentModel(
      id: (json['id'] ?? '').toString(),
      postId: (json['post_id'] ?? '').toString(),
      authorId: authorId,
      authorName: _readNullableString(json['author_name']) ?? 'Unknown',
      authorAvatarUrl: _readNullableString(json['author_avatar_url']),
      message: _readNullableString(json['message']) ??
          _readNullableString(json['body']) ??
          '',
        imageUrl: _readNullableString(json['image_url']),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] == true,
      createdAt: JapanTime.parseServerTimestamp(json['created_at']) ??
          DateTime.now(),
      parentCommentId: _readNullableString(json['parent_comment_id']),
    );
  }
}

const Object _communityCommentNoChange = Object();
const Object _communityPostNoChange = Object();

String? _readNullableString(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
}

class CommunityPostsPage {
  const CommunityPostsPage({
    required this.items,
    required this.nextOffset,
    required this.hasMore,
  });

  final List<CommunityPostModel> items;
  final int nextOffset;
  final bool hasMore;
}

class CommunityPostPoll {
  const CommunityPostPoll({
    required this.id,
    required this.postId,
    required this.question,
    required this.allowMultiple,
    required this.options,
    required this.selectedOptionIds,
    required this.totalVotes,
    this.expiresAt,
  });

  final String id;
  final String postId;
  final String question;
  final bool allowMultiple;
  final List<CommunityPostPollOption> options;
  final Set<String> selectedOptionIds;
  final int totalVotes;
  final DateTime? expiresAt;

  bool get isExpired {
    if (expiresAt == null) {
      return false;
    }
    return JapanTime.now().isAfter(expiresAt!);
  }

  bool get hasVoted => selectedOptionIds.isNotEmpty;

  CommunityPostPoll copyWith({
    String? id,
    String? postId,
    String? question,
    bool? allowMultiple,
    List<CommunityPostPollOption>? options,
    Set<String>? selectedOptionIds,
    int? totalVotes,
    Object? expiresAt = _communityPostNoChange,
  }) {
    return CommunityPostPoll(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      question: question ?? this.question,
      allowMultiple: allowMultiple ?? this.allowMultiple,
      options: options ?? this.options,
      selectedOptionIds: selectedOptionIds ?? this.selectedOptionIds,
      totalVotes: totalVotes ?? this.totalVotes,
      expiresAt: expiresAt == _communityPostNoChange
          ? this.expiresAt
          : expiresAt as DateTime?,
    );
  }
}

class CommunityPostPollOption {
  const CommunityPostPollOption({
    required this.id,
    required this.pollId,
    required this.optionText,
    required this.sortOrder,
    required this.voteCount,
  });

  final String id;
  final String pollId;
  final String optionText;
  final int sortOrder;
  final int voteCount;

  CommunityPostPollOption copyWith({
    String? id,
    String? pollId,
    String? optionText,
    int? sortOrder,
    int? voteCount,
  }) {
    return CommunityPostPollOption(
      id: id ?? this.id,
      pollId: pollId ?? this.pollId,
      optionText: optionText ?? this.optionText,
      sortOrder: sortOrder ?? this.sortOrder,
      voteCount: voteCount ?? this.voteCount,
    );
  }
}
