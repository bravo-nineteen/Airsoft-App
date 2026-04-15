import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_model.dart';

class EventRepository {
  EventRepository();

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<EventModel>> getEvents() async {
    final response = await _client
        .from('events')
        .select()
        .order('starts_at', ascending: true);

    return response.map<EventModel>((e) => EventModel.fromJson(e)).toList();
  }

  Future<void> createEvent({
    required String title,
    required String description,
    required DateTime startsAt,
    required DateTime endsAt,
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
    await _client.from('events').insert({
      'title': title,
      'description': description,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
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
    });
  }

  String? _nullIfEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}