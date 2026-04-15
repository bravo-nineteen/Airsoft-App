class CommunityCommentModel {
  const CommunityCommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.callSign,
  });

  final String id;
  final String postId;
  final String userId;
  final String body;
  final DateTime createdAt;
  final String? callSign;

  factory CommunityCommentModel.fromJson(Map<String, dynamic> json) {
    return CommunityCommentModel(
      id: json['id'].toString(),
      postId: json['post_id'].toString(),
      userId: json['user_id'].toString(),
      body: (json['body'] ?? '') as String,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      callSign: json['call_sign'] as String?,
    );
  }
}
