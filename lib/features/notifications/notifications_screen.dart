import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../community/community_post_details_screen.dart';
import '../community/community_user_profile_screen.dart';
import '../events/event_details_screen.dart';
import '../events/event_repository.dart';
import '../social/contacts_screen.dart';
import '../social/direct_message_screen.dart';
import 'notification_model.dart';
import 'notification_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    NotificationRepository? repository,
    EventRepository? eventRepository,
    this.subscribeToRealtime = true,
    this.onOpenNotification,
  }) : _repository = repository,
       _eventRepository = eventRepository;

  final NotificationRepository? _repository;
  final EventRepository? _eventRepository;
  final bool subscribeToRealtime;
  final Future<void> Function(BuildContext context, AppNotificationModel item)?
      onOpenNotification;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationRepository _repository;
  EventRepository? _eventRepository;

  late Future<List<AppNotificationModel>> _future;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _repository = widget._repository ?? NotificationRepository();
    _eventRepository = widget._eventRepository;
    _future = _repository.getNotifications();
    if (widget.subscribeToRealtime) {
      _channel = _repository.subscribeToNotifications(
        onNotification: () async {
          await _refresh();
        },
      );
    }
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _future = _repository.getNotifications();
    });
    await _future;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Updated'),
          duration: Duration(seconds: 1),
        ),
      );
    }
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
      case 'contact_request_accepted':
        return Icons.person_add_alt_1;
      case 'community_post_comment':
        return Icons.comment_outlined;
      case 'community_comment_reply':
        return Icons.reply_outlined;
      case 'community_post_like':
      case 'community_comment_like':
        return Icons.favorite_border;
      case 'moderation_report_triaged':
      case 'moderation_report_actioned':
      case 'moderation_report_dismissed':
        return Icons.gavel_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Future<void> _openNotification(AppNotificationModel item) async {
    try {
      await _repository.markRead(item.id);
    } catch (_) {
      // Keep deep-link navigation working even when marking as read fails.
    }

    if (!mounted) return;
    final AppLocalizations l10n = AppLocalizations.of(context);

    if (widget.onOpenNotification != null) {
      await widget.onOpenNotification!(context, item);
      await _refresh();
      return;
    }

    final String normalizedType = item.type.trim().toLowerCase();

    if (normalizedType == 'contact_request' ||
        normalizedType == 'friend_request' ||
        normalizedType == 'contact_request_accepted') {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ContactsScreen()));
    } else if (normalizedType == 'direct_message') {
      final String? otherUserId = item.entityId?.trim();
      if (otherUserId != null && otherUserId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DirectMessageScreen(
              otherUserId: otherUserId,
              otherDisplayName: item.title.trim().isNotEmpty
                  ? item.title
                  : l10n.t('directMessageFallback'),
            ),
          ),
        );
      } else {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ContactsScreen()));
      }
    } else if (normalizedType == 'community_post_comment' ||
        normalizedType == 'community_post_like' ||
        normalizedType == 'community_comment_reply' ||
        normalizedType == 'community_comment_like') {
      final String? postId = await _resolvePostIdForNotification(item);
      if (postId != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CommunityPostDetailsScreen(postId: postId),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('postNoLongerAvailable'))),
        );
      }
    } else if (normalizedType.contains('event')) {
      final String? eventId = await _resolveEventIdForNotification(item);
      if (eventId != null && eventId.isNotEmpty && mounted) {
        try {
          final EventRepository eventRepository =
              _eventRepository ??= EventRepository();
          final event = await eventRepository.getEventById(eventId);
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
          );
        } catch (_) {
          // Ignore broken event links and just refresh the list.
        }
      }
    } else if (normalizedType.contains('safety') ||
        normalizedType.contains('report')) {
      final _SafetyReportTarget? target = await _resolveSafetyTarget(item);
      if (target != null && mounted) {
        if (target.targetType == 'post' || target.targetType == 'comment') {
          final String? postId = await _resolvePostIdFromSafetyTarget(target);
          if (postId != null && mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CommunityPostDetailsScreen(postId: postId),
              ),
            );
          }
        } else if (target.targetType == 'event') {
          final String? eventId = target.targetId;
          if (eventId != null && eventId.isNotEmpty && mounted) {
            try {
              final EventRepository eventRepository =
                  _eventRepository ??= EventRepository();
              final event = await eventRepository.getEventById(eventId);
              if (!mounted) {
                return;
              }
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EventDetailsScreen(event: event),
                ),
              );
            } catch (_) {
              // Ignore broken links.
            }
          }
        } else {
          final String? userId = target.userId;
          if (userId != null && userId.isNotEmpty && mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CommunityUserProfileScreen(
                  userId: userId,
                  fallbackName: item.title.trim().isNotEmpty
                      ? item.title
                      : l10n.t('operator'),
                ),
              ),
            );
          }
        }
      }
    }

    await _refresh();
  }

  Future<bool> _deleteNotification(AppNotificationModel item) async {
    try {
      await _repository.deleteNotification(item.id);
      await _refresh();
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      final AppLocalizations l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('failedRemoveNotification', args: {'error': '$error'}),
          ),
        ),
      );
      return false;
    }
  }

  Future<String?> _resolvePostIdForNotification(
    AppNotificationModel item,
  ) async {
    final String? entityId = item.entityId?.trim();
    if (entityId == null || entityId.isEmpty) {
      return null;
    }

    final String normalizedType = item.type.trim().toLowerCase();
    if (normalizedType == 'community_post_comment' ||
        normalizedType == 'community_post_like') {
      try {
        final response = await Supabase.instance.client
            .from('community_posts')
            .select('id')
            .eq('id', entityId)
            .maybeSingle();
        if (response != null) {
          return entityId;
        }
      } catch (_) {}

      try {
        final response = await Supabase.instance.client
            .from('community_comments')
            .select('post_id')
            .eq('id', entityId)
            .maybeSingle();
        return response?['post_id']?.toString();
      } catch (_) {
        return null;
      }
    }

    if (normalizedType == 'community_comment_reply' ||
        normalizedType == 'community_comment_like') {
      try {
        final response = await Supabase.instance.client
            .from('community_comments')
            .select('post_id')
            .eq('id', entityId)
            .maybeSingle();
        return response?['post_id']?.toString();
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  Future<String?> _resolveEventIdForNotification(
    AppNotificationModel item,
  ) async {
    final String? entityId = item.entityId?.trim();
    if (entityId == null || entityId.isEmpty) {
      return null;
    }

    try {
      final response = await Supabase.instance.client
          .from('events')
          .select('id')
          .eq('id', entityId)
          .maybeSingle();
      if (response != null) {
        return entityId;
      }
    } catch (_) {}

    try {
      final response = await Supabase.instance.client
          .from('event_attendees')
          .select('event_id')
          .eq('id', entityId)
          .maybeSingle();
      return response?['event_id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<_SafetyReportTarget?> _resolveSafetyTarget(
    AppNotificationModel item,
  ) async {
    final String? entityId = item.entityId?.trim();
    if (entityId == null || entityId.isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic>? reportRow = await Supabase.instance.client
          .from('safety_reports')
          .select('id, reporter_user_id, target_type, target_id')
          .eq('id', entityId)
          .maybeSingle();

      if (reportRow == null) {
        return null;
      }

      final String targetType = (reportRow['target_type'] ?? '').toString();
      final String? targetId = reportRow['target_id']?.toString();
      final String? reporterUserId = reportRow['reporter_user_id']?.toString();

      if (targetType == 'user') {
        return _SafetyReportTarget(
          targetType: targetType,
          targetId: targetId,
          userId: (targetId ?? '').trim().isNotEmpty ? targetId : reporterUserId,
        );
      }

      return _SafetyReportTarget(
        targetType: targetType,
        targetId: targetId,
        userId: reporterUserId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolvePostIdFromSafetyTarget(_SafetyReportTarget target) async {
    final String targetType = target.targetType;
    final String? targetId = target.targetId;
    if ((targetId ?? '').trim().isEmpty) {
      return null;
    }

    if (targetType == 'post') {
      return targetId;
    }

    if (targetType == 'comment') {
      try {
        final Map<String, dynamic>? row = await Supabase.instance.client
            .from('community_comments')
            .select('post_id')
            .eq('id', targetId!)
            .maybeSingle();
        return row?['post_id']?.toString();
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  String _timeLabel(AppLocalizations l10n, DateTime value) {
    final now = DateTime.now();
    final difference = now.difference(value);

    if (difference.inMinutes < 1) return l10n.t('justNow');
    if (difference.inMinutes < 60) {
      return l10n.t(
        'minutesAgoShort',
        args: {'value': '${difference.inMinutes}'},
      );
    }
    if (difference.inHours < 24) {
      return l10n.t('hoursAgoShort', args: {'value': '${difference.inHours}'});
    }
    return l10n.t('daysAgoShort', args: {'value': '${difference.inDays}'});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('notifications')),
        actions: [
          TextButton(
            onPressed: () async {
              await _repository.markAllRead();
              await _refresh();
            },
            child: Text(l10n.t('markAllRead')),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AppNotificationModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SingleChildScrollView(
                child: ShimmerList(count: 8),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 160),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.t(
                          'failedLoadNotifications',
                          args: {'error': '${snapshot.error}'},
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.notifications_none_outlined,
                title: l10n.t('noNotificationsYet'),
                subtitle: 'Activity from the community will appear here.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                return Dismissible(
                  key: ValueKey<String>(item.id),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  secondaryBackground: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  confirmDismiss: (_) async {
                    final bool deleted = await _deleteNotification(item);
                    return deleted;
                  },
                  onDismissed: (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.t('notificationRemoved'))),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(_iconForType(item.type))),
                      title: Text(item.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(item.body),
                          const SizedBox(height: 6),
                          Text(
                            _timeLabel(l10n, item.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (!item.isRead)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.fiber_manual_record, size: 12),
                            ),
                          IconButton(
                            tooltip: l10n.t('deleteNotification'),
                            onPressed: () async {
                              final bool deleted = await _deleteNotification(
                                item,
                              );
                              if (!deleted) {
                                return;
                              }
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.t('notificationRemoved')),
                                ),
                              );
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      onTap: () => _openNotification(item),
                    ),
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

class _SafetyReportTarget {
  const _SafetyReportTarget({
    required this.targetType,
    required this.targetId,
    required this.userId,
  });

  final String targetType;
  final String? targetId;
  final String? userId;
}
