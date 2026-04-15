class CommunityModel {
  const CommunityModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.languageCode,
    required this.category,
    this.callSign,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime createdAt;
  final String languageCode;
  final String category;
  final String? callSign;

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    return CommunityModel(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      languageCode: ((json['language_code'] ?? 'en') as String).trim().isEmpty
          ? 'en'
          : (json['language_code'] as String),
      category: ((json['category'] ?? 'off-topic') as String).trim().isEmpty
          ? 'off-topic'
          : (json['category'] as String),
      callSign: json['call_sign'] as String?,
    );
  }
}