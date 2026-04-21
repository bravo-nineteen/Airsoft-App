import 'package:supabase_flutter/supabase_flutter.dart';

import '../community/community_image_service.dart';
import 'event_model.dart';
import '../notifications/notification_writer.dart';

class EventRepository {
  EventRepository({SupabaseClient? client})
    : _client = client,
      _notificationWriter = NotificationWriter(client: client),
      _imageService = CommunityImageService(client: client);

  final SupabaseClient? _client;
  final NotificationWriter _notificationWriter;
  final CommunityImageService _imageService;

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
