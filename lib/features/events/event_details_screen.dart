import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import 'event_create_screen.dart';
import 'event_model.dart';
import 'event_repository.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({super.key, required this.event});

  final EventModel event;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final EventRepository _repository = EventRepository();
  final TextEditingController _commentController = TextEditingController();

  late EventModel _event;
  List<EventAttendanceRecord> _attendees = <EventAttendanceRecord>[];
  List<EventCommentModel> _comments = <EventCommentModel>[];
  bool _isLoading = true;
  bool _isUpdatingAttendance = false;
  bool _isSendingComment = false;
  final Set<String> _busyAttendeeIds = <String>{};
  String? _replyToCommentId;
  String? _replyToCommentAuthor;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _load();
  }

  Future<void> _load() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() {
      _isLoading = true;
    });

    try {
      final EventModel event = await _repository.getEventById(widget.event.id);
      final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getEventAttendeesForHost(event.id),
        _repository.getEventComments(event.id),
      ]);
      final List<EventAttendanceRecord> attendees =
          results[0] as List<EventAttendanceRecord>;
      final List<EventCommentModel> comments =
          results[1] as List<EventCommentModel>;

      if (!mounted) {
        return;
      }

      setState(() {
        _event = event;
        _attendees = attendees;
        _comments = comments;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(l10n.t('failedLoadEvent', args: {'error': '$error'}))),
      );
    }
  }

  bool _isCurrentUserHost(EventModel event) {
    final User? user = Supabase.instance.client.auth.currentUser;
    return user != null && event.hostUserId == user.id;
  }

  bool _isCommentOwner(EventCommentModel comment) {
    final User? user = Supabase.instance.client.auth.currentUser;
    return user != null && user.id == comment.userId;
  }

  bool get _isLoggedIn => Supabase.instance.client.auth.currentUser != null;

  List<EventCommentModel> get _topLevelComments {
    return _comments
        .where(
          (EventCommentModel comment) =>
              comment.parentCommentId == null ||
              comment.parentCommentId!.trim().isEmpty,
        )
        .toList();
  }

  List<EventCommentModel> _childRepliesFor(String parentCommentId) {
    return _comments
        .where(
          (EventCommentModel comment) => comment.parentCommentId == parentCommentId,
        )
        .toList();
  }

  String _formatDateTime(DateTime value) {
    final String yyyy = value.year.toString().padLeft(4, '0');
    final String mm = value.month.toString().padLeft(2, '0');
    final String dd = value.day.toString().padLeft(2, '0');
    final String hh = value.hour.toString().padLeft(2, '0');
    final String min = value.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }

  Future<void> _attend() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_isUpdatingAttendance) {
      return;
    }

    setState(() {
      _isUpdatingAttendance = true;
    });

    try {
      await _repository.attendEvent(_event.id);
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('failedConfirmAttendance', args: {'error': '$error'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAttendance = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_isUpdatingAttendance) {
      return;
    }

    setState(() {
      _isUpdatingAttendance = true;
    });

    try {
      await _repository.cancelAttendance(_event.id);
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t('failedCancelAttendance', args: {'error': '$error'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAttendance = false;
        });
      }
    }
  }

  Future<void> _hostUpdateStatus({
    required String attendeeUserId,
    required String status,
  }) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_busyAttendeeIds.contains(attendeeUserId)) {
      return;
    }

    setState(() {
      _busyAttendeeIds.add(attendeeUserId);
    });

    try {
      await _repository.hostConfirmAttendance(
        eventId: _event.id,
        attendeeUserId: attendeeUserId,
        status: status,
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('failedUpdateAttendee', args: {'error': '$error'})),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyAttendeeIds.remove(attendeeUserId);
        });
      }
    }
  }

  Future<void> _editEvent() async {
    final bool? didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventCreateScreen(
          existingEvent: _event,
          isOfficial: _event.isOfficial,
        ),
      ),
    );

    if (didSave == true) {
      await _load();
    }
  }

  Future<void> _deleteEvent() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.t('deleteEventPromptTitle')),
          content: Text(l10n.t('deleteEventDetailsBody')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('delete')),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _repository.deleteEvent(_event.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(l10n.t('failedDeleteEvent', args: {'error': '$error'}))),
      );
    }
  }

  Future<void> _submitComment() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String body = _commentController.text.trim();
    if (body.isEmpty || _isSendingComment) {
      return;
    }

    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('mustBeLoggedInToComment'))),
      );
      return;
    }

    setState(() {
      _isSendingComment = true;
    });

    try {
      await _repository.addEventComment(
        eventId: _event.id,
        body: body,
        parentCommentId: _replyToCommentId,
      );
      _commentController.clear();
      _replyToCommentId = null;
      _replyToCommentAuthor = null;
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(l10n.t('failedPostComment', args: {'error': '$error'}))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingComment = false;
        });
      }
    }
  }

  void _setReplyTarget(EventCommentModel comment) {
    setState(() {
      _replyToCommentId = comment.id;
      _replyToCommentAuthor = comment.displayName;
    });
  }

  void _clearReplyTarget() {
    setState(() {
      _replyToCommentId = null;
      _replyToCommentAuthor = null;
    });
  }

  Future<void> _editComment(EventCommentModel comment) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextEditingController controller =
        TextEditingController(text: comment.body);

    try {
      final bool? shouldSave = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text(l10n.t('editComment')),
            content: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(labelText: l10n.t('comment')),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.t('save')),
              ),
            ],
          );
        },
      );

      if (shouldSave != true) {
        return;
      }

      await _repository.updateEventComment(
        commentId: comment.id,
        body: controller.text,
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(l10n.t('failedUpdateComment', args: {'error': '$error'}))),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteComment(EventCommentModel comment) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.t('deleteCommentTitle')),
          content: Text(l10n.t('deleteCommentBody')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('delete')),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _repository.softDeleteEventComment(comment.id);
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(l10n.t('failedDeleteComment', args: {'error': '$error'}))),
      );
    }
  }

  Widget _buildAttendanceActions() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? status = _event.currentUserAttendanceStatus;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.t('attendance'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _StatusChip(
                  icon: Icons.event_available,
                  label: l10n.t('goingWithCount', args: {'count': '${_event.attendingCount}'}),
                ),
                _StatusChip(
                  icon: Icons.verified,
                  label: l10n.t('attendedWithCount', args: {'count': '${_event.attendedCount}'}),
                ),
                _StatusChip(
                  icon: Icons.cancel_outlined,
                  label: l10n.t('cancelledWithCount', args: {'count': '${_event.cancelledCount}'}),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (status == 'attending') ...[
              Text(l10n.t('youAreAttendingEvent')),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isUpdatingAttendance ? null : _attend,
                      icon: const Icon(Icons.check_circle),
                      label: Text(l10n.t('attendanceAttending')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUpdatingAttendance ? null : _cancel,
                      icon: const Icon(Icons.cancel_outlined),
                      label: Text(l10n.t('cancel')),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'cancelled') ...[
              Text(l10n.t('youCancelledAttendance')),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isUpdatingAttendance ? null : _attend,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.t('attendInstead')),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'attended') ...[
              Text(l10n.t('hostConfirmedAttended')),
              const SizedBox(height: 10),
              _StatusChip(
                icon: Icons.verified,
                label: l10n.t('attendanceConfirmed'),
              ),
            ] else if (status == 'no_show') ...[
              Text(l10n.t('hostMarkedNoShow')),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUpdatingAttendance ? null : _attend,
                      icon: const Icon(Icons.replay),
                      label: Text(l10n.t('markAttendingAgain')),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(l10n.t('letHostKnowGoing')),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isUpdatingAttendance ? null : _attend,
                      icon: const Icon(Icons.event_available),
                      label: Text(l10n.t('attend')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHostSection() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!_isCurrentUserHost(_event)) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.t('hostControls'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('confirmAttendeesHelp'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_attendees.isEmpty)
              Text(l10n.t('noAttendeesYet'))
            else
              ..._attendees.map((EventAttendanceRecord attendee) {
                final bool isBusy = _busyAttendeeIds.contains(attendee.userId);
                final String displayName =
                    attendee.displayName?.trim().isNotEmpty == true
                    ? attendee.displayName!
                    : attendee.userId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 18,
                            backgroundImage:
                                attendee.avatarUrl != null &&
                                    attendee.avatarUrl!.trim().isNotEmpty
                                ? NetworkImage(attendee.avatarUrl!)
                                : null,
                            child:
                                attendee.avatarUrl == null ||
                                    attendee.avatarUrl!.trim().isEmpty
                                ? Text(
                                    _avatarInitial(displayName),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  displayName,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.t(
                                    'statusLabel',
                                    args: {'status': _readableStatus(attendee.status)},
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilledButton(
                            onPressed: isBusy
                                ? null
                                : () => _hostUpdateStatus(
                                    attendeeUserId: attendee.userId,
                                    status: 'attended',
                                  ),
                            child: Text(l10n.t('markAttended')),
                          ),
                          OutlinedButton(
                            onPressed: isBusy
                                ? null
                                : () => _hostUpdateStatus(
                                    attendeeUserId: attendee.userId,
                                    status: 'no_show',
                                  ),
                            child: Text(l10n.t('markNoShow')),
                          ),
                          OutlinedButton(
                            onPressed: isBusy
                                ? null
                                : () => _hostUpdateStatus(
                                    attendeeUserId: attendee.userId,
                                    status: 'attending',
                                  ),
                            child: Text(l10n.t('reset')),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendeesSection() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<EventAttendanceRecord> attending = _attendees
        .where((EventAttendanceRecord attendee) => attendee.status == 'attending')
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.t('attendees'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('peopleGoingCount', args: {'count': '${attending.length}'}),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (attending.isEmpty)
              Text(l10n.t('noAttendeesYet'))
            else
              ...attending.map((EventAttendanceRecord attendee) {
                final String displayName =
                    attendee.displayName?.trim().isNotEmpty == true
                    ? attendee.displayName!
                    : attendee.userId;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage:
                        attendee.avatarUrl != null &&
                            attendee.avatarUrl!.trim().isNotEmpty
                        ? NetworkImage(attendee.avatarUrl!)
                        : null,
                    child:
                        attendee.avatarUrl == null ||
                            attendee.avatarUrl!.trim().isEmpty
                        ? Text(_avatarInitial(displayName))
                        : null,
                  ),
                  title: Text(displayName),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentCard(EventCommentModel comment, {bool isReply = false}) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isOwner = _isCommentOwner(comment);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 16,
                backgroundImage:
                    (comment.avatarUrl ?? '').trim().isNotEmpty
                    ? NetworkImage(comment.avatarUrl!)
                    : null,
                child: (comment.avatarUrl ?? '').trim().isEmpty
                    ? Text(_avatarInitial(comment.displayName))
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      comment.displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _formatDateTime(comment.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (comment.updatedAt != null &&
                        comment.updatedAt!.isAfter(comment.createdAt))
                      Text(
                        l10n.t('edited'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (isOwner)
                PopupMenuButton<String>(
                  onSelected: (String value) {
                    if (value == 'edit') {
                      _editComment(comment);
                    } else if (value == 'delete') {
                      _deleteComment(comment);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text(l10n.t('edit')),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text(l10n.t('delete')),
                        ),
                      ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.body),
          if (!isReply)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _setReplyTarget(comment),
                icon: const Icon(Icons.reply_outlined),
                label: Text(l10n.t('reply')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<EventCommentModel> topLevel = _topLevelComments;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.t('commentsWithCount', args: {'count': '${_comments.length}'}),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (topLevel.isEmpty)
              Text(l10n.t('noCommentsYet'))
            else
              ...topLevel.map((EventCommentModel comment) {
                final List<EventCommentModel> replies = _childRepliesFor(comment.id);
                return Column(
                  children: <Widget>[
                    _buildCommentCard(comment),
                    ...replies.map(
                      (EventCommentModel reply) => Padding(
                        padding: const EdgeInsets.only(left: 18),
                        child: _buildCommentCard(reply, isReply: true),
                      ),
                    ),
                  ],
                );
              }),
            const SizedBox(height: 8),
            if (!_isLoggedIn)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.t('logInToJoinConversation'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_replyToCommentId != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.t(
                          'replyingTo',
                          args: {'name': _replyToCommentAuthor ?? l10n.t('comment')},
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: _clearReplyTarget,
                      icon: const Icon(Icons.close),
                      tooltip: l10n.t('cancelReply'),
                    ),
                  ],
                ),
              ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    enabled: _isLoggedIn && !_isSendingComment,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l10n.t('writeComment'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (!_isLoggedIn || _isSendingComment)
                    ? null
                    : _submitComment,
                  child: _isSendingComment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.t('send')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _readableStatus(String status) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    switch (status) {
      case 'attending':
        return l10n.t('attendanceAttending');
      case 'cancelled':
        return l10n.t('attendanceCancelled');
      case 'attended':
        return l10n.t('attendanceAttended');
      case 'no_show':
        return l10n.t('attendanceNoShow');
      default:
        return status;
    }
  }

  String _avatarInitial(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed.substring(0, 1).toUpperCase();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<String> subtitleParts = <String>[
      if ((_event.prefecture ?? '').isNotEmpty) _event.prefecture!,
      if ((_event.location ?? '').isNotEmpty) _event.location!,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_event.title),
        actions: _isCurrentUserHost(_event)
            ? <Widget>[
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editEvent();
                    } else if (value == 'delete') {
                      _deleteEvent();
                    }
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text(l10n.t('editEvent')),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(l10n.t('deleteEventAction')),
                    ),
                  ],
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (subtitleParts.isNotEmpty)
                              Text(
                                subtitleParts.join(' • '),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            if (subtitleParts.isNotEmpty)
                              const SizedBox(height: 12),
                            Text(_event.description),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAttendanceActions(),
                    const SizedBox(height: 12),
                    _buildAttendeesSection(),
                    const SizedBox(height: 12),
                    _DetailTile(
                      icon: Icons.schedule,
                      title: l10n.t('start'),
                      value: _formatDateTime(_event.startsAt),
                    ),
                    _DetailTile(
                      icon: Icons.flag,
                      title: l10n.t('end'),
                      value: _formatDateTime(_event.endsAt),
                    ),
                    if ((_event.eventType ?? '').isNotEmpty)
                      _DetailTile(
                        icon: Icons.category,
                        title: l10n.t('type'),
                        value: _event.eventType!,
                      ),
                    if ((_event.language ?? '').isNotEmpty)
                      _DetailTile(
                        icon: Icons.translate,
                        title: l10n.language,
                        value: _event.language!,
                      ),
                    if ((_event.skillLevel ?? '').isNotEmpty)
                      _DetailTile(
                        icon: Icons.military_tech,
                        title: l10n.t('skillLevel'),
                        value: _event.skillLevel!,
                      ),
                    if ((_event.location ?? '').isNotEmpty)
                      _DetailTile(
                        icon: Icons.place,
                        title: l10n.location,
                        value: _event.location!,
                      ),
                    if ((_event.prefecture ?? '').isNotEmpty)
                      _DetailTile(
                        icon: Icons.map,
                        title: l10n.t('prefecture'),
                        value: _event.prefecture!,
                      ),
                    if (_event.priceYen != null)
                      _DetailTile(
                        icon: Icons.payments,
                        title: l10n.t('price'),
                        value: '¥${_event.priceYen}',
                      ),
                    if (_event.maxPlayers != null)
                      _DetailTile(
                        icon: Icons.groups,
                        title: l10n.t('maxPlayers'),
                        value: '${_event.maxPlayers}',
                      ),
                    if ((_event.organizerName ?? '').isNotEmpty)
                      _DetailTile(
                        icon: Icons.badge,
                        title: l10n.t('organizer'),
                        value: _event.organizerName!,
                      ),
                    if ((_event.contactInfo ?? '').isNotEmpty)
                      _DetailTile(
                        icon: Icons.contact_mail,
                        title: l10n.t('contact'),
                        value: _event.contactInfo!,
                      ),
                    if ((_event.notes ?? '').isNotEmpty)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.rule),
                          title: Text(l10n.t('rules')),
                          subtitle: Text(_event.notes!),
                        ),
                      ),
                    if (_isCurrentUserHost(_event)) ...<Widget>[
                      const SizedBox(height: 12),
                      _buildHostSection(),
                    ],
                    const SizedBox(height: 12),
                    _buildCommentsSection(),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(label),
        ],
      ),
    );
  }
}
