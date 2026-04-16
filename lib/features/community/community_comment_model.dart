class CommunityCommentModel {
  const CommunityCommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.callSign,
    this.avatarUrl,
    this.parentCommentId,
  });

  final String id;
  final String postId;
  final String userId;
  final String body;
  final DateTime createdAt;
  final String? callSign;
  final String? avatarUrl;
  final String? parentCommentId;

  factory CommunityCommentModel.fromJson(Map<String, dynamic> json) {
    return CommunityCommentModel(
      id: json['id'].toString(),
      postId: json['post_id'].toString(),
      userId: json['user_id'].toString(),
      body: (json['body'] ?? '') as String,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      callSign: _readNullableString(json['call_sign']),
      avatarUrl: _readNullableString(json['avatar_url']),
      parentCommentId: _readNullableString(json['parent_comment_id']),
    );
  }

  String get displayName {
    final value = (callSign ?? '').trim();
    return value.isEmpty ? 'Operator' : value;
  }

  bool get hasAvatar => (avatarUrl ?? '').trim().isNotEmpty;

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}