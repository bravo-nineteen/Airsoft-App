import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/community/community_model.dart';
import '../../features/community/community_repository.dart';
import '../../features/events/event_model.dart';
import '../../features/events/event_repository.dart';
import '../../features/fields/field_model.dart';
import '../../features/fields/field_repository.dart';
import '../../features/social/direct_message_thread_model.dart';
import '../../features/social/direct_message_thread_repository.dart';

enum _PreloadedArea { community, events, fields, threads }

class AppContentPreloader {
  AppContentPreloader._();

  static final AppContentPreloader instance = AppContentPreloader._();

  final CommunityRepository _communityRepository = CommunityRepository();
  final EventRepository _eventRepository = EventRepository();
  final FieldRepository _fieldRepository = FieldRepository();
  final DirectMessageThreadRepository _threadRepository =
      DirectMessageThreadRepository();

  final ValueNotifier<int> communityRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> eventsRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> fieldsRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> threadsRevision = ValueNotifier<int>(0);

  List<CommunityPostModel> _communityPosts = const <CommunityPostModel>[];
  List<EventModel> _events = const <EventModel>[];
  List<FieldModel> _fields = const <FieldModel>[];
  List<DirectMessageThreadModel> _threads = const <DirectMessageThreadModel>[];

  RealtimeChannel? _contentChannel;
  RealtimeChannel? _messagesChannel;
  Timer? _refreshDebounce;
  Future<void>? _warmupFuture;
  String? _activeUserId;
  final Set<_PreloadedArea> _pendingAreas = <_PreloadedArea>{};

  List<CommunityPostModel> get communityPosts =>
      List<CommunityPostModel>.unmodifiable(_communityPosts);
  List<EventModel> get events => List<EventModel>.unmodifiable(_events);
  List<FieldModel> get fields => List<FieldModel>.unmodifiable(_fields);
  List<DirectMessageThreadModel> get threads =>
      List<DirectMessageThreadModel>.unmodifiable(_threads);

  Future<void> ensureStarted() async {
    final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (_activeUserId != currentUserId) {
      _restartRealtime(currentUserId);
    }

    _warmupFuture ??= _warmUpAll();
    try {
      await _warmupFuture;
    } finally {
      _warmupFuture = null;
    }
  }

  Future<List<CommunityPostModel>> loadCommunityPosts({
    bool preferCache = true,
  }) async {
    if (preferCache && _communityPosts.isNotEmpty) {
      return communityPosts;
    }
    return refreshCommunityPosts();
  }

  Future<List<EventModel>> loadEvents({bool preferCache = true}) async {
    if (preferCache && _events.isNotEmpty) {
      return events;
    }
    return refreshEvents();
  }

  Future<List<FieldModel>> loadFields({bool preferCache = true}) async {
    if (preferCache && _fields.isNotEmpty) {
      return fields;
    }
    return refreshFields();
  }

  Future<List<DirectMessageThreadModel>> loadThreads({
    bool preferCache = true,
  }) async {
    if (preferCache && _threads.isNotEmpty) {
      return threads;
    }
    return refreshThreads();
  }

  Future<List<CommunityPostModel>> refreshCommunityPosts() async {
    final CommunityPostsPage page = await _communityRepository.fetchPostsPage(
      category: 'All',
      preferredLanguage: 'all',
      offset: 0,
      limit: 20,
    );
    _communityPosts = page.items;
    communityRevision.value++;
    return communityPosts;
  }

  Future<List<EventModel>> refreshEvents() async {
    _events = await _eventRepository.getEvents();
    eventsRevision.value++;
    return events;
  }

  Future<List<FieldModel>> refreshFields() async {
    _fields = await _fieldRepository.getFields();
    fieldsRevision.value++;
    return fields;
  }

  Future<List<DirectMessageThreadModel>> refreshThreads() async {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _threads = const <DirectMessageThreadModel>[];
      threadsRevision.value++;
      return threads;
    }

    _threads = await _threadRepository.getThreads();
    threadsRevision.value++;
    return threads;
  }

  Future<void> _warmUpAll() {
    return Future.wait<void>(<Future<void>>[
      refreshCommunityPosts().then((_) {}),
      refreshEvents().then((_) {}),
      refreshFields().then((_) {}),
      refreshThreads().then((_) {}),
    ]);
  }

  void _restartRealtime(String? userId) {
    _disposeRealtime();
    _activeUserId = userId;

    final SupabaseClient client = Supabase.instance.client;

    _contentChannel = client
        .channel(
          'app-content-preload-${userId ?? 'guest'}-${DateTime.now().millisecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_posts',
          callback: (_) => _scheduleRefresh(_PreloadedArea.community),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_comments',
          callback: (_) => _scheduleRefresh(_PreloadedArea.community),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_post_likes',
          callback: (_) => _scheduleRefresh(_PreloadedArea.community),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_comment_likes',
          callback: (_) => _scheduleRefresh(_PreloadedArea.community),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: (_) => _scheduleRefresh(_PreloadedArea.events),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_attendees',
          callback: (_) => _scheduleRefresh(_PreloadedArea.events),
        )
        .subscribe();

    if (userId != null) {
      _messagesChannel = client
          .channel(
            'app-thread-preload-$userId-${DateTime.now().millisecondsSinceEpoch}',
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'direct_messages',
            callback: (PostgresChangePayload payload) {
              final String? newRecipientId = payload.newRecord['recipient_id']
                  ?.toString();
              final String? oldRecipientId = payload.oldRecord['recipient_id']
                  ?.toString();
              final String? newSenderId = payload.newRecord['sender_id']
                  ?.toString();
              final String? oldSenderId = payload.oldRecord['sender_id']
                  ?.toString();

              if (newRecipientId == userId ||
                  oldRecipientId == userId ||
                  newSenderId == userId ||
                  oldSenderId == userId) {
                _scheduleRefresh(_PreloadedArea.threads);
              }
            },
          )
          .subscribe();
    } else {
      _threads = const <DirectMessageThreadModel>[];
      threadsRevision.value++;
    }
  }

  void _scheduleRefresh(_PreloadedArea area) {
    _pendingAreas.add(area);
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_flushPendingRefreshes());
    });
  }

  Future<void> _flushPendingRefreshes() async {
    if (_pendingAreas.isEmpty) {
      return;
    }

    final Set<_PreloadedArea> nextAreas = Set<_PreloadedArea>.from(
      _pendingAreas,
    );
    _pendingAreas.clear();

    final List<Future<void>> jobs = <Future<void>>[];
    if (nextAreas.contains(_PreloadedArea.community)) {
      jobs.add(refreshCommunityPosts().then((_) {}));
    }
    if (nextAreas.contains(_PreloadedArea.events)) {
      jobs.add(refreshEvents().then((_) {}));
    }
    if (nextAreas.contains(_PreloadedArea.fields)) {
      jobs.add(refreshFields().then((_) {}));
    }
    if (nextAreas.contains(_PreloadedArea.threads)) {
      jobs.add(refreshThreads().then((_) {}));
    }

    try {
      await Future.wait<void>(jobs);
    } catch (_) {
      // Background refreshes are best-effort and should never disrupt UI.
    }
  }

  void _disposeRealtime() {
    final SupabaseClient client = Supabase.instance.client;
    if (_contentChannel != null) {
      client.removeChannel(_contentChannel!);
      _contentChannel = null;
    }
    if (_messagesChannel != null) {
      client.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
    _refreshDebounce?.cancel();
  }
}
