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
  final int commentCount;
  final int likeCount;
  final int viewCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPinned;

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
    required this.commentCount,
    required this.likeCount,
    required this.viewCount,
    required this.createdAt,
    required this.updatedAt,
    required this.isPinned,
  });

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

  factory CommunityPostModel.fromJson(Map<String, dynamic> json) {
    final imageList = (json['image_urls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        <String>[];

    return CommunityPostModel(
      id: json['id'].toString(),
      authorId: json['author_id']?.toString(),
      authorName: (json['author_name'] ?? 'Unknown').toString(),
      authorAvatarUrl: json['author_avatar_url']?.toString(),
      title: (json['title'] ?? '').toString(),
      bodyText: (json['body_text'] ?? '').toString(),
      plainText: (json['plain_text'] ?? '').toString(),
      imageUrl: json['image_url']?.toString(),
      imageUrls: imageList,
      category: json['category']?.toString(),
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'].toString()).toLocal(),
      isPinned: json['is_pinned'] == true,
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
  final int likeCount;
  final bool likedByMe;
  final DateTime createdAt;

  const CommunityCommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.message,
    required this.likeCount,
    required this.likedByMe,
    required this.createdAt,
  });

  CommunityCommentModel copyWith({
    int? likeCount,
    bool? likedByMe,
  }) {
    return CommunityCommentModel(
      id: id,
      postId: postId,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      message: message,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      createdAt: createdAt,
    );
  }

  factory CommunityCommentModel.fromJson(Map<String, dynamic> json) {
    return CommunityCommentModel(
      id: json['id'].toString(),
      postId: json['post_id'].toString(),
      authorId: json['author_id']?.toString(),
      authorName: (json['author_name'] ?? 'Unknown').toString(),
      authorAvatarUrl: json['author_avatar_url']?.toString(),
      message: (json['message'] ?? json['body'] ?? '').toString(),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] == true,
      createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
    );
  }
}