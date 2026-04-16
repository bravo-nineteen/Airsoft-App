import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../social/contacts_screen.dart';
import 'notification_model.dart';
import 'notification_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationRepository _repository = NotificationRepository();

  late Future<List<AppNotificationModel>> _future;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _future = _repository.getNotifications();
    _channel = _repository.subscribeToNotifications(
      onNotification: () async {
        await _refresh();
      },
    );
    _markAllReadSoon();
  }

  Future<void> _markAllReadSoon() async {
    await _repository.markAllRead();
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repository.getNotifications();
    });
    await _future;
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'direct_message':
        return Icons.chat_bubble_outline;
      case 'contact_request':
        return Icons.person_add_alt_1;
      case 'community_post_comment':
        return Icons.comment_outlined;
      case 'community_comment_reply':
        return Icons.reply_outlined;
      case 'community_post_like':
      case 'community_comment_like':
        return Icons.favorite_border;
      default:
        return Icons.notifications_none;
    }
  }

  Future<void> _openNotification(AppNotificationModel item) async {
    await _repository.markRead(item.id);

    if (!mounted) return;

    if (item.type == 'contact_request' || item.type == 'direct_message') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ContactsScreen()),
      );
    }

    await _refresh();
  }

  String _timeLabel(DateTime value) {
    final now = DateTime.now();
    final difference = now.difference(value);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await _repository.markAllRead();
              await _refresh();
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AppNotificationModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 160),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Failed to load notifications:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('No notifications yet.')),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(_iconForType(item.type)),
                    ),
                    title: Text(item.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(item.body),
                        const SizedBox(height: 6),
                        Text(
                          _timeLabel(item.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    trailing: item.isRead
                        ? null
                        : const Icon(Icons.fiber_manual_record, size: 12),
                    onTap: () => _openNotification(item),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}