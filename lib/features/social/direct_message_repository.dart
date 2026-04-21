import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../community/community_image_service.dart';
import 'contact_repository.dart';
import 'direct_message_model.dart';
import '../notifications/notification_writer.dart';

class DirectMessageRepository {
  DirectMessageRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client,
      _contactRepository = ContactRepository(client: client),
      _notificationWriter = NotificationWriter(client: client),
      _imageService = CommunityImageService(client: client);

  final SupabaseClient _client;
  final ContactRepository _contactRepository;
  final NotificationWriter _notificationWriter;
  final CommunityImageService _imageService;

  String get _currentUserId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in.');
    }
    return user.id;
  }

  bool _isTransient(Object error) {
    final String text = error.toString().toLowerCase();
    return text.contains('502') ||
        text.contains('503') ||
        text.contains('gateway') ||
        text.contains('socketexception') ||
        text.contains('timeout');
  }

  Future<T> _withTransientRetry<T>(Future<T> Function() action) async {
    Object? lastError;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        return await action();
      } catch (error) {
        lastError = error;
        if (!_isTransient(error) || attempt == 2) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
    throw lastError ?? Exception('Unknown messaging error');
  }

  Future<List<DirectMessageModel>> getMessages(String otherUserId) async {
    final currentUserId = _currentUserId;

    final allowed = await _contactRepository.areAcceptedContacts(otherUserId);
    if (!allowed) {
      throw Exception('Messaging is only available for accepted contacts.');
    }

    await cleanupExpiredMediaMessages();

    final response = await _withTransientRetry(
      () => _client
          .from('direct_messages')
          .select()
          .or(
            'and(sender_id.eq.$currentUserId,recipient_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,recipient_id.eq.$currentUserId)',
          )
          .order('created_at', ascending: true),
    );

    return response
      .map<DirectMessageModel>((e) => DirectMessageModel.fromJson(e))
      .where((DirectMessageModel message) => !message.isExpired)
      .toList();
  }

  Future<void> sendMessage({
    required String recipientId,
    required String body,
    String? imageUrl,
    bool expiresIn30Days = false,
  }) async {
    final currentUserId = _currentUserId;

    final allowed = await _contactRepository.areAcceptedContacts(recipientId);
    if (!allowed) {
      throw Exception('Messaging is only available for accepted contacts.');
    }

    final trimmed = body.trim();
    final String normalizedImageUrl = (imageUrl ?? '').trim();
    if (trimmed.isEmpty && normalizedImageUrl.isEmpty) {
      throw Exception('Message is empty.');
    }

    final String? expiresAt = normalizedImageUrl.isNotEmpty && expiresIn30Days
        ? DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String()
        : null;

    await _client.from('direct_messages').insert({
      'sender_id': currentUserId,
      'recipient_id': recipientId,
      'body': trimmed,
      'image_url': normalizedImageUrl.isEmpty ? null : normalizedImageUrl,
      'expires_at': expiresAt,
    });

    final String actorName = await _notificationWriter.getCurrentActorName();
    await _notificationWriter.safeCreateNotification(
      userId: recipientId,
      type: 'direct_message',
      entityId: currentUserId,
      title: actorName,
      body: trimmed.length <= 120 ? trimmed : '${trimmed.substring(0, 117)}...',
    );
  }

  Future<void> unsendMessage(String messageId) async {
    final String currentUserId = _currentUserId;

    final Map<String, dynamic>? row = await _client
        .from('direct_messages')
        .select('sender_id, image_url')
        .eq('id', messageId)
        .maybeSingle();
    if (row == null) {
      return;
    }
    if (row['sender_id']?.toString() != currentUserId) {
      throw Exception('Only sender can unsend a message.');
    }

    final String? imageUrl = row['image_url']?.toString();
    await _client
        .from('direct_messages')
        .update({
          'body': '[Message unsent]',
          'image_url': null,
          'unsent_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', messageId)
        .eq('sender_id', currentUserId);

    await _imageService.deleteUploadedImageByPublicUrl(imageUrl);
  }

  Future<void> deleteMessage(String messageId) async {
    final String currentUserId = _currentUserId;

    final Map<String, dynamic>? row = await _client
        .from('direct_messages')
        .select('sender_id, recipient_id, image_url')
        .eq('id', messageId)
        .maybeSingle();
    if (row == null) {
      return;
    }

    final String senderId = row['sender_id']?.toString() ?? '';
    final String recipientId = row['recipient_id']?.toString() ?? '';
    if (senderId != currentUserId && recipientId != currentUserId) {
      throw Exception('Not allowed to delete this message.');
    }

    await _client.from('direct_messages').delete().eq('id', messageId);
    await _imageService.deleteUploadedImageByPublicUrl(
      row['image_url']?.toString(),
    );
  }

  Future<void> cleanupExpiredMediaMessages() async {
    final String nowIso = DateTime.now().toUtc().toIso8601String();

    final List<dynamic> expired = await _client
        .from('direct_messages')
        .select('id, image_url')
        .lte('expires_at', nowIso);

    for (final dynamic row in expired) {
      await _imageService.deleteUploadedImageByPublicUrl(
        row['image_url']?.toString(),
      );
      await _client.from('direct_messages').delete().eq('id', row['id']);
    }
  }

  Future<void> markThreadRead(String otherUserId) async {
    final currentUserId = _currentUserId;

    await _withTransientRetry(
      () => _client
          .from('direct_messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('sender_id', otherUserId)
          .eq('recipient_id', currentUserId)
          .isFilter('read_at', null),
    );
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

    final response = await _withTransientRetry(
      () => _client
          .from('direct_messages')
          .select('id')
          .eq('recipient_id', currentUserId)
          .isFilter('read_at', null),
    );

    return response.length;
  }
}