class CommunityModel {
  const CommunityModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.languageCode,
    required this.category,
    this.callSign,
    this.avatarUrl,
    this.imageUrl,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String languageCode;
  final String category;
  final String? callSign;
  final String? avatarUrl;
  final String? imageUrl;

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    return CommunityModel(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
            (json['updated_at'] ?? json['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      languageCode: ((json['language_code'] ?? 'en') as String).trim().isEmpty
          ? 'en'
          : (json['language_code'] as String),
      category: ((json['category'] ?? 'off-topic') as String).trim().isEmpty
          ? 'off-topic'
          : (json['category'] as String),
      callSign: _readNullableString(json['call_sign']),
      avatarUrl: _readNullableString(json['avatar_url']),
      imageUrl: _readNullableString(json['image_url']),
    );
  }

  String get displayName {
    final value = (callSign ?? '').trim();
    return value.isEmpty ? 'Operator' : value;
  }

  bool get hasAvatar => (avatarUrl ?? '').trim().isNotEmpty;
  bool get hasImage => (imageUrl ?? '').trim().isNotEmpty;

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}