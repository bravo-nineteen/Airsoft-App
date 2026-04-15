import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_token_repository.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final PushTokenRepository _tokenRepository = PushTokenRepository();

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Push permission status: ${permission.authorizationStatus}');

    await _registerCurrentToken();

    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (newToken) async {
        debugPrint('FCM token refreshed.');
        await _saveToken(newToken);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM token refresh listener error: $error');
      },
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground push received: ${message.messageId}');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Push opened app: ${message.messageId}');
      debugPrint('Open data: ${message.data}');
    });
  }

  static Future<void> _registerCurrentToken() async {
    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) {
      debugPrint('No FCM token returned.');
      return;
    }

    debugPrint('FCM token acquired.');
    await _saveToken(token);
  }

  static Future<void> _saveToken(String token) async {
    final platform = _platformName();

    await _tokenRepository.upsertToken(
      token: token,
      platform: platform,
      deviceName: platform,
    );
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
