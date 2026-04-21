import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  static const int _cacheSchemaVersion = 2;
  static const Duration _communityCacheTtl = Duration(minutes: 30);
  static const Duration _eventsCacheTtl = Duration(minutes: 15);
  static const Duration _fieldsCacheTtl = Duration(hours: 24);
  static const Duration _threadsCacheTtl = Duration(minutes: 10);
  static const String _communityCacheBaseKey = 'preload.community_posts';
  static const String _eventsCacheBaseKey = 'preload.events';
  static const String _fieldsCacheBaseKey = 'preload.fields';

  static String get _communityCacheKey =>
    '$_communityCacheBaseKey.v$_cacheSchemaVersion';
  static String get _eventsCacheKey =>
    '$_eventsCacheBaseKey.v$_cacheSchemaVersion';
  static String get _fieldsCacheKey =>
    '$_fieldsCacheBaseKey.v$_cacheSchemaVersion';

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
  Future<void>? _diskHydrationFuture;
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

    await _ensureDiskHydrated();

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
    await _ensureDiskHydrated();
    if (preferCache && _communityPosts.isNotEmpty) {
      return communityPosts;
    }
    return refreshCommunityPosts();
  }

  Future<List<EventModel>> loadEvents({bool preferCache = true}) async {
    await _ensureDiskHydrated();
    if (preferCache && _events.isNotEmpty) {
      return events;
    }
    return refreshEvents();
  }

  Future<List<FieldModel>> loadFields({bool preferCache = true}) async {
    await _ensureDiskHydrated();
    if (preferCache && _fields.isNotEmpty) {
      return fields;
    }
    return refreshFields();
  }

  Future<List<DirectMessageThreadModel>> loadThreads({
    bool preferCache = true,
  }) async {
    await _ensureDiskHydrated();
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
    unawaited(_saveCommunityCache(_communityPosts));
    return communityPosts;
  }

  Future<List<EventModel>> refreshEvents() async {
    _events = await _eventRepository.getEvents();
    eventsRevision.value++;
    unawaited(_saveEventsCache(_events));
    return events;
  }

  Future<List<FieldModel>> refreshFields() async {
    _fields = await _fieldRepository.getFields();
    fieldsRevision.value++;
    unawaited(_saveFieldsCache(_fields));
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
    unawaited(_saveThreadsCache(_threads, _activeUserId));
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
    _diskHydrationFuture = null;

    _threads = const <DirectMessageThreadModel>[];
    threadsRevision.value++;

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

  Future<void> _ensureDiskHydrated() async {
    _diskHydrationFuture ??= _hydrateFromDisk();
    try {
      await _diskHydrationFuture;
    } finally {
      _diskHydrationFuture = null;
    }
  }

  Future<void> _hydrateFromDisk() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final String? communityRaw = prefs.getString(_communityCacheKey);
        if (_isCacheFresh(prefs, _communityCacheKey, _communityCacheTtl) &&
          communityRaw != null &&
          _communityPosts.isEmpty) {
        final List<dynamic> decoded = jsonDecode(communityRaw) as List<dynamic>;
        _communityPosts = decoded
            .map(
              (dynamic row) => CommunityPostModel.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
        if (_communityPosts.isNotEmpty) {
          communityRevision.value++;
        }
      }

      final String? eventsRaw = prefs.getString(_eventsCacheKey);
        if (_isCacheFresh(prefs, _eventsCacheKey, _eventsCacheTtl) &&
          eventsRaw != null &&
          _events.isEmpty) {
        final List<dynamic> decoded = jsonDecode(eventsRaw) as List<dynamic>;
        _events = decoded
            .map(
              (dynamic row) => EventModel.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
        if (_events.isNotEmpty) {
          eventsRevision.value++;
        }
      }

      final String? fieldsRaw = prefs.getString(_fieldsCacheKey);
        if (_isCacheFresh(prefs, _fieldsCacheKey, _fieldsCacheTtl) &&
          fieldsRaw != null &&
          _fields.isEmpty) {
        final List<dynamic> decoded = jsonDecode(fieldsRaw) as List<dynamic>;
        _fields = decoded
            .map(
              (dynamic row) => FieldModel.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
        if (_fields.isNotEmpty) {
          fieldsRevision.value++;
        }
      }

      final String threadsKey = _threadsCacheKey(_activeUserId);
      final String? threadsRaw = prefs.getString(threadsKey);
        if (_isCacheFresh(prefs, threadsKey, _threadsCacheTtl) &&
          threadsRaw != null &&
          _threads.isEmpty) {
        final List<dynamic> decoded = jsonDecode(threadsRaw) as List<dynamic>;
        _threads = decoded
            .map(
              (dynamic row) => DirectMessageThreadModel.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
        if (_threads.isNotEmpty) {
          threadsRevision.value++;
        }
      }
    } catch (_) {
      // Hydration is best-effort and should never block network refresh.
    }
  }

  Future<void> _saveCommunityCache(List<CommunityPostModel> posts) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(
        posts.map((CommunityPostModel post) => post.toJson()).toList(),
      );
      await prefs.setString(_communityCacheKey, encoded);
      await prefs.setInt(
        _cacheSavedAtKey(_communityCacheKey),
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  Future<void> _saveEventsCache(List<EventModel> events) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(
        events.map((EventModel event) => _eventToJson(event)).toList(),
      );
      await prefs.setString(_eventsCacheKey, encoded);
      await prefs.setInt(
        _cacheSavedAtKey(_eventsCacheKey),
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  Future<void> _saveFieldsCache(List<FieldModel> fields) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(
        fields.map((FieldModel field) => _fieldToJson(field)).toList(),
      );
      await prefs.setString(_fieldsCacheKey, encoded);
      await prefs.setInt(
        _cacheSavedAtKey(_fieldsCacheKey),
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  Future<void> _saveThreadsCache(
    List<DirectMessageThreadModel> threads,
    String? userId,
  ) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String key = _threadsCacheKey(userId);
      final String encoded = jsonEncode(
        threads
            .map((DirectMessageThreadModel thread) => _threadToJson(thread))
            .toList(),
      );
      await prefs.setString(key, encoded);
      await prefs.setInt(
        _cacheSavedAtKey(key),
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  String _threadsCacheKey(String? userId) {
    return 'preload.threads.${userId ?? 'guest'}.v$_cacheSchemaVersion';
  }

  String _cacheSavedAtKey(String dataKey) => '$dataKey.saved_at_ms';

  bool _isCacheFresh(
    SharedPreferences prefs,
    String dataKey,
    Duration ttl,
  ) {
    final int? savedAtMs = prefs.getInt(_cacheSavedAtKey(dataKey));
    if (savedAtMs == null) {
      return false;
    }

    final int ageMs = DateTime.now().millisecondsSinceEpoch - savedAtMs;
    if (ageMs <= ttl.inMilliseconds) {
      return true;
    }

    unawaited(prefs.remove(dataKey));
    unawaited(prefs.remove(_cacheSavedAtKey(dataKey)));
    return false;
  }

  Map<String, dynamic> _eventToJson(EventModel event) {
    return <String, dynamic>{
      'id': event.id,
      'title': event.title,
      'description': event.description,
      'starts_at': event.startsAt.toUtc().toIso8601String(),
      'ends_at': event.endsAt.toUtc().toIso8601String(),
      'location': event.location,
      'prefecture': event.prefecture,
      'event_type': event.eventType,
      'language': event.language,
      'skill_level': event.skillLevel,
      'organizer_name': event.organizerName,
      'contact_info': event.contactInfo,
      'notes': event.notes,
      'price_yen': event.priceYen,
      'max_players': event.maxPlayers,
      'image_url': event.imageUrl,
      'book_tickets_url': event.bookTicketsUrl,
      'pinned_until': event.pinnedUntil?.toUtc().toIso8601String(),
      'host_user_id': event.hostUserId,
      'current_user_attendance_status': event.currentUserAttendanceStatus,
      'attending_count': event.attendingCount,
      'attended_count': event.attendedCount,
      'cancelled_count': event.cancelledCount,
      'no_show_count': event.noShowCount,
      'is_official': event.isOfficial,
    };
  }

  Map<String, dynamic> _fieldToJson(FieldModel field) {
    return <String, dynamic>{
      'id': field.id,
      'name': field.name,
      'location_name': field.locationName,
      'description': field.description,
      'latitude': field.latitude,
      'longitude': field.longitude,
      'prefecture': field.prefecture,
      'city': field.city,
      'field_type': field.fieldType,
      'image_url': field.imageUrl,
      'rating': field.rating,
      'review_count': field.reviewCount,
      'feature_list': field.featuresText,
      'pros_list': field.prosText,
      'cons_list': field.consText,
      'is_official': field.isOfficial,
      'claim_status': field.claimStatus,
      'claimed_by_user_id': field.claimedByUserId,
      'booking_enabled': field.bookingEnabled,
      'booking_contact_name': field.bookingContactName,
      'booking_phone': field.bookingPhone,
      'booking_email': field.bookingEmail,
    };
  }

  Map<String, dynamic> _threadToJson(DirectMessageThreadModel thread) {
    return <String, dynamic>{
      'other_user_id': thread.otherUserId,
      'last_message_body': thread.lastMessage,
      'last_message_at': thread.lastMessageAt.toUtc().toIso8601String(),
      'unread_count': thread.unreadCount,
    };
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
