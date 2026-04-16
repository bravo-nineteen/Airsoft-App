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
      id: _readRequiredUuid(json['id']),
      postId: _readRequiredUuid(json['post_id']),
      userId: _readRequiredUuid(json['user_id']),
      body: _readNullableString(json['body']) ?? '',
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      callSign: _readNullableString(json['call_sign']),
      avatarUrl: _readNullableString(json['avatar_url']),
      parentCommentId: _readNullableUuid(json['parent_comment_id']),
    );
  }

  String get displayName {
    final value = (callSign ?? '').trim();
    return value.isEmpty ? 'Operator' : value;
  }

  bool get hasAvatar => (avatarUrl ?? '').trim().isNotEmpty;

  static String _readRequiredUuid(dynamic value) {
    final text = _readNullableUuid(value);
    return text ?? '';
  }

  static String? _readNullableUuid(dynamic value) {
    final text = _readNullableString(value);
    if (text == null) return null;
    return _isValidUuid(text) ? text : null;
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    if (text.toLowerCase() == 'null') return null;
    return text;
  }

  static bool _isValidUuid(String? value) {
    if (value == null) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}
