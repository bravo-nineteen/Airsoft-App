class CommunityReactionTypes {
  static const String thumbsUp = 'thumbs_up';
  static const String thumbsDown = 'thumbs_down';
  static const String confused = 'confused';
  static const String angry = 'angry';
  static const String sad = 'sad';
  static const String love = 'love';

  static const List<String> values = <String>[
    thumbsUp,
    thumbsDown,
    confused,
    angry,
    sad,
    love,
  ];

  static bool isValid(String? value) {
    if (value == null) {
      return false;
    }
    return values.contains(value.trim());
  }

  static String? normalizeNullable(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (values.contains(trimmed)) {
      return trimmed;
    }
    return thumbsUp;
  }
}
