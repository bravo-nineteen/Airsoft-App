import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'direct_message_thread_model.dart';

class DirectMessageThreadRepository {
  DirectMessageThreadRepository();

  final SupabaseClient _client = Supabase.instance.client;

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

  Future<List<DirectMessageThreadModel>> getThreads() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in.');
    }

    final response = await _withTransientRetry(
      () => _client
        .from('direct_message_threads')
        .select()
        .eq('current_user_id', user.id)
        .order('last_message_at', ascending: false),
    );

    return response
        .map<DirectMessageThreadModel>(
          (e) => DirectMessageThreadModel.fromJson(e),
        )
        .toList();
  }
}