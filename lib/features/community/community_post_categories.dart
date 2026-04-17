class CommunityPostCategories {
  static const String all = 'All';
  static const String general = 'General';
  static const String news = 'News';
  static const String discussion = 'Discussion';
  static const String gear = 'Gear';
  static const String field = 'Fields';
  static const String events = 'Events';
  static const String team = 'Team Up';
  static const String advice = 'Advice';
  static const String timeline = 'Timeline';

  static const List<String> communityCategories = <String>[
    general,
    news,
    discussion,
    gear,
    fields,
    events,
    team up,
    advice,
  ];

  static const List<String> communityCategoriesWithAll = <String>[
    all,
    general,
    news,
    discussion,
    gear,
    fields,
    events,
    team up,
    advice,
  ];

  static const List<String> timelineCategories = <String>[
    timeline,
  ];

  static bool isValidCommunityCategory(String? value) {
    if (value == null || value.trim().isEmpty) {
      return false;
    }
    return communityCategories.contains(value.trim());
  }

  static String normalizeCommunityCategory(String? value) {
    if (value == null || value.trim().isEmpty) {
      return general;
    }

    final trimmed = value.trim();
    if (communityCategories.contains(trimmed)) {
      return trimmed;
    }

    return general;
  }

  static String normalizeTimelineCategory(String? value) {
    if (value == null || value.trim().isEmpty) {
      return timeline;
    }

    return timeline;
  }
}
