import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/events/event_model.dart';

/// Schedules and cancels local reminder notifications for events the user has
/// RSVPed to.  Two reminders are scheduled per event:
///   • 24 hours before [EventModel.startsAt]
///   • 1 hour  before [EventModel.startsAt]
class EventReminderService {
  EventReminderService._();

  static final EventReminderService instance = EventReminderService._();

  static const AndroidNotificationDetails _android = AndroidNotificationDetails(
    'fieldops_event_reminders',
    'Event Reminders',
    channelDescription: 'Reminders before events you are attending',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _android,
    iOS: DarwinNotificationDetails(),
  );

  static bool _tzInitialized = false;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Must be called once at app startup (after [FlutterLocalNotificationsPlugin]
  /// is already initialised in [PushNotificationService.init]).
  static Future<void> ensureTimezoneInitialized() async {
    if (_tzInitialized) return;
    _tzInitialized = true;
    tz.initializeTimeZones();
  }

  /// Schedules 24-hour and 1-hour reminders for [event].
  /// Safe to call even if the event is in the past (no-ops).
  Future<void> scheduleReminders(EventModel event) async {
    await ensureTimezoneInitialized();
    final now = DateTime.now().toUtc();
    final startsAt = event.startsAt.toUtc();

    final reminder24h = startsAt.subtract(const Duration(hours: 24));
    final reminder1h  = startsAt.subtract(const Duration(hours: 1));

    if (reminder24h.isAfter(now)) {
      await _schedule(
        id: _id24h(event.id),
        title: '📅 ${event.title} — Tomorrow',
        body: 'Your event starts tomorrow. Get your gear ready!',
        scheduledDate: reminder24h,
      );
    }

    if (reminder1h.isAfter(now)) {
      await _schedule(
        id: _id1h(event.id),
        title: '⏰ ${event.title} — Starting Soon',
        body: 'Your event starts in 1 hour. Time to head out!',
        scheduledDate: reminder1h,
      );
    }
  }

  /// Cancels any reminders previously scheduled for [eventId].
  Future<void> cancelReminders(String eventId) async {
    try {
      await _plugin.cancel(_id24h(eventId));
      await _plugin.cancel(_id1h(eventId));
    } catch (e) {
      debugPrint('EventReminderService: cancel failed: $e');
    }
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      final tz.TZDateTime tzDate =
          tz.TZDateTime.from(scheduledDate, tz.UTC);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('EventReminderService: schedule failed: $e');
    }
  }

  /// Notification ID for the 24-hour reminder.  Uses the last 4 hex chars of
  /// the event ID to fit within a 32-bit int, XORed with a salt.
  int _id24h(String eventId) => _hashId(eventId, 0x1000);

  /// Notification ID for the 1-hour reminder.
  int _id1h(String eventId)  => _hashId(eventId, 0x2000);

  int _hashId(String eventId, int salt) {
    final clean = eventId.replaceAll('-', '');
    final chunk = clean.length > 7 ? clean.substring(clean.length - 7) : clean;
    return (int.tryParse(chunk, radix: 16) ?? chunk.hashCode) ^ salt;
  }
}
