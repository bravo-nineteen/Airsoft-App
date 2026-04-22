import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_nav_service.dart';
import 'push_token_repository.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final PushTokenRepository _tokenRepository = PushTokenRepository();
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _foregroundChannel =
      AndroidNotificationChannel(
        'fieldops_push_foreground',
        'FieldOps Push Notifications',
        description: 'Notifications shown while app is in foreground',
        importance: Importance.high,
      );

  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<AuthState>? _authSubscription;
  static String? _lastRegisteredUserId;
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

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _initLocalNotifications();

    debugPrint('Push permission status: ${permission.authorizationStatus}');

    await _registerCurrentToken();

    _authSubscription?.cancel();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (AuthState state) async {
        final String? nextUserId = state.session?.user.id;
        if (nextUserId == null || nextUserId == _lastRegisteredUserId) {
          return;
        }
        await _registerCurrentToken();
      },
    );

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

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('Foreground push received: ${message.messageId}');
      await _showForegroundNotification(message);
    });

    // App in background → user taps notification.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final target = NotificationNavTarget.fromMessage(message);
      if (target != null) {
        NotificationNavService.instance.push(target);
      }
    });

    // App was terminated → user tapped notification to launch app.
    final RemoteMessage? initialMessage =
        await _messaging.getInitialMessage();
    if (initialMessage != null) {
      final target = NotificationNavTarget.fromMessage(initialMessage);
      if (target != null) {
        NotificationNavService.instance.storeColdStart(target);
      }
    }
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

  static Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _localNotificationsPlugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    final androidImplementation = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(_foregroundChannel);
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      return;
    }

    await _localNotificationsPlugin.show(
      message.messageId.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fieldops_push_foreground',
          'FieldOps Push Notifications',
          channelDescription: 'Notifications shown while app is in foreground',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> _saveToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('Skipping FCM token save because user is not authenticated yet.');
      return;
    }

    final platform = _platformName();

    await _tokenRepository.upsertToken(
      token: token,
      platform: platform,
      deviceName: platform,
    );
    _lastRegisteredUserId = user.id;
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
