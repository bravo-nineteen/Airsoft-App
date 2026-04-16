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
    final rawUserId = _readNullableString(json['user_id']) ??
        _readNullableString(json['author_id']) ??
        '';

    final rawLanguageCode = _readNullableString(json['language_code']) ??
        _readNullableString(json['language']) ??
        'en';

    return CommunityModel(
      id: _readRequiredString(json['id']),
      userId: rawUserId,
      title: _readNullableString(json['title']) ?? '',
      body: _readNullableString(json['body']) ?? '',
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at'], fallback: json['created_at']),
      languageCode: rawLanguageCode.trim().isEmpty ? 'en' : rawLanguageCode,
      category: (_readNullableString(json['category']) ?? 'off-topic').trim().isEmpty
          ? 'off-topic'
          : (_readNullableString(json['category']) ?? 'off-topic'),
      callSign: _firstNonEmpty([
        json['call_sign'],
        json['author_name'],
      ]),
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
  bool get hasValidUserId => _isValidUuid(userId);

  static String _readRequiredString(dynamic value) {
    final text = _readNullableString(value);
    return text ?? '';
  }

  static DateTime _readDateTime(dynamic value, {dynamic fallback}) {
    final primary = DateTime.tryParse((value ?? '').toString());
    if (primary != null) return primary;

    final secondary = DateTime.tryParse((fallback ?? '').toString());
    if (secondary != null) return secondary;

    return DateTime.now();
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = _readNullableString(value);
      if (text != null) return text;
    }
    return null;
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
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}4',
    ).hasMatch(value);
  }
}
