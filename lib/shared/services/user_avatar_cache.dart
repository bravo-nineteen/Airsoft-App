import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory store for user avatar URLs.
///
/// Keyed by user ID. Once a URL is stored here it is returned immediately
/// on subsequent lookups — no network round-trip needed.  The cache is
/// cleared on sign-out via [clear].
class UserAvatarCache {
  UserAvatarCache._();
  static final UserAvatarCache instance = UserAvatarCache._();

  final Map<String, String> _urls = {};

  /// A [ValueNotifier] that holds the *current authenticated user's* avatar
  /// URL.  Widgets that display the current user's avatar should listen to
  /// this so they update immediately when the avatar changes.
  final ValueNotifier<String?> currentUserAvatarUrl = ValueNotifier(null);

  /// Store [url] for [userId] and, if [userId] is the signed-in user, also
  /// update [currentUserAvatarUrl].
  void set(String userId, String? url) {
    if (url == null || url.trim().isEmpty) {
      _urls.remove(userId);
    } else {
      _urls[userId] = url;
    }

    final currentUid = Supabase.instance.client.auth.currentUser?.id;
    if (userId == currentUid) {
      currentUserAvatarUrl.value = url?.trim().isEmpty == true ? null : url;
    }
  }

  /// Returns the cached URL for [userId], or `null` if not yet seen.
  String? get(String userId) => _urls[userId];

  /// Initialise the cache for the signed-in user.  Safe to call on every
  /// profile load — only overwrites if the URL is non-null.
  void warmCurrentUser(String userId, String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      set(userId, avatarUrl);
    } else {
      final currentUid = Supabase.instance.client.auth.currentUser?.id;
      if (userId == currentUid && currentUserAvatarUrl.value == null) {
        currentUserAvatarUrl.value = null;
      }
    }
  }

  /// Remove all cached entries (call on sign-out).
  void clear() {
    _urls.clear();
    currentUserAvatarUrl.value = null;
  }
}
