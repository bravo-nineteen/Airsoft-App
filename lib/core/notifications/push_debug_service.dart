import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushDebugService {
  PushDebugService._();

  static Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    final token = await messaging.getToken();
    debugPrint('FCM token available: ${token != null && token.isNotEmpty}');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message ID: ${message.messageId}');
      debugPrint('Foreground message title: ${message.notification?.title}');
      debugPrint('Foreground message body: ${message.notification?.body}');
      debugPrint('Foreground message data: ${message.data}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened app: ${message.messageId}');
      debugPrint('Opened with data: ${message.data}');
    });

    messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM token refreshed.');
    });
  }
}
