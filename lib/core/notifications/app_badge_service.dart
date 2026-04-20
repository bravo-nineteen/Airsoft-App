import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppBadgeService {
  AppBadgeService._();

  static Future<void> setBadgeCount(int count) async {
    if (kIsWeb) {
      return;
    }

    try {
      final TargetPlatform platform = defaultTargetPlatform;
      final bool supported =
          platform == TargetPlatform.android ||
          platform == TargetPlatform.iOS ||
          platform == TargetPlatform.macOS;
      if (!supported) {
        return;
      }

      await AppBadgePlus.updateBadge(count < 0 ? 0 : count);
    } catch (_) {
      // Ignore badge update failures on unsupported launchers/devices.
    }
  }
}
