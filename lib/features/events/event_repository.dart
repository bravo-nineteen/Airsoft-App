import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/notifications/event_reminder_service.dart';
import '../community/community_image_service.dart';
import '../safety/safety_repository.dart';
import 'event_model.dart';
import '../notifications/notification_writer.dart';

class EventRepository {
  EventRepository({SupabaseClient? client})
    : _client = client,
      _notificationWriter = NotificationWriter(client: client),
      _imageService = CommunityImageService(client: client),
      _safetyRepository = SafetyRepository(client: client);

  final SupabaseClient? _client;
  final NotificationWriter _notificationWriter;
  final CommunityImageService _imageService;
  final SafetyRepository _safetyRepository;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  User? get currentUser => _resolvedClient.auth.currentUser;

  Future<List<EventModel>> getEvents() async {
    dynamic query = _resolvedClient.from('events').select();
    dynamic response;
    try {
      response = await query
          .order('pinned_until', ascending: false)
          .order('starts_at', ascending: true);
    } on PostgrestException catch (error) {
      if (!_isMissingColumnError(error, 'pinned_until')) {
        rethrow;
      }
      response = await query.order('starts_at', ascending: true);
    }

    final List<EventModel> baseEvents = (response as List<dynamic>)
        .map(
          (dynamic e) =>
              EventModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return Future.wait<EventModel>(
      baseEvents.map((EventModel event) => _enrichEvent(event)),
    );
  }

  Future<EventModel> getEventById(String eventId) async {
    final response = await _resolvedClient
        .from('events')
        .select()
        .eq('id', eventId)
        .single();

    final EventModel event = EventModel.fromJson(
      Map<String, dynamic>.from(response),
    );
    return _enrichEvent(event);
  }

  Future<void> createEvent({
    required String title,
    required String description,
    required DateTime startsAt,
    required DateTime endsAt,
    bool isOfficial = false,
    String? country,
    String? location,
    String? prefecture,
    String? eventType,
    String? language,
    String? skillLevel,
    String? organizerName,
    String? contactInfo,
    String? notes,
    int? priceYen,
    int? maxPlayers,
    String? imageUrl,
    String? bookTicketsUrl,
  }) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in to create events.');
    }

    final String trimmedTitle = title.trim();
    final String trimmedDescription = description.trim();

    if (trimmedTitle.isEmpty) {
      throw Exception('Title is required.');
    }

    if (trimmedDescription.isEmpty) {
      throw Exception('Description is required.');
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'title': trimmedTitle,
      'description': trimmedDescription,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'country': _nullIfEmpty(country),
      'location': _nullIfEmpty(location),
      'prefecture': _nullIfEmpty(prefecture),
      'event_type': _nullIfEmpty(eventType),
      'language': _nullIfEmpty(_normalizeEventLanguage(language)),
      'skill_level': _nullIfEmpty(skillLevel),
      'organizer_name': _nullIfEmpty(organizerName),
      'contact_info': _nullIfEmpty(contactInfo),
      'notes': _nullIfEmpty(notes),
      'price_yen': priceYen,
      'max_players': maxPlayers,
      'image_url': _nullIfEmpty(imageUrl),
      'book_tickets_url': _nullIfEmpty(bookTicketsUrl),
      'host_user_id': user.id,
      'is_official': isOfficial,
    };

    try {
      await _resolvedClient.from('events').insert(payload);
    } on PostgrestException catch (error) {
      if (!_isMissingColumnError(error, 'is_official')) {
        rethrow;
      }
      payload.remove('is_official');
      await _resolvedClient.from('events').insert(payload);
    }
  }

  Future<void> updateEvent({
    required String eventId,
    required String title,
    required String description,
    required DateTime startsAt,
    required DateTime endsAt,
    bool isOfficial = false,
    String? country,
    String? location,
    String? prefecture,
    String? eventType,
    String? language,
    String? skillLevel,
    String? organizerName,
    String? contactInfo,
    String? notes,
    int? priceYen,
    int? maxPlayers,
    String? imageUrl,
    String? bookTicketsUrl,
  }) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in to edit events.');
    }

    final String trimmedTitle = title.trim();
    final String trimmedDescription = description.trim();

    if (trimmedTitle.isEmpty) {
      throw Exception('Title is required.');
    }

    if (trimmedDescription.isEmpty) {
      throw Exception('Description is required.');
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'title': trimmedTitle,
      'description': trimmedDescription,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'country': _nullIfEmpty(country),
      'location': _nullIfEmpty(location),
      'prefecture': _nullIfEmpty(prefecture),
      'event_type': _nullIfEmpty(eventType),
      'language': _nullIfEmpty(_normalizeEventLanguage(language)),
      'skill_level': _nullIfEmpty(skillLevel),
      'organizer_name': _nullIfEmpty(organizerName),
      'contact_info': _nullIfEmpty(contactInfo),
      'notes': _nullIfEmpty(notes),
      'price_yen': priceYen,
      'max_players': maxPlayers,
      'image_url': _nullIfEmpty(imageUrl),
      'book_tickets_url': _nullIfEmpty(bookTicketsUrl),
      'is_official': isOfficial,
    };

    try {
      await _resolvedClient
          .from('events')
          .update(payload)
          .eq('id', eventId)
          .eq('host_user_id', user.id);
    } on PostgrestException catch (error) {
      if (!_isMissingColumnError(error, 'is_official')) {
        rethrow;
      }
      payload.remove('is_official');
      await _resolvedClient
          .from('events')
          .update(payload)
          .eq('id', eventId)
          .eq('host_user_id', user.id);
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in.');
    }

    final Map<String, dynamic>? existing = await _resolvedClient
        .from('events')
        .select('image_url')
        .eq('id', eventId)
        .eq('host_user_id', user.id)
        .maybeSingle();
    final String? imageUrl = _nullIfEmpty(existing?['image_url']?.toString());

    await _resolvedClient
      .from('events')
      .delete()
      .eq('id', eventId)
      .eq('host_user_id', user.id);

    await _imageService.deleteUploadedImageByPublicUrl(imageUrl);
  }

  Future<void> markInterested(String eventId) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in to set interest.');
    }

    final Map<String, dynamic>? existing = await _resolvedClient
        .from('event_attendees')
        .select('id')
        .eq('event_id', eventId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing == null) {
      await _resolvedClient.from('event_attendees').insert({
        'event_id': eventId,
        'user_id': user.id,
        'status': 'interested',
      });
      return;
    }

    try {
      await _resolvedClient
          .from('event_attendees')
          .update({'status': 'interested'})
          .eq('event_id', eventId)
          .eq('user_id', user.id);
    } on PostgrestException catch (error) {
      if (!_isMissingUpdatedAtTriggerError(error)) {
        rethrow;
      }

      await _resolvedClient
          .from('event_attendees')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', user.id);
      await _resolvedClient.from('event_attendees').insert({
        'event_id': eventId,
        'user_id': user.id,
        'status': 'interested',
      });
    }
  }

  Future<void> attendEvent(String eventId) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in to attend events.');
    }

    final Map<String, dynamic>? eventRecord = await _resolvedClient
        .from('events')
        .select('id, title, host_user_id')
        .eq('id', eventId)
        .maybeSingle();

    final Map<String, dynamic>? existing = await _resolvedClient
        .from('event_attendees')
        .select('id')
        .eq('event_id', eventId)
        .eq('user_id', user.id)
        .maybeSingle();

    final Map<String, dynamic> payload = <String, dynamic>{
      'event_id': eventId,
      'user_id': user.id,
      'status': 'attending',
    };

    if (existing == null) {
      await _resolvedClient.from('event_attendees').insert(payload);
    } else {
      try {
        await _resolvedClient
          .from('event_attendees')
          .update({'status': 'attending'})
          .eq('event_id', eventId)
          .eq('user_id', user.id);
      } on PostgrestException catch (error) {
        if (!_isMissingUpdatedAtTriggerError(error)) {
          rethrow;
        }

        await _resolvedClient
            .from('event_attendees')
            .delete()
            .eq('event_id', eventId)
            .eq('user_id', user.id);
        await _resolvedClient.from('event_attendees').insert(payload);
      }
    }

    final String actorName = await _notificationWriter.getCurrentActorName();
    await _notificationWriter.safeCreateNotification(
      userId: eventRecord?['host_user_id']?.toString() ?? '',
      type: 'event_attendance_update',
      entityId: eventId,
      title: actorName,
      body: 'is attending ${eventRecord?['title'] ?? 'your event'}.',
    );

    // Schedule local reminders for this event.
    try {
      final EventModel event = await getEventById(eventId);
      await EventReminderService.instance.scheduleReminders(event);
    } catch (_) {
      // Best-effort — never break RSVP because of reminder scheduling.
    }
  }

  Future<void> cancelAttendance(String eventId) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in to cancel attendance.');
    }

    final Map<String, dynamic>? eventRecord = await _resolvedClient
        .from('events')
        .select('id, title, host_user_id')
        .eq('id', eventId)
        .maybeSingle();

    final Map<String, dynamic>? existing = await _resolvedClient
        .from('event_attendees')
        .select('id')
        .eq('event_id', eventId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing == null) {
      await _resolvedClient.from('event_attendees').insert({
        'event_id': eventId,
        'user_id': user.id,
        'status': 'cancelled',
      });
    } else {
      try {
        await _resolvedClient
            .from('event_attendees')
            .update({'status': 'cancelled'})
            .eq('event_id', eventId)
            .eq('user_id', user.id);
      } on PostgrestException catch (error) {
        if (!_isMissingUpdatedAtTriggerError(error)) {
          rethrow;
        }

        await _resolvedClient
            .from('event_attendees')
            .delete()
            .eq('event_id', eventId)
            .eq('user_id', user.id);
        await _resolvedClient.from('event_attendees').insert({
          'event_id': eventId,
          'user_id': user.id,
          'status': 'cancelled',
        });
      }
    }

    final String actorName = await _notificationWriter.getCurrentActorName();
    await _notificationWriter.safeCreateNotification(
      userId: eventRecord?['host_user_id']?.toString() ?? '',
      type: 'event_attendance_update',
      entityId: eventId,
      title: actorName,
      body: 'cancelled attendance for ${eventRecord?['title'] ?? 'your event'}.',
    );

    // Cancel any scheduled local reminders.
    await EventReminderService.instance.cancelReminders(eventId);
  }

  Future<void> hostConfirmAttendance({
    required String eventId,
    required String attendeeUserId,
    required String status,
  }) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in.');
    }

    if (status != 'attended' && status != 'no_show' && status != 'attending') {
      throw Exception('Invalid attendance status.');
    }

    final EventModel event = await getEventById(eventId);
    if (event.hostUserId != user.id) {
      throw Exception('Only the host can confirm attendance.');
    }

    final bool hostConfirmed = status == 'attended' || status == 'no_show';
    final String nowIso = DateTime.now().toUtc().toIso8601String();
    final Map<String, dynamic> payload = <String, dynamic>{
      'status': status,
      'confirmed_by_host': hostConfirmed,
      'confirmed_at': hostConfirmed ? nowIso : null,
      'updated_at': nowIso,
    };

    try {
        await _resolvedClient
          .from('event_attendees')
          .update(payload)
          .eq('event_id', eventId)
          .eq('user_id', attendeeUserId);
    } on PostgrestException catch (error) {
      if (_isMissingUpdatedAtTriggerError(error)) {
        payload.remove('updated_at');
      } else if (!_isMissingConfirmedAtColumnError(error)) {
        rethrow;
      } else {
        payload.remove('confirmed_at');
      }

        await _resolvedClient
          .from('event_attendees')
          .update(payload)
          .eq('event_id', eventId)
          .eq('user_id', attendeeUserId);
    }

    final String actorName = await _notificationWriter.getCurrentActorName();
    final String body;
    switch (status) {
      case 'attended':
        body = 'confirmed your attendance for ${event.title}.';
        break;
      case 'no_show':
        body = 'marked you as no-show for ${event.title}.';
        break;
      default:
        body = 'updated your attendance for ${event.title}.';
        break;
    }
    await _notificationWriter.safeCreateNotification(
      userId: attendeeUserId,
      type: 'event_attendance_update',
      entityId: eventId,
      title: actorName,
      body: body,
    );
  }

  Future<int> getEventWaitlistCount(String eventId) async {
    try {
      final List<dynamic> response = await _resolvedClient
          .from('event_waitlist')
          .select('id')
          .eq('event_id', eventId)
          .eq('status', 'queued');
      return response.length;
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'event_waitlist')) {
        return 0;
      }
      rethrow;
    }
  }

  Future<bool> isCurrentUserWaitlisted(String eventId) async {
    final User? user = currentUser;
    if (user == null) {
      return false;
    }

    try {
      final Map<String, dynamic>? response = await _resolvedClient
          .from('event_waitlist')
          .select('id')
          .eq('event_id', eventId)
          .eq('user_id', user.id)
          .eq('status', 'queued')
          .maybeSingle();
      return response != null;
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'event_waitlist')) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> joinEventWaitlist(String eventId) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in to join waitlist.');
    }

    try {
      await _resolvedClient.from('event_waitlist').upsert(
        <String, dynamic>{
          'event_id': eventId,
          'user_id': user.id,
          'status': 'queued',
          'queued_at': DateTime.now().toUtc().toIso8601String(),
          'promoted_at': null,
        },
        onConflict: 'event_id,user_id',
      );
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'event_waitlist')) {
        throw Exception('Waitlist is not available yet.');
      }
      rethrow;
    }
  }

  Future<void> leaveEventWaitlist(String eventId) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in to update waitlist.');
    }

    try {
      await _resolvedClient
          .from('event_waitlist')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', user.id);
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'event_waitlist')) {
        return;
      }
      rethrow;
    }
  }

  Future<List<EventCheckinRecord>> getEventCheckins(String eventId) async {
    try {
      final List<dynamic> response = await _resolvedClient
          .from('event_checkins')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: false);

      return response
          .map(
            (dynamic row) => EventCheckinRecord.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'event_checkins')) {
        return <EventCheckinRecord>[];
      }
      rethrow;
    }
  }

  Future<void> hostRecordEventCheckin({
    required String eventId,
    required String attendeeUserId,
    required String status,
    String? notes,
  }) async {
    if (status != 'attended' && status != 'no_show') {
      throw Exception('Invalid check-in status.');
    }

    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in.');
    }

    final EventModel event = await getEventById(eventId);
    if (event.hostUserId != user.id) {
      throw Exception('Only the host can check in attendees.');
    }

    try {
      await _resolvedClient.from('event_checkins').upsert(
        <String, dynamic>{
          'event_id': eventId,
          'attendee_user_id': attendeeUserId,
          'checked_by_host_id': user.id,
          'status': status,
          'notes': _nullIfEmpty(notes),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'event_id,attendee_user_id',
      );
    } on PostgrestException catch (error) {
      if (!_isMissingTableError(error, 'event_checkins')) {
        rethrow;
      }
    }

    await hostConfirmAttendance(
      eventId: eventId,
      attendeeUserId: attendeeUserId,
      status: status,
    );
  }

  Future<String?> getCurrentUserCalendarExportProvider() async {
    final User? user = currentUser;
    if (user == null) {
      return null;
    }

    try {
      final Map<String, dynamic>? row = await _resolvedClient
          .from('event_calendar_exports')
          .select('provider')
          .eq('user_id', user.id)
          .maybeSingle();
      return _nullIfEmpty(row?['provider']?.toString());
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'event_calendar_exports')) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> setCurrentUserCalendarExportProvider(String provider) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in to update calendar sync.');
    }

    final String normalizedProvider = provider.trim().toLowerCase();
    if (normalizedProvider != 'google' &&
        normalizedProvider != 'apple' &&
        normalizedProvider != 'ics') {
      throw Exception('Unsupported calendar provider.');
    }

    try {
      await _resolvedClient.from('event_calendar_exports').upsert(
        <String, dynamic>{
          'user_id': user.id,
          'provider': normalizedProvider,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,provider',
      );
    } on PostgrestException catch (error) {
      if (_isMissingTableError(error, 'event_calendar_exports')) {
        return;
      }
      rethrow;
    }
  }

  bool _isMissingConfirmedAtColumnError(PostgrestException error) {
    if (error.code != 'PGRST204') {
      return false;
    }

    final String summary =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return summary.contains('confirmed_at') &&
        summary.contains('event_attendees');
  }

  bool _isMissingUpdatedAtTriggerError(PostgrestException error) {
    if (error.code != '42703' && error.code != 'PGRST204') {
      return false;
    }

    final String summary =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return summary.contains('updated_at') && summary.contains('new');
  }

  bool _isMissingTableError(PostgrestException error, String tableName) {
    if (error.code != '42P01' && error.code != 'PGRST205') {
      return false;
    }

    final String summary =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return summary.contains(tableName.toLowerCase());
  }

  bool _isMissingColumnError(PostgrestException error, String columnName) {
    // PGRST204/PostgREST and 42703/PostgreSQL are the missing-column cases.
    if (error.code != 'PGRST204' && error.code != '42703') {
      return false;
    }

    final String summary =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    final String needle = columnName.toLowerCase();
    return summary.contains("column '$needle'") ||
        summary.contains('"$needle"') ||
        summary.contains('column $needle');
  }

  Future<List<EventAttendanceRecord>> getEventAttendeesForHost(
    String eventId,
  ) async {
    final response = await _resolvedClient
        .from('event_attendees')
        .select()
        .eq('event_id', eventId)
        .order('created_at', ascending: true);

    final List<EventAttendanceRecord> baseRecords = (response as List<dynamic>)
        .map(
          (dynamic e) => EventAttendanceRecord.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    if (baseRecords.isEmpty) {
      return <EventAttendanceRecord>[];
    }

    final List<String> userIds = baseRecords.map((e) => e.userId).toList();

    final profilesResponse = await _resolvedClient
        .from('profiles')
        .select('id, call_sign, avatar_url')
        .inFilter('id', userIds);

    final Map<String, Map<String, dynamic>> profilesById = {
      for (final dynamic row in profilesResponse as List<dynamic>)
        row['id'].toString(): Map<String, dynamic>.from(row as Map),
    };

    return baseRecords.map((EventAttendanceRecord record) {
      final Map<String, dynamic>? profile = profilesById[record.userId];
      return EventAttendanceRecord(
        id: record.id,
        eventId: record.eventId,
        userId: record.userId,
        status: record.status,
        confirmedByHost: record.confirmedByHost,
        confirmedAt: record.confirmedAt,
        updatedAt: record.updatedAt,
        displayName: profile?['call_sign']?.toString(),
        avatarUrl: profile?['avatar_url']?.toString(),
      );
    }).toList();
  }

  Future<List<EventCommentModel>> getEventComments(String eventId) async {
    final response = await _resolvedClient
        .from('event_comments')
        .select(
          'id, event_id, parent_comment_id, user_id, body, is_deleted, created_at, updated_at',
        )
        .eq('event_id', eventId)
        .eq('is_deleted', false)
        .order('created_at', ascending: true);

    List<EventCommentModel> baseComments = (response as List<dynamic>)
        .map(
          (dynamic e) => EventCommentModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    if (currentUser != null) {
      final Set<String> hiddenUserIds = await _safetyRepository.getHiddenAuthorIds();
      baseComments = baseComments.where((EventCommentModel comment) {
        return !hiddenUserIds.contains(comment.userId);
      }).toList();
    }

    if (baseComments.isEmpty) {
      return <EventCommentModel>[];
    }

    final Set<String> userIds = baseComments
        .map((EventCommentModel comment) => comment.userId)
        .where((String id) => id.trim().isNotEmpty)
        .toSet();
    if (userIds.isEmpty) {
      return baseComments;
    }

    final profilesResponse = await _resolvedClient
        .from('profiles')
        .select('id, call_sign, avatar_url')
        .inFilter('id', userIds.toList());

    final Map<String, Map<String, dynamic>> profilesById =
        <String, Map<String, dynamic>>{
          for (final dynamic row in profilesResponse as List<dynamic>)
            row['id'].toString(): Map<String, dynamic>.from(row as Map),
        };

    return baseComments.map((EventCommentModel comment) {
      final Map<String, dynamic>? profile = profilesById[comment.userId];
      return comment.copyWith(
        callSign: profile?['call_sign']?.toString(),
        avatarUrl: profile?['avatar_url']?.toString(),
      );
    }).toList();
  }

  Future<void> addEventComment({
    required String eventId,
    required String body,
    String? parentCommentId,
  }) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in to comment.');
    }

    final String trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      throw Exception('Comment cannot be empty.');
    }

    await _resolvedClient.from('event_comments').insert({
      'event_id': eventId,
      'parent_comment_id': _nullIfEmpty(parentCommentId),
      'user_id': user.id,
      'body': trimmedBody,
      'is_deleted': false,
    });
  }

  Future<void> updateEventComment({
    required String commentId,
    required String body,
  }) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in to edit comments.');
    }

    final String trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      throw Exception('Comment cannot be empty.');
    }

    await _resolvedClient
        .from('event_comments')
        .update({'body': trimmedBody, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', commentId)
        .eq('user_id', user.id);
  }

  Future<void> softDeleteEventComment(String commentId) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in to delete comments.');
    }

    await _resolvedClient
        .from('event_comments')
        .update({
          'is_deleted': true,
          'body': '',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', commentId)
        .eq('user_id', user.id);
  }

  Future<List<EventModel>> getUserAttendingEvents(String userId) async {
    final response = await _resolvedClient
        .from('event_attendees')
        .select('event_id')
        .eq('user_id', userId)
        .eq('status', 'attending');

    final List<String> eventIds = (response as List<dynamic>)
        .map((dynamic e) => e['event_id'].toString())
        .toList();

    if (eventIds.isEmpty) {
      return <EventModel>[];
    }

    final eventsResponse = await _resolvedClient
        .from('events')
        .select()
        .inFilter('id', eventIds)
        .order('starts_at', ascending: true);

    final List<EventModel> events = (eventsResponse as List<dynamic>)
        .map(
          (dynamic e) =>
              EventModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return Future.wait<EventModel>(
      events.map((EventModel event) => _enrichEvent(event)),
    );
  }

  Future<EventAttendanceStats> getUserEventStats(String userId) async {
    final List<dynamic> response = await _resolvedClient
        .from('event_attendees')
        .select('status')
        .eq('user_id', userId);

    int attending = 0;
    int attended = 0;
    int cancelled = 0;
    int noShow = 0;

    for (final dynamic row in response) {
      final String status = (row['status'] ?? '').toString();
      switch (status) {
        case 'attending':
          attending++;
          break;
        case 'attended':
          attended++;
          break;
        case 'cancelled':
          cancelled++;
          break;
        case 'no_show':
          noShow++;
          break;
      }
    }

    return EventAttendanceStats(
      attending: attending,
      attended: attended,
      cancelled: cancelled,
      noShow: noShow,
    );
  }

  Future<EventModel> _enrichEvent(EventModel event) async {
    final EventAttendanceStats stats = await _getEventAttendanceStats(event.id);
    final String? currentStatus = await getCurrentUserAttendanceStatus(
      event.id,
    );

    return event.copyWith(
      currentUserAttendanceStatus: currentStatus,
      attendingCount: stats.attending,
      attendedCount: stats.attended,
      cancelledCount: stats.cancelled,
      noShowCount: stats.noShow,
    );
  }

  Future<String?> getCurrentUserAttendanceStatus(String eventId) async {
    final User? user = currentUser;
    if (user == null) {
      return null;
    }

    final Map<String, dynamic>? response = await _resolvedClient
        .from('event_attendees')
        .select('status')
        .eq('event_id', eventId)
        .eq('user_id', user.id)
        .maybeSingle();

    return response?['status']?.toString();
  }

  Future<EventAttendanceStats> _getEventAttendanceStats(String eventId) async {
    final List<dynamic> response = await _resolvedClient
        .from('event_attendees')
        .select('status')
        .eq('event_id', eventId);

    int attending = 0;
    int attended = 0;
    int cancelled = 0;
    int noShow = 0;

    for (final dynamic row in response) {
      final String status = (row['status'] ?? '').toString();
      switch (status) {
        case 'attending':
          attending++;
          break;
        case 'attended':
          attended++;
          break;
        case 'cancelled':
          cancelled++;
          break;
        case 'no_show':
          noShow++;
          break;
      }
    }

    return EventAttendanceStats(
      attending: attending,
      attended: attended,
      cancelled: cancelled,
      noShow: noShow,
    );
  }

  String? _nullIfEmpty(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _normalizeEventLanguage(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    switch (normalized) {
      case 'english':
      case 'japanese':
      case 'bilingual':
        return normalized;
      default:
        return 'bilingual';
    }
  }
}
