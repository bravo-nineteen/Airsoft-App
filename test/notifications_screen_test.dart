import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:airsoft_app/features/notifications/notification_model.dart';
import 'package:airsoft_app/features/notifications/notification_repository.dart';
import 'package:airsoft_app/features/notifications/notifications_screen.dart';

class _FakeNotificationRepository extends NotificationRepository {
  _FakeNotificationRepository(this.items);

  final List<AppNotificationModel> items;
  int markAllReadCalls = 0;
  final List<String> markedReadIds = <String>[];

  @override
  Future<List<AppNotificationModel>> getNotifications() async => items;

  @override
  Future<void> markAllRead() async {
    markAllReadCalls += 1;
  }

  @override
  Future<void> markRead(String id) async {
    markedReadIds.add(id);
  }

  @override
  RealtimeChannel subscribeToNotifications({
    required VoidCallback onNotification,
  }) {
    throw UnimplementedError('Realtime should be disabled in widget tests.');
  }
}

void main() {
  testWidgets('Notifications screen does not mark all read on open', (
    WidgetTester tester,
  ) async {
    final _FakeNotificationRepository repository = _FakeNotificationRepository(
      <AppNotificationModel>[
        AppNotificationModel(
          id: 'n1',
          userId: 'user-1',
          type: 'contact_request',
          title: 'Raven',
          body: 'sent you a contact request.',
          isRead: false,
          createdAt: DateTime(2026, 4, 19),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          repository: repository,
          subscribeToRealtime: false,
          onOpenNotification: (_, __) async {},
        ),
      ),
    );
    await tester.pump();

    expect(repository.markAllReadCalls, 0);
    expect(find.text('Raven'), findsOneWidget);
  });

  testWidgets('Notifications screen marks one item read when tapped', (
    WidgetTester tester,
  ) async {
    final _FakeNotificationRepository repository = _FakeNotificationRepository(
      <AppNotificationModel>[
        AppNotificationModel(
          id: 'n1',
          userId: 'user-1',
          type: 'direct_message',
          title: 'Commander',
          body: 'Move to the staging area.',
          isRead: false,
          createdAt: DateTime(2026, 4, 19),
          entityId: 'user-2',
        ),
      ],
    );
    int openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          repository: repository,
          subscribeToRealtime: false,
          onOpenNotification: (_, __) async {
            openCalls += 1;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Commander'));
    await tester.pump();

    expect(repository.markedReadIds, <String>['n1']);
    expect(openCalls, 1);
    expect(repository.markAllReadCalls, 0);
  });
}