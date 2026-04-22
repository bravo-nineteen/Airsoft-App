import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

/// Holds a pending deep-link navigation target extracted from a push
/// notification so that the shell can act on it once it is mounted.
class NotificationNavTarget {
  const NotificationNavTarget({required this.type, this.entityId});

  final String type;
  final String? entityId;

  /// Extracts a navigation target from an FCM [RemoteMessage].
  /// The FCM payload is expected to contain `type` and optionally `entity_id`
  /// in the `data` map.
  static NotificationNavTarget? fromMessage(RemoteMessage message) {
    final String type = message.data['type']?.toString().trim() ?? '';
    final String entityId =
        message.data['entity_id']?.toString().trim() ?? '';
    if (type.isEmpty) return null;
    return NotificationNavTarget(
      type: type,
      entityId: entityId.isEmpty ? null : entityId,
    );
  }
}

/// Singleton that bridges push notification taps to in-app navigation.
///
/// Usage:
///   // On notification tap:
///   NotificationNavService.instance.push(target);
///
///   // In the shell, subscribe:
///   NotificationNavService.instance.stream.listen(_handleNavTarget);
class NotificationNavService {
  NotificationNavService._();

  static final NotificationNavService instance = NotificationNavService._();

  final StreamController<NotificationNavTarget> _controller =
      StreamController<NotificationNavTarget>.broadcast();

  /// Stream of navigation targets. Subscribe in the shell.
  Stream<NotificationNavTarget> get stream => _controller.stream;

  // Stored when the app was cold-started from a notification tap.
  NotificationNavTarget? _cold;

  /// Call this when the app was launched from a terminated state via a push
  /// notification tap (from [FirebaseMessaging.getInitialMessage]).
  void storeColdStart(NotificationNavTarget target) {
    _cold = target;
  }

  /// Consumes and returns the cold-start target (if any).
  NotificationNavTarget? consumeColdStart() {
    final t = _cold;
    _cold = null;
    return t;
  }

  /// Pushes a target to the navigation stream (used when app is in background
  /// and the user taps a notification).
  void push(NotificationNavTarget target) {
    _controller.add(target);
  }
}
