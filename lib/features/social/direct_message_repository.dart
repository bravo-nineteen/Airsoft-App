import 'package:supabase_flutter/supabase_flutter.dart';

import 'contact_repository.dart';
import 'direct_message_model.dart';

class DirectMessageRepository {
  DirectMessageRepository();

  final SupabaseClient _client = Supabase.instance.client;
  final ContactRepository _contactRepository = ContactRepository();

  String get _currentUserId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in.');
    }
    return user.id;
  }

  Future<List<DirectMessageModel>> getMessages(String otherUserId) async {
    final currentUserId = _currentUserId;

    final allowed = await _contactRepository.areAcceptedContacts(otherUserId);
    if (!allowed) {
      throw Exception('Messaging is only available for accepted contacts.');
    }

    final response = await _client
        .from('direct_messages')
        .select()
        .or(
          'and(sender_id.eq.$currentUserId,recipient_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,recipient_id.eq.$currentUserId)',
        )
        .order('created_at', ascending: true);

    return response
        .map<DirectMessageModel>((e) => DirectMessageModel.fromJson(e))
        .toList();
  }

  Future<void> sendMessage({
    required String recipientId,
    required String body,
  }) async {
    final currentUserId = _currentUserId;

    final allowed = await _contactRepository.areAcceptedContacts(recipientId);
    if (!allowed) {
      throw Exception('Messaging is only available for accepted contacts.');
    }

    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw Exception('Message is empty.');
    }

    await _client.from('direct_messages').insert({
      'sender_id': currentUserId,
      'recipient_id': recipientId,
      'body': trimmed,
    });
  }

  Future<void> markThreadRead(String otherUserId) async {
    final currentUserId = _currentUserId;

    await _client
        .from('direct_messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('sender_id', otherUserId)
        .eq('recipient_id', currentUserId)
        .isFilter('read_at', null);
  }

  RealtimeChannel subscribeToThread({
    required String otherUserId,
    required VoidCallback onMessage,
  }) {
    final currentUserId = _currentUserId;

    final channel = _client.channel('dm-$currentUserId-$otherUserId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          callback: (payload) {
            final row = payload.newRecord;
            final senderId = row['sender_id']?.toString();
            final recipientId = row['recipient_id']?.toString();

            final matches = (senderId == currentUserId &&
                    recipientId == otherUserId) ||
                (senderId == otherUserId && recipientId == currentUserId);

            if (matches) {
              onMessage();
            }
          },
        )
        .subscribe();

    return channel;
  }

  Future<int> getUnreadCount() async {
    final currentUserId = _currentUserId;

    final response = await _client
        .from('direct_messages')
        .select('id')
        .eq('recipient_id', currentUserId)
        .isFilter('read_at', null);

    return response.length;
  }
}