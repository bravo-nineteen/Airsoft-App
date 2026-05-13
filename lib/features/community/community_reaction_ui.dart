import 'package:flutter/material.dart';

import 'community_reaction_types.dart';

class CommunityReactionOption {
  const CommunityReactionOption({
    required this.code,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String code;
  final String label;
  final IconData icon;
  final Color color;
}

class CommunityReactionUi {
  static const List<CommunityReactionOption> options = <CommunityReactionOption>[
    CommunityReactionOption(
      code: CommunityReactionTypes.thumbsUp,
      label: 'Thumbs up',
      icon: Icons.thumb_up_alt_rounded,
      color: Color(0xFF2E7D32),
    ),
    CommunityReactionOption(
      code: CommunityReactionTypes.thumbsDown,
      label: 'Thumbs down',
      icon: Icons.thumb_down_alt_rounded,
      color: Color(0xFF6D4C41),
    ),
    CommunityReactionOption(
      code: CommunityReactionTypes.confused,
      label: 'Confused',
      icon: Icons.help_outline_rounded,
      color: Color(0xFF1565C0),
    ),
    CommunityReactionOption(
      code: CommunityReactionTypes.angry,
      label: 'Angry',
      icon: Icons.sentiment_very_dissatisfied_rounded,
      color: Color(0xFFC62828),
    ),
    CommunityReactionOption(
      code: CommunityReactionTypes.sad,
      label: 'Sad',
      icon: Icons.sentiment_dissatisfied_rounded,
      color: Color(0xFF5C6BC0),
    ),
    CommunityReactionOption(
      code: CommunityReactionTypes.love,
      label: 'Love',
      icon: Icons.favorite_rounded,
      color: Color(0xFFE91E63),
    ),
  ];

  static CommunityReactionOption optionFor(String? code) {
    final String? normalized = CommunityReactionTypes.normalizeNullable(code);
    if (normalized == null) {
      return options.first;
    }
    for (final CommunityReactionOption option in options) {
      if (option.code == normalized) {
        return option;
      }
    }
    return options.first;
  }
}
