import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import '../services/user_avatar_cache.dart';

/// A circular avatar that caches the image to disk (via [ExtendedImage]) so
/// it is only downloaded once.  Pass [userId] when displaying another user's
/// avatar so the [UserAvatarCache] is consulted and updated automatically.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.userId,
    this.avatarUrl,
    this.radius = 20,
    this.initials,
  });

  /// Optional user ID — used to look up / store the URL in [UserAvatarCache].
  final String? userId;

  /// The avatar URL to display.  When [userId] is also provided the URL is
  /// written into [UserAvatarCache] so later widgets skip the network hit.
  final String? avatarUrl;

  /// Fallback initials shown when there is no avatar URL.
  final String? initials;

  final double radius;

  String? _resolvedUrl() {
    // Prefer an explicitly passed URL.
    String? url = avatarUrl?.trim().isEmpty == true ? null : avatarUrl;
    // Fall back to the cache if a userId was given.
    if ((url == null || url.isEmpty) && userId != null) {
      url = UserAvatarCache.instance.get(userId!);
    }
    // Populate the cache whenever we have both pieces.
    if (url != null && url.isNotEmpty && userId != null) {
      UserAvatarCache.instance.set(userId!, url);
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolvedUrl();

    if (url == null || url.isEmpty) {
      return _Fallback(initials: initials, radius: radius);
    }

    return ClipOval(
      child: ExtendedImage.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        cache: true,
        loadStateChanged: (ExtendedImageState state) {
          switch (state.extendedImageLoadState) {
            case LoadState.loading:
              return _Fallback(initials: initials, radius: radius);
            case LoadState.failed:
              return _Fallback(initials: initials, radius: radius);
            case LoadState.completed:
              return null; // use default completed widget
          }
        },
      ),
    );
  }
}

/// A [UserAvatar] that rebuilds whenever the *current user's* avatar URL
/// changes (listens to [UserAvatarCache.currentUserAvatarUrl]).
class CurrentUserAvatar extends StatelessWidget {
  const CurrentUserAvatar({
    super.key,
    required this.userId,
    this.radius = 20,
    this.initials,
  });

  final String userId;
  final double radius;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: UserAvatarCache.instance.currentUserAvatarUrl,
      builder: (context, url, _) {
        return UserAvatar(
          userId: userId,
          avatarUrl: url,
          radius: radius,
          initials: initials,
        );
      },
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({this.initials, required this.radius});
  final String? initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: initials != null && initials!.isNotEmpty
          ? Text(
              initials!.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: radius * 0.85,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            )
          : Icon(
              Icons.person,
              size: radius,
              color: theme.colorScheme.onPrimaryContainer,
            ),
    );
  }
}
