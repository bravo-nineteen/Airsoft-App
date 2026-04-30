import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/widgets/user_avatar.dart';
import '../safety/safety_repository.dart';
import 'event_create_screen.dart';
import 'event_model.dart';
import 'event_repository.dart';

enum _CommentSortMode { mostRecent, allComments, popularComments }

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({super.key, required this.event});

  final EventModel event;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final EventRepository _repository = EventRepository();
  final SafetyRepository _safetyRepository = SafetyRepository();
  final TextEditingController _commentController = TextEditingController();

  late EventModel _event;
  List<EventAttendanceRecord> _attendees = <EventAttendanceRecord>[];
  List<EventCommentModel> _comments = <EventCommentModel>[];
  bool _isLoading = true;
  bool _isUpdatingAttendance = false;
  bool _isUpdatingWaitlist = false;
  bool _isSendingComment = false;
  _CommentSortMode _commentSortMode = _CommentSortMode.mostRecent;
  final Set<String> _busyAttendeeIds = <String>{};
  int _waitlistCount = 0;
  bool _isCurrentUserWaitlisted = false;
  List<EventCheckinRecord> _checkins = <EventCheckinRecord>[];
  String? _calendarExportProvider;
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
        _repository.getEventWaitlistCount(event.id),
        _repository.isCurrentUserWaitlisted(event.id),
        _repository.getEventCheckins(event.id),
        _repository.getCurrentUserCalendarExportProvider(),
      ]);
      final List<EventAttendanceRecord> attendees =
          results[0] as List<EventAttendanceRecord>;
      final List<EventCommentModel> comments =
          results[1] as List<EventCommentModel>;
      final int waitlistCount = results[2] as int;
      final bool isCurrentUserWaitlisted = results[3] as bool;
      final List<EventCheckinRecord> checkins =
          results[4] as List<EventCheckinRecord>;
      final String? calendarExportProvider = results[5] as String?;

      if (!mounted) {
        return;
      }

      setState(() {
        _event = event;
        _attendees = attendees;
        _comments = comments;
        _waitlistCount = waitlistCount;
        _isCurrentUserWaitlisted = isCurrentUserWaitlisted;
        _checkins = checkins;
        _calendarExportProvider = calendarExportProvider;
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

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _reportTarget({
    required String targetType,
    required String targetId,
  }) async {
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
              title: Text(l10n.t('reportContent')),
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
        targetType: targetType,
        targetId: targetId,
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

  Future<void> _blockUser(String userId) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('mustBeLoggedInToReport'))),
      );
      return;
    }
    try {
      await _safetyRepository.blockUser(userId);
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('userBlocked'))),
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

  Future<void> _muteUser(String userId) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('mustBeLoggedInToReport'))),
      );
      return;
    }
    try {
      await _safetyRepository.muteUser(userId);
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

  void _muteUserIfPresent(String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return;
    }
    _muteUser(userId);
  }

  void _blockUserIfPresent(String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return;
    }
    _blockUser(userId);
  }

  List<EventCommentModel> get _topLevelComments {
    return _comments
        .where(
          (EventCommentModel comment) =>
              comment.parentCommentId == null ||
              comment.parentCommentId!.trim().isEmpty,
        )
        .toList();
  }

  List<EventCommentModel> get _sortedTopLevelComments {
    final List<EventCommentModel> comments = _topLevelComments.toList();
    final Map<String, List<EventCommentModel>> descendantsById =
        <String, List<EventCommentModel>>{
          for (final EventCommentModel comment in comments)
            comment.id: _descendantsFor(comment.id),
        };

    comments.sort((EventCommentModel left, EventCommentModel right) {
      final List<EventCommentModel> leftDescendants =
          descendantsById[left.id] ?? <EventCommentModel>[];
      final List<EventCommentModel> rightDescendants =
          descendantsById[right.id] ?? <EventCommentModel>[];

      switch (_commentSortMode) {
        case _CommentSortMode.mostRecent:
          return _threadLatestActivity(right, rightDescendants).compareTo(
            _threadLatestActivity(left, leftDescendants),
          );
        case _CommentSortMode.allComments:
          return left.createdAt.compareTo(right.createdAt);
        case _CommentSortMode.popularComments:
          final int popularityDelta =
              _threadPopularity(rightDescendants) -
              _threadPopularity(leftDescendants);
          if (popularityDelta != 0) {
            return popularityDelta;
          }
          return _threadLatestActivity(right, rightDescendants).compareTo(
            _threadLatestActivity(left, leftDescendants),
          );
      }
    });

    return comments;
  }

  List<EventCommentModel> _childRepliesFor(String parentCommentId) {
    return _comments
        .where(
          (EventCommentModel comment) => comment.parentCommentId == parentCommentId,
        )
        .toList();
  }

  List<EventCommentModel> _sortedRepliesFor(String parentCommentId) {
    final List<EventCommentModel> replies =
        _childRepliesFor(parentCommentId).toList();
    replies.sort(
      (EventCommentModel left, EventCommentModel right) =>
          left.createdAt.compareTo(right.createdAt),
    );
    return replies;
  }

  List<EventCommentModel> _descendantsFor(String rootCommentId) {
    final List<EventCommentModel> descendants = <EventCommentModel>[];
    final List<String> pendingIds = <String>[rootCommentId];

    while (pendingIds.isNotEmpty) {
      final String parentId = pendingIds.removeLast();
      final List<EventCommentModel> directReplies = _sortedRepliesFor(parentId);
      descendants.addAll(directReplies);
      pendingIds.addAll(directReplies.map((EventCommentModel reply) => reply.id));
    }

    return descendants;
  }

  EventCommentModel? _commentById(String commentId) {
    for (final EventCommentModel comment in _comments) {
      if (comment.id == commentId) {
        return comment;
      }
    }
    return null;
  }

  String? _parentAuthorNameFor(EventCommentModel comment) {
    final String? parentCommentId = comment.parentCommentId?.trim();
    if (parentCommentId == null || parentCommentId.isEmpty) {
      return null;
    }

    return _commentById(parentCommentId)?.displayName;
  }

  DateTime _threadLatestActivity(
    EventCommentModel rootComment,
    List<EventCommentModel> descendants,
  ) {
    DateTime latest = rootComment.createdAt;
    for (final EventCommentModel reply in descendants) {
      if (reply.createdAt.isAfter(latest)) {
        latest = reply.createdAt;
      }
    }
    return latest;
  }

  int _threadPopularity(List<EventCommentModel> descendants) {
    return descendants.length;
  }

  void _setCommentSortMode(_CommentSortMode mode) {
    if (_commentSortMode == mode) {
      return;
    }

    setState(() {
      _commentSortMode = mode;
    });
  }

  String _commentSortLabel(_CommentSortMode mode, AppLocalizations l10n) {
    switch (mode) {
      case _CommentSortMode.mostRecent:
        return l10n.t('mostRecentComments');
      case _CommentSortMode.allComments:
        return l10n.t('allComments');
      case _CommentSortMode.popularComments:
        return l10n.t('popularComments');
    }
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

  Future<void> _joinWaitlist() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_isUpdatingWaitlist) {
      return;
    }

    setState(() {
      _isUpdatingWaitlist = true;
    });

    try {
      await _repository.joinEventWaitlist(_event.id);
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('actionFailed', args: {'error': '$error'}))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingWaitlist = false;
        });
      }
    }
  }

  Future<void> _leaveWaitlist() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_isUpdatingWaitlist) {
      return;
    }

    setState(() {
      _isUpdatingWaitlist = true;
    });

    try {
      await _repository.leaveEventWaitlist(_event.id);
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('actionFailed', args: {'error': '$error'}))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingWaitlist = false;
        });
      }
    }
  }

  Future<void> _hostCheckIn({
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
      await _repository.hostRecordEventCheckin(
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
        SnackBar(content: Text(l10n.t('actionFailed', args: {'error': '$error'}))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyAttendeeIds.remove(attendeeUserId);
        });
      }
    }
  }

  Future<void> _pickCalendarExportProvider() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!_isLoggedIn) {
      return;
    }

    final String? selected = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Google Calendar'),
                onTap: () => Navigator.of(sheetContext).pop('google'),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Apple Calendar'),
                onTap: () => Navigator.of(sheetContext).pop('apple'),
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('ICS Export'),
                onTap: () => Navigator.of(sheetContext).pop('ics'),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    try {
      await _repository.setCurrentUserCalendarExportProvider(selected);
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('actionFailed', args: {'error': '$error'}))),
      );
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
    final bool isFull =
        _event.maxPlayers != null && _event.attendingCount >= _event.maxPlayers!;

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
                _StatusChip(
                  icon: Icons.hourglass_bottom,
                  label: 'Waitlist: $_waitlistCount',
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
              Text(
                isFull
                    ? 'Event is currently full. You can join the waitlist.'
                    : l10n.t('letHostKnowGoing'),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: isFull
                        ? FilledButton.icon(
                            onPressed: (_isUpdatingWaitlist || _isCurrentUserWaitlisted)
                                ? null
                                : _joinWaitlist,
                            icon: const Icon(Icons.schedule_send_outlined),
                            label: Text(
                              _isCurrentUserWaitlisted
                                  ? 'Waitlisted'
                                  : 'Join Waitlist',
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: _isUpdatingAttendance ? null : _attend,
                            icon: const Icon(Icons.event_available),
                            label: Text(l10n.t('attend')),
                          ),
                  ),
                  if (isFull && _isCurrentUserWaitlisted) ...<Widget>[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUpdatingWaitlist ? null : _leaveWaitlist,
                        icon: const Icon(Icons.close),
                        label: const Text('Leave Waitlist'),
                      ),
                    ),
                  ],
                ],
              ),
              if (isFull && _isCurrentUserWaitlisted) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'You will be auto-promoted when a slot opens.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
            if (_isUpdatingWaitlist) ...<Widget>[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCheckinSummary() {
    final int attendedCount = _checkins.where((EventCheckinRecord c) => c.attended).length;
    final int noShowCount = _checkins.where((EventCheckinRecord c) => c.noShow).length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _StatusChip(
          icon: Icons.how_to_reg,
          label: 'Check-ins: ${_checkins.length}',
        ),
        _StatusChip(
          icon: Icons.verified,
          label: 'Attended: $attendedCount',
        ),
        _StatusChip(
          icon: Icons.person_off_outlined,
          label: 'No-show: $noShowCount',
        ),
      ],
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
            _buildCheckinSummary(),
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
                          UserAvatar(
                            userId: attendee.userId,
                            avatarUrl: attendee.avatarUrl,
                            radius: 18,
                            initials: displayName,
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
                          FilledButton.tonalIcon(
                            onPressed: isBusy
                                ? null
                                : () => _hostCheckIn(
                                    attendeeUserId: attendee.userId,
                                    status: 'attended',
                                  ),
                            icon: const Icon(Icons.how_to_reg),
                            label: const Text('Check-in'),
                          ),
                          OutlinedButton.icon(
                            onPressed: isBusy
                                ? null
                                : () => _hostCheckIn(
                                    attendeeUserId: attendee.userId,
                                    status: 'no_show',
                                  ),
                            icon: const Icon(Icons.person_off_outlined),
                            label: const Text('No-show'),
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
                  leading: UserAvatar(
                    userId: attendee.userId,
                    avatarUrl: attendee.avatarUrl,
                    initials: displayName,
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
    final ThemeData theme = Theme.of(context);
    final String? parentAuthorName =
        isReply ? _parentAuthorNameFor(comment) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReply
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isReply
            ? Border(
                left: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.35),
                  width: 3,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (parentAuthorName != null) ...<Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 16,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.t('inReplyTo', args: {'name': parentAuthorName}),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: <Widget>[
              UserAvatar(
                userId: comment.userId,
                avatarUrl: comment.avatarUrl,
                radius: 16,
                initials: comment.displayName,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      comment.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _formatDateTime(comment.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (comment.updatedAt != null &&
                        comment.updatedAt!.isAfter(comment.createdAt))
                      Text(
                        l10n.t('edited'),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (String value) {
                  if (value == 'edit') {
                    _editComment(comment);
                  } else if (value == 'delete') {
                    _deleteComment(comment);
                  } else if (value == 'report') {
                    _reportTarget(targetType: 'comment', targetId: comment.id);
                  } else if (value == 'mute') {
                    _muteUser(comment.userId);
                  } else if (value == 'block') {
                    _blockUser(comment.userId);
                  }
                },
                itemBuilder: (BuildContext context) {
                  final List<PopupMenuEntry<String>> items = <PopupMenuEntry<String>>[];
                  if (isOwner) {
                    items.add(
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text(l10n.t('edit')),
                      ),
                    );
                    items.add(
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text(l10n.t('delete')),
                      ),
                    );
                  }
                  if (!isOwner) {
                    items.add(
                      PopupMenuItem<String>(
                        value: 'report',
                        child: Text(l10n.t('report')),
                      ),
                    );
                    items.add(
                      PopupMenuItem<String>(
                        value: 'mute',
                        child: Text(l10n.t('muteUser')),
                      ),
                    );
                    items.add(
                      PopupMenuItem<String>(
                        value: 'block',
                        child: Text(l10n.t('blockUser')),
                      ),
                    );
                  }
                  return items;
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.body),
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

  Widget _buildCommentThread(EventCommentModel comment, {int depth = 0}) {
    final List<EventCommentModel> replies = _sortedRepliesFor(comment.id);
    final double leftInset = depth <= 0
        ? 0
        : depth >= 3
            ? 42
            : depth * 14;

    return Padding(
      padding: EdgeInsets.only(left: leftInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildCommentCard(comment, isReply: depth > 0),
          ...replies.map(
            (EventCommentModel reply) => _buildCommentThread(
              reply,
              depth: depth + 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSortChips(AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _CommentSortMode.values.map((_CommentSortMode mode) {
        return ChoiceChip(
          label: Text(_commentSortLabel(mode, l10n)),
          selected: _commentSortMode == mode,
          onSelected: (_) => _setCommentSortMode(mode),
        );
      }).toList(),
    );
  }

  Widget _buildCommentsSection() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<EventCommentModel> topLevel = _sortedTopLevelComments;

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
            _buildCommentSortChips(l10n),
            const SizedBox(height: 10),
            if (topLevel.isEmpty)
              Text(l10n.t('noCommentsYet'))
            else
              ...topLevel.map((EventCommentModel comment) {
                return _buildCommentThread(comment);
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

  Widget _buildCalendarSyncCard() {
    final String currentProvider = (_calendarExportProvider ?? 'none').trim();
    final String providerLabel = switch (currentProvider) {
      'google' => 'Google Calendar',
      'apple' => 'Apple Calendar',
      'ics' => 'ICS Export',
      _ => 'Not configured',
    };

    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_month_outlined),
        title: const Text('Calendar sync'),
        subtitle: Text(providerLabel),
        trailing: const Icon(Icons.chevron_right),
        onTap: _isLoggedIn ? _pickCalendarExportProvider : null,
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
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'edit') {
                _editEvent();
              } else if (value == 'delete') {
                _deleteEvent();
              } else if (value == 'report') {
                _reportTarget(targetType: 'event', targetId: _event.id);
              } else if (value == 'mute') {
                _muteUserIfPresent(_event.hostUserId);
              } else if (value == 'block') {
                _blockUserIfPresent(_event.hostUserId);
              }
            },
            itemBuilder: (BuildContext context) {
              final bool isHost = _isCurrentUserHost(_event);
              final bool isSelf = _event.hostUserId == _currentUserId;
              final List<PopupMenuEntry<String>> items = <PopupMenuEntry<String>>[];
              if (isHost) {
                items.add(
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Text(l10n.t('editEvent')),
                  ),
                );
                items.add(
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(l10n.t('deleteEventAction')),
                  ),
                );
              }
              if (!isSelf) {
                items.add(
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Text(l10n.t('report')),
                  ),
                );
                items.add(
                  PopupMenuItem<String>(
                    value: 'mute',
                    child: Text(l10n.t('muteUser')),
                  ),
                );
                items.add(
                  PopupMenuItem<String>(
                    value: 'block',
                    child: Text(l10n.t('blockUser')),
                  ),
                );
              }
              return items;
            },
          ),
        ],
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
                    _buildCalendarSyncCard(),
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
