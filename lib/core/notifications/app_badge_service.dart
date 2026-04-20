import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

class AppBadgeService {
  AppBadgeService._();

  static Future<void> setBadgeCount(int count) async {
    if (kIsWeb) {
      return;
    }

    try {
      final bool supported = await FlutterAppBadger.isAppBadgeSupported();
      if (!supported) {
        return;
      }

      if (count <= 0) {
        await FlutterAppBadger.removeBadge();
      } else {
        await FlutterAppBadger.updateBadgeCount(count);
      }
    } catch (_) {
      // Ignore badge update failures on unsupported launchers/devices.
    }
  }
}
