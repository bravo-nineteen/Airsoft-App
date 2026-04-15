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
    String? location,
  }) async {
    await _client.from('events').insert({
      'title': title,
      'description': description,
      'starts_at': startsAt.toIso8601String(),
      'location': location,
    });
  }
}
