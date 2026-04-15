class CommunityModel {
  const CommunityModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.callSign,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? callSign;

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    return CommunityModel(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      callSign: json['call_sign'] as String?,
    );
  }
}
