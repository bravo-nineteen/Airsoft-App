import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_model.dart';

class EventRepository {
  EventRepository();

  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Future<List<EventModel>> getEvents() async {
    final response = await _client
        .from('events')
        .select()
        .order('starts_at', ascending: true);

    final List<EventModel> baseEvents = (response as List<dynamic>)
        .map(
          (dynamic e) => EventModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    return Future.wait<EventModel>(
      baseEvents.map((EventModel event) => _enrichEvent(event)),
    );
  }

  Future<EventModel> getEventById(String eventId) async {
    final response =
        await _client.from('events').select().eq('id', eventId).single();

    final EventModel event =
        EventModel.fromJson(Map<String, dynamic>.from(response));
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

    await _client.from('events').insert({
      'title': trimmedTitle,
      'description': trimmedDescription,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'location': _nullIfEmpty(location),
      'prefecture': _nullIfEmpty(prefecture),
      'event_type': _nullIfEmpty(eventType),
      'language': _nullIfEmpty(language),
      'skill_level': _nullIfEmpty(skillLevel),
      'organizer_name': _nullIfEmpty(organizerName),
      'contact_info': _nullIfEmpty(contactInfo),
      'notes': _nullIfEmpty(notes),
      'price_yen': priceYen,
      'max_players': maxPlayers,
      'host_user_id': user.id,
      'is_official': isOfficial,
    });
  }

  Future<void> attendEvent(String eventId) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in to attend events.');
    }

    final Map<String, dynamic>? existing = await _client
        .from('event_attendees')
        .select('id')
        .eq('event_id', eventId)
        .eq('user_id', user.id)
        .maybeSingle();

    final Map<String, dynamic> payload = <String, dynamic>{
      'event_id': eventId,
      'user_id': user.id,
      'status': 'attending',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (existing == null) {
      await _client.from('event_attendees').insert(payload);
    } else {
      await _client
          .from('event_attendees')
          .update({'status': 'attending', 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('event_id', eventId)
          .eq('user_id', user.id);
    }
  }

  Future<void> cancelAttendance(String eventId) async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('You must be logged in to cancel attendance.');
    }

    final Map<String, dynamic>? existing = await _client
        .from('event_attendees')
        .select('id')
        .eq('event_id', eventId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing == null) {
      await _client.from('event_attendees').insert({
        'event_id': eventId,
        'user_id': user.id,
        'status': 'cancelled',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } else {
      await _client
          .from('event_attendees')
          .update({'status': 'cancelled', 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('event_id', eventId)
          .eq('user_id', user.id);
    }
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

    await _client
        .from('event_attendees')
        .update({
          'status': status,
          'confirmed_by_host': status == 'attended' || status == 'no_show',
          'confirmed_at': status == 'attended' || status == 'no_show'
              ? DateTime.now().toUtc().toIso8601String()
              : null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('event_id', eventId)
        .eq('user_id', attendeeUserId);
  }

  Future<List<EventAttendanceRecord>> getEventAttendeesForHost(
    String eventId,
  ) async {
    final response = await _client
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

    final profilesResponse = await _client
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
    final response = await _client
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

    final eventsResponse = await _client
        .from('events')
        .select()
        .inFilter('id', eventIds)
        .order('starts_at', ascending: true);

    final List<EventModel> events = (eventsResponse as List<dynamic>)
        .map(
          (dynamic e) => EventModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    return Future.wait<EventModel>(
      events.map((EventModel event) => _enrichEvent(event)),
    );
  }

  Future<EventAttendanceStats> getUserEventStats(String userId) async {
    final List<dynamic> response = await _client
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
    final String? currentStatus =
        await getCurrentUserAttendanceStatus(event.id);

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

    final Map<String, dynamic>? response = await _client
        .from('event_attendees')
        .select('status')
        .eq('event_id', eventId)
        .eq('user_id', user.id)
        .maybeSingle();

    return response?['status']?.toString();
  }

  Future<EventAttendanceStats> _getEventAttendanceStats(String eventId) async {
    final List<dynamic> response = await _client
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
}
