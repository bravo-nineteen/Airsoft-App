import 'package:flutter/material.dart';

import 'community_reaction_types.dart';

class CommunityReactionOption {
  const CommunityReactionOption({
    required this.code,
    required this.label,
    required this.icon,
    required this.color,
    this.assetPath,
  });

  final String code;
  final String label;
  final IconData icon;
  final Color color;
  final String? assetPath;
}

class CommunityReactionUi {
  static const List<CommunityReactionOption> options = <CommunityReactionOption>[
    CommunityReactionOption(
      code: CommunityReactionTypes.thumbsUp,
      label: 'Thumbs up',
      icon: Icons.thumb_up_alt_rounded,
      color: Color(0xFF2E7D32),
      assetPath: 'assets/reactions/thumbs_up.png',
    ),
    CommunityReactionOption(
      code: CommunityReactionTypes.thumbsDown,
      label: 'Thumbs down',
      icon: Icons.thumb_down_alt_rounded,
      color: Color(0xFF6D4C41),
      assetPath: 'assets/reactions/thumbs_down.png',
    ),
    CommunityReactionOption(
      code: CommunityReactionTypes.confused,
      label: 'Confused',
      icon: Icons.help_outline_rounded,
      color: Color(0xFF1565C0),
      assetPath: 'assets/reactions/confused.png',
    ),
    CommunityReactionOption(
      code: CommunityReactionTypes.angry,
      label: 'Angry',
      icon: Icons.sentiment_very_dissatisfied_rounded,
      color: Color(0xFFC62828),
      assetPath: 'assets/reactions/angry.png',
    ),
    CommunityReactionOption(
      code: CommunityReactionTypes.sad,
      label: 'Sad',
      icon: Icons.sentiment_dissatisfied_rounded,
      color: Color(0xFF5C6BC0),
      assetPath: 'assets/reactions/sad.png',
    ),
    CommunityReactionOption(
      code: CommunityReactionTypes.love,
      label: 'Love',
      icon: Icons.favorite_rounded,
      color: Color(0xFFE91E63),
      assetPath: 'assets/reactions/love.png',
    ),
  ];

  static Widget buildIcon(
    CommunityReactionOption option, {
    double size = 20,
    bool useColor = true,
  }) {
    final Color? iconColor = useColor ? option.color : null;
    final String? assetPath = option.assetPath;
    if (assetPath != null && assetPath.trim().isNotEmpty) {
      return Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          option.icon,
          size: size,
          color: iconColor,
        ),
      );
    }
    return Icon(option.icon, size: size, color: iconColor);
  }

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
