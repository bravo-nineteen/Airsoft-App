import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/widgets/user_avatar.dart';
import '../events/event_details_screen.dart';
import '../events/event_model.dart';
import '../events/event_repository.dart';
import '../safety/safety_repository.dart';
import '../social/contact_repository.dart';
import '../social/direct_message_screen.dart';
import 'community_create_post_screen.dart';
import 'community_model.dart';
import 'community_post_details_screen.dart';
import 'community_repository.dart';

class CommunityUserProfileScreen extends StatelessWidget {
  const CommunityUserProfileScreen({
    super.key,
    required this.userId,
    this.fallbackName = 'Operator',
  });

  final String userId;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    return CommunityPublicProfileScreen(
      userId: userId,
      fallbackName: fallbackName,
    );
  }
}

class CommunityPublicProfileScreen extends StatefulWidget {
  const CommunityPublicProfileScreen({
    super.key,
    required this.userId,
    required this.fallbackName,
  });

  final String userId;
  final String fallbackName;

  @override
  State<CommunityPublicProfileScreen> createState() =>
      _CommunityPublicProfileScreenState();
}

class _CommunityPublicProfileScreenState
    extends State<CommunityPublicProfileScreen>
    with SingleTickerProviderStateMixin {
  final CommunityRepository _repository = CommunityRepository();
  final EventRepository _eventRepository = EventRepository();
  final ContactRepository _contactRepository = ContactRepository();
  final SafetyRepository _safetyRepository = SafetyRepository();

  Map<String, dynamic>? _profile;
  List<CommunityPostModel> _timelinePosts = <CommunityPostModel>[];
  List<CommunityCommentModel> _recentComments = <CommunityCommentModel>[];
  List<EventModel> _attendingEvents = <EventModel>[];
  EventAttendanceStats _eventStats = const EventAttendanceStats();
  int _receivedLikesCount = 0;

  bool _isLoading = true;
  bool _isSendingFriendRequest = false;

  bool _isSelf = false;
  bool _isLoggedIn = false;
  bool _areFriends = false;
  bool _outgoingPending = false;
  bool _incomingPending = false;
  bool _canMessage = false;

    late final TabController _tabController =
      TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<dynamic> results = await Future.wait<dynamic>([
      _repository.fetchProfileByUserId(widget.userId),
      _repository.fetchMergedTimelinePosts(widget.userId),
      _repository.fetchCommentsByAuthor(widget.userId, limit: 20),
      _repository.fetchUserReceivedLikesCount(widget.userId),
      _repository.fetchFriendshipState(widget.userId),
      _eventRepository.getUserAttendingEvents(widget.userId),
      _eventRepository.getUserEventStats(widget.userId),
      ]);

      final Map<String, dynamic>? profile = results[0] as Map<String, dynamic>?;
      final List<CommunityPostModel> timelinePosts =
        results[1] as List<CommunityPostModel>;
      final List<CommunityCommentModel> recentComments =
        results[2] as List<CommunityCommentModel>;
      final int receivedLikesCount = results[3] as int;
      final Map<String, dynamic> friendshipState =
        results[4] as Map<String, dynamic>;
      final List<EventModel> attendingEvents = results[5] as List<EventModel>;
      final EventAttendanceStats eventStats = results[6] as EventAttendanceStats;

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _timelinePosts = timelinePosts;
        _recentComments = recentComments;
        _attendingEvents = attendingEvents;
        _eventStats = eventStats;
        _receivedLikesCount = receivedLikesCount;
        _isSelf = friendshipState['isSelf'] == true;
        _isLoggedIn = friendshipState['isLoggedIn'] == true;
        _areFriends = friendshipState['areFriends'] == true;
        _outgoingPending = friendshipState['outgoingPending'] == true;
        _incomingPending = friendshipState['incomingPending'] == true;
        _canMessage = friendshipState['canMessage'] == true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $error')),
      );
    }
  }

  String get _displayName {
    final String profileName = (_profile?['call_sign'] ?? '').toString().trim();
    if (profileName.isNotEmpty) {
      return profileName;
    }
    return widget.fallbackName;
  }

  String? get _avatarUrl {
    final String value = (_profile?['avatar_url'] ?? '').toString().trim();
    if (value.isEmpty) {
      return null;
    }
    return value;
  }

  String? get _bio {
    final String value = (_profile?['bio'] ?? '').toString().trim();
    if (value.isEmpty) {
      return null;
    }
    return value;
  }

  bool get _canCreateTimelinePost {
    final User? currentUser = Supabase.instance.client.auth.currentUser;
    return currentUser != null && currentUser.id == widget.userId;
  }

  Widget _buildAvatar(double size) {
    return UserAvatar(
      userId: widget.userId,
      avatarUrl: _avatarUrl,
      radius: size / 2,
      initials: _displayName,
    );
  }

  String _formatDate(DateTime value) {
    return DateFormat('dd MMM yyyy').format(value);
  }

  Future<void> _openPost(CommunityPostModel post) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailsScreen(postId: post.id),
      ),
    );

    await _load();
  }

  Future<void> _openEvent(EventModel event) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EventDetailsScreen(event: event),
      ),
    );

    await _load();
  }

  Future<void> _openCreateTimelinePost() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityCreatePostScreen(
          postContext: 'profile',
          targetUserId: widget.userId,
          appBarTitle: 'New Timeline Post',
        ),
      ),
    );

    await _load();
  }

  Future<void> _sendFriendRequest() async {
    if (_isSendingFriendRequest || _isSelf || _areFriends || _outgoingPending) {
      return;
    }

    setState(() {
      _isSendingFriendRequest = true;
    });

    try {
      await _repository.sendFriendRequest(widget.userId);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent')),
      );

      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send friend request: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingFriendRequest = false;
        });
      }
    }
  }

  Future<void> _acceptIncomingRequest() async {
    if (_isSendingFriendRequest) return;
    setState(() => _isSendingFriendRequest = true);
    try {
      await _contactRepository.sendRequest(widget.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request accepted')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept request: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSendingFriendRequest = false);
    }
  }

  Future<void> _confirmAndRemoveFriend() async {
    if (_isSendingFriendRequest || !_areFriends) {
      return;
    }

    final bool? shouldRemove = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Remove friend?'),
          content: Text('Remove $_displayName from your friends list?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true) {
      return;
    }

    setState(() {
      _isSendingFriendRequest = true;
    });

    try {
      await _contactRepository.removeFriendByUserId(widget.userId);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend removed')),
      );

      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove friend: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingFriendRequest = false;
        });
      }
    }
  }

  Future<void> _onMessagePressed() async {
    if (!_canMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messaging is available for friends only')),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DirectMessageScreen(
          otherUserId: widget.userId,
          otherDisplayName: _displayName,
        ),
      ),
    );

    await _load();
  }

  Future<void> _reportUser() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('mustBeLoggedInToReport'))),
      );
      return;
    }

    String selectedReason = 'other';
    final TextEditingController detailsController = TextEditingController();
    final bool? shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(l10n.t('reportUser')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'spam', child: Text(l10n.t('reportReasonSpam'))),
                      DropdownMenuItem(value: 'harassment', child: Text(l10n.t('reportReasonHarassment'))),
                      DropdownMenuItem(value: 'hate', child: Text(l10n.t('reportReasonHate'))),
                      DropdownMenuItem(value: 'scam', child: Text(l10n.t('reportReasonScam'))),
                      DropdownMenuItem(value: 'other', child: Text(l10n.t('other'))),
                    ],
                    onChanged: (String? value) {
                      setState(() {
                        selectedReason = value ?? 'other';
                      });
                    },
                    decoration: InputDecoration(labelText: l10n.t('reason')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(labelText: l10n.t('detailsOptional')),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.t('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.t('submitReport')),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSubmit != true) {
      detailsController.dispose();
      return;
    }

    try {
      await _safetyRepository.submitReport(
        targetType: 'user',
        targetId: widget.userId,
        reasonCategory: selectedReason,
        details: detailsController.text,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('reportSubmitted'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('actionFailed', args: {'error': '$error'}))),
      );
    } finally {
      detailsController.dispose();
    }
  }

  Future<void> _blockUser() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('mustBeLoggedInToReport'))),
      );
      return;
    }
    try {
      await _safetyRepository.blockUser(widget.userId);
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('userBlocked'))),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('actionFailed', args: {'error': '$error'}))),
      );
    }
  }

  Future<void> _muteUser() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('mustBeLoggedInToReport'))),
      );
      return;
    }
    try {
      await _safetyRepository.muteUser(widget.userId);
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('userMuted'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('actionFailed', args: {'error': '$error'}))),
      );
    }
  }

  Widget _buildRelationshipActions(ThemeData theme) {
    if (_isSelf) {
      return const SizedBox.shrink();
    }

    String friendLabel = 'Add Friend';
    VoidCallback? friendAction = _sendFriendRequest;
    IconData friendIcon = Icons.person_add_alt_1;

    if (!_isLoggedIn) {
      friendLabel = 'Login Required';
      friendAction = null;
      friendIcon = Icons.lock_outline;
    } else if (_areFriends) {
      friendLabel = 'Remove Friend';
      friendAction = _confirmAndRemoveFriend;
      friendIcon = Icons.person_remove_outlined;
    } else if (_outgoingPending) {
      friendLabel = 'Requested';
      friendAction = null;
      friendIcon = Icons.schedule;
    } else if (_incomingPending) {
      friendLabel = 'Accept Request';
      friendAction = _acceptIncomingRequest;
      friendIcon = Icons.person_add_outlined;
    } else if (_isSendingFriendRequest) {
      friendLabel = 'Sending...';
      friendAction = null;
      friendIcon = Icons.hourglass_top;
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: friendAction,
            icon: Icon(friendIcon),
            label: Text(friendLabel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _canMessage ? () => _onMessagePressed() : null,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Message'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _canMessage ? null : theme.disabledColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(
    BuildContext context,
    CommunityPostModel post, {
    bool showContextChip = false,
  }) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openPost(post),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if ((post.primaryImageUrl ?? '').isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: ExtendedImage.network(
                      post.primaryImageUrl!,
                      fit: BoxFit.cover,
                      cache: true,
                    ),
                  ),
                )
              else
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    post.isProfilePost ? Icons.timeline : Icons.article_outlined,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (showContextChip)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Chip(
                          label: Text(post.isProfilePost ? 'Timeline' : 'Post'),
                        ),
                      ),
                    if ((post.category ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Chip(
                          label: Text(post.category!),
                        ),
                      ),
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.excerpt.isEmpty
                          ? 'No preview text available.'
                          : post.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: <Widget>[
                        Text(
                          _formatDate(post.createdAt),
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          'Likes ${post.likeCount}',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          'Comments ${post.commentCount}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, EventModel event) {
    final ThemeData theme = Theme.of(context);
    final String venue = <String>[
      if ((event.prefecture ?? '').isNotEmpty) event.prefecture!,
      if ((event.location ?? '').isNotEmpty) event.location!,
    ].join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openEvent(event),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.event_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if ((event.eventType ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Chip(
                          label: Text(event.eventType!),
                        ),
                      ),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(event.startsAt),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (venue.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        venue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: <Widget>[
                        Text(
                          'Going ${event.attendingCount}',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          'Attended ${event.attendedCount}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Timeline',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (_canCreateTimelinePost)
                FilledButton.icon(
                  onPressed: _openCreateTimelinePost,
                  icon: const Icon(Icons.add),
                  label: const Text('Post'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_timelinePosts.isEmpty)
            Text(
              _canCreateTimelinePost
                  ? 'Your timeline is empty. Create the first post.'
                  : 'No timeline posts yet.',
            )
          else
            ..._timelinePosts.map(
              (CommunityPostModel post) => _buildPostCard(
                context,
                post,
                showContextChip: false,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventsSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int finalizedAttendanceCount = _eventStats.attended + _eventStats.noShow;
    final int attendanceRatePercent = finalizedAttendanceCount == 0
        ? 0
        : ((_eventStats.attended / finalizedAttendanceCount) * 100).round();
    final int noShowRatePercent = finalizedAttendanceCount == 0
        ? 0
        : ((_eventStats.noShow / finalizedAttendanceCount) * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Events',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(label: Text('Attending ${_eventStats.attending}')),
              Chip(label: Text('Attended ${_eventStats.attended}')),
              Chip(label: Text('Cancelled ${_eventStats.cancelled}')),
              Chip(label: Text('No Show ${_eventStats.noShow}')),
              Chip(label: Text('Attendance Rate $attendanceRatePercent%')),
              Chip(label: Text('No-Show Rate $noShowRatePercent%')),
            ],
          ),
          const SizedBox(height: 12),
          if (_attendingEvents.isEmpty)
            const Text('No upcoming attending events.')
          else
            ..._attendingEvents.map(
              (EventModel event) => _buildEventCard(context, event),
            ),
        ],
      ),
    );
  }

  List<_PublicProfileActivityItem> get _activityItems {
    final List<_PublicProfileActivityItem> items = <_PublicProfileActivityItem>[
      ..._timelinePosts.map(
        (CommunityPostModel post) => _PublicProfileActivityItem(
          timestamp: post.createdAt,
          title: post.title,
          subtitle: post.excerpt.isEmpty
              ? 'Posted on profile timeline'
              : post.excerpt,
          icon: Icons.timeline,
          onTap: () => _openPost(post),
        ),
      ),
      ..._recentComments.map(
        (CommunityCommentModel comment) => _PublicProfileActivityItem(
          timestamp: comment.createdAt,
          title: 'Comment',
          subtitle: comment.message,
          icon: Icons.comment_outlined,
          onTap: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => CommunityPostDetailsScreen(postId: comment.postId),
              ),
            );
            await _load();
          },
        ),
      ),
    ];

    items.sort(
      (_PublicProfileActivityItem a, _PublicProfileActivityItem b) =>
          b.timestamp.compareTo(a.timestamp),
    );

    if (items.length <= 30) {
      return items;
    }

    return items.take(30).toList();
  }

  Widget _buildActivitySection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_PublicProfileActivityItem> items = _activityItems;
    final int totalPosts = _timelinePosts.length;
    final int totalComments = _recentComments.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Activity',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(label: Text('Received Likes $_receivedLikesCount')),
              Chip(label: Text('Posts $totalPosts')),
              Chip(label: Text('Comments $totalComments')),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('No recent activity yet.')
          else
            ...items.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: item.onTap,
                  leading: CircleAvatar(
                    child: Icon(item.icon),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(item.timestamp),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: _isSelf
            ? null
            : <Widget>[
                PopupMenuButton<String>(
                  onSelected: (String value) {
                    if (value == 'report') {
                      _reportUser();
                    } else if (value == 'mute') {
                      _muteUser();
                    } else if (value == 'block') {
                      _blockUser();
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'report',
                      child: Text(AppLocalizations.of(context).t('reportUser')),
                    ),
                    PopupMenuItem<String>(
                      value: 'mute',
                      child: Text(AppLocalizations.of(context).t('muteUser')),
                    ),
                    PopupMenuItem<String>(
                      value: 'block',
                      child: Text(AppLocalizations.of(context).t('blockUser')),
                    ),
                  ],
                ),
              ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Tab>[
            Tab(text: 'Timeline'),
            Tab(text: 'Activity'),
            Tab(text: 'Events'),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: <Widget>[
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              children: <Widget>[
                                _buildAvatar(84),
                                const SizedBox(height: 12),
                                Text(
                                  _displayName,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (_bio != null) ...<Widget>[
                                  const SizedBox(height: 10),
                                  Text(
                                    _bio!,
                                    style: theme.textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                const SizedBox(height: 14),
                                _buildRelationshipActions(theme),
                                if (!_canMessage && !_isSelf) ...<Widget>[
                                  const SizedBox(height: 10),
                                  Text(
                                    'Messaging unlocks once you are friends.',
                                    style: theme.textTheme.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: <Widget>[
                                    Chip(
                                      label: Text('Timeline ${_timelinePosts.length}'),
                                    ),
                                    Chip(label: Text('Likes $_receivedLikesCount')),
                                    Chip(
                                      label: Text('Events ${_attendingEvents.length}'),
                                    ),
                                    if (_areFriends) const Chip(label: Text('Friends')),
                                    if (_outgoingPending)
                                      const Chip(label: Text('Request Pending')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.82,
                            child: TabBarView(
                              controller: _tabController,
                              children: <Widget>[
                                SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: _buildTimelineSection(context),
                                ),
                                SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: _buildActivitySection(context),
                                ),
                                SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: _buildEventsSection(context),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PublicProfileActivityItem {
  const _PublicProfileActivityItem({
    required this.timestamp,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final DateTime timestamp;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}
