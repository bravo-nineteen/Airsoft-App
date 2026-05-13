import '../../core/time/japan_time.dart';
import '../community/community_reaction_types.dart';

class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    this.country,
    this.location,
    this.prefecture,
    this.eventType,
    this.language,
    this.skillLevel,
    this.organizerName,
    this.contactInfo,
    this.notes,
    this.priceYen,
    this.maxPlayers,
    this.imageUrl,
    this.bookTicketsUrl,
    this.pinnedUntil,
    this.hostUserId,
    this.currentUserAttendanceStatus,
    this.attendingCount = 0,
    this.attendedCount = 0,
    this.cancelledCount = 0,
    this.noShowCount = 0,
    this.isOfficial = false,
  });

  final String id;
  final String title;
  final String description;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? country;
  final String? location;
  final String? prefecture;
  final String? eventType;
  final String? language;
  final String? skillLevel;
  final String? organizerName;
  final String? contactInfo;
  final String? notes;
  final int? priceYen;
  final int? maxPlayers;
  final String? imageUrl;
  final String? bookTicketsUrl;
  final DateTime? pinnedUntil;
  final String? hostUserId;
  final String? currentUserAttendanceStatus;
  final int attendingCount;
  final int attendedCount;
  final int cancelledCount;
  final int noShowCount;
  final bool isOfficial;

  bool get isUserAttending => currentUserAttendanceStatus == 'attending';
  bool get isUserCancelled => currentUserAttendanceStatus == 'cancelled';
  bool get isUserAttended => currentUserAttendanceStatus == 'attended';
  bool get isUserNoShow => currentUserAttendanceStatus == 'no_show';

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startsAt,
    DateTime? endsAt,
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
    DateTime? pinnedUntil,
    String? hostUserId,
    String? currentUserAttendanceStatus,
    int? attendingCount,
    int? attendedCount,
    int? cancelledCount,
    int? noShowCount,
    bool? isOfficial,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      country: country ?? this.country,
      location: location ?? this.location,
      prefecture: prefecture ?? this.prefecture,
      eventType: eventType ?? this.eventType,
      language: language ?? this.language,
      skillLevel: skillLevel ?? this.skillLevel,
      organizerName: organizerName ?? this.organizerName,
      contactInfo: contactInfo ?? this.contactInfo,
      notes: notes ?? this.notes,
      priceYen: priceYen ?? this.priceYen,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      imageUrl: imageUrl ?? this.imageUrl,
      bookTicketsUrl: bookTicketsUrl ?? this.bookTicketsUrl,
      pinnedUntil: pinnedUntil ?? this.pinnedUntil,
      hostUserId: hostUserId ?? this.hostUserId,
      currentUserAttendanceStatus:
          currentUserAttendanceStatus ?? this.currentUserAttendanceStatus,
      attendingCount: attendingCount ?? this.attendingCount,
      attendedCount: attendedCount ?? this.attendedCount,
      cancelledCount: cancelledCount ?? this.cancelledCount,
      noShowCount: noShowCount ?? this.noShowCount,
      isOfficial: isOfficial ?? this.isOfficial,
    );
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final DateTime startsAt =
      JapanTime.parseServerTimestamp(json['starts_at']) ?? DateTime.now();

    final DateTime endsAt =
      JapanTime.parseServerTimestamp(json['ends_at']) ??
            startsAt.add(const Duration(hours: 6));

    return EventModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      startsAt: startsAt,
      endsAt: endsAt,
      country: _readNullableString(json['country']),
      location: _readNullableString(json['location']),
      prefecture: _readNullableString(json['prefecture']),
      eventType: _readNullableString(json['event_type']),
      language: _readNullableString(json['language']),
      skillLevel: _readNullableString(json['skill_level']),
      organizerName: _readNullableString(json['organizer_name']),
      contactInfo: _readNullableString(json['contact_info']),
      notes: _readNullableString(json['notes']),
      priceYen: _readNullableInt(json['price_yen']),
      maxPlayers: _readNullableInt(json['max_players']),
      imageUrl: _readNullableString(json['image_url']),
        bookTicketsUrl: _readNullableString(json['book_tickets_url']),
          pinnedUntil: JapanTime.parseServerTimestamp(json['pinned_until']),
      hostUserId: _readNullableString(json['host_user_id']),
      currentUserAttendanceStatus:
          _readNullableString(json['current_user_attendance_status']),
      attendingCount: _readNullableInt(json['attending_count']) ?? 0,
      attendedCount: _readNullableInt(json['attended_count']) ?? 0,
      cancelledCount: _readNullableInt(json['cancelled_count']) ?? 0,
      noShowCount: _readNullableInt(json['no_show_count']) ?? 0,
      isOfficial: (json['is_official'] as bool?) ?? false,
    );
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _readNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }
}

class EventAttendanceRecord {
  const EventAttendanceRecord({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.status,
    required this.confirmedByHost,
    this.confirmedAt,
    this.updatedAt,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String eventId;
  final String userId;
  final String status;
  final bool confirmedByHost;
  final DateTime? confirmedAt;
  final DateTime? updatedAt;
  final String? displayName;
  final String? avatarUrl;

  bool get isAttending => status == 'attending';
  bool get isCancelled => status == 'cancelled';
  bool get isAttended => status == 'attended';
  bool get isNoShow => status == 'no_show';

  factory EventAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return EventAttendanceRecord(
      id: (json['id'] ?? '').toString(),
      eventId: (json['event_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      status: (json['status'] ?? 'attending').toString(),
      confirmedByHost: json['confirmed_by_host'] == true,
        confirmedAt: JapanTime.parseServerTimestamp(json['confirmed_at']),
        updatedAt: JapanTime.parseServerTimestamp(json['updated_at']),
      displayName: _readNullableString(json['display_name']),
      avatarUrl: _readNullableString(json['avatar_url']),
    );
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

class EventAttendanceStats {
  const EventAttendanceStats({
    this.attending = 0,
    this.attended = 0,
    this.cancelled = 0,
    this.noShow = 0,
  });

  final int attending;
  final int attended;
  final int cancelled;
  final int noShow;
}

class EventCheckinRecord {
  const EventCheckinRecord({
    required this.id,
    required this.eventId,
    required this.attendeeUserId,
    required this.status,
    required this.createdAt,
    this.checkedByHostId,
    this.notes,
  });

  final String id;
  final String eventId;
  final String attendeeUserId;
  final String status;
  final String? checkedByHostId;
  final String? notes;
  final DateTime createdAt;

  bool get attended => status == 'attended';
  bool get noShow => status == 'no_show';

  factory EventCheckinRecord.fromJson(Map<String, dynamic> json) {
    return EventCheckinRecord(
      id: (json['id'] ?? '').toString(),
      eventId: (json['event_id'] ?? '').toString(),
      attendeeUserId: (json['attendee_user_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      checkedByHostId: _readNullableString(json['checked_by_host_id']),
      notes: _readNullableString(json['notes']),
      createdAt:
          JapanTime.parseServerTimestamp(json['created_at']) ?? DateTime.now(),
    );
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

class EventCommentModel {
  const EventCommentModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.updatedAt,
    this.parentCommentId,
    this.callSign,
    this.avatarUrl,
    this.reactionCount = 0,
    this.myReaction,
  });

  final String id;
  final String eventId;
  final String userId;
  final String body;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? parentCommentId;
  final String? callSign;
  final String? avatarUrl;
  final int reactionCount;
  final String? myReaction;

  String get displayName {
    final String name = (callSign ?? '').trim();
    return name.isEmpty ? 'Operator' : name;
  }

  EventCommentModel copyWith({
    String? id,
    String? eventId,
    String? userId,
    String? body,
    DateTime? createdAt,
    Object? updatedAt = _eventCommentNoChange,
    Object? parentCommentId = _eventCommentNoChange,
    Object? callSign = _eventCommentNoChange,
    Object? avatarUrl = _eventCommentNoChange,
    int? reactionCount,
    Object? myReaction = _eventCommentNoChange,
  }) {
    return EventCommentModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt == _eventCommentNoChange
          ? this.updatedAt
          : updatedAt as DateTime?,
      parentCommentId: parentCommentId == _eventCommentNoChange
          ? this.parentCommentId
          : parentCommentId as String?,
      callSign: callSign == _eventCommentNoChange
          ? this.callSign
          : callSign as String?,
      avatarUrl: avatarUrl == _eventCommentNoChange
          ? this.avatarUrl
          : avatarUrl as String?,
      reactionCount: reactionCount ?? this.reactionCount,
      myReaction: myReaction == _eventCommentNoChange
          ? this.myReaction
          : myReaction as String?,
    );
  }

  factory EventCommentModel.fromJson(Map<String, dynamic> json) {
    final String? myReaction = CommunityReactionTypes.normalizeNullable(
      _readNullableString(json['my_reaction']) ?? _readNullableString(json['reaction']),
    );
    return EventCommentModel(
      id: (json['id'] ?? '').toString(),
      eventId: (json['event_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt: JapanTime.parseServerTimestamp(json['created_at']) ?? DateTime.now(),
      updatedAt: JapanTime.parseServerTimestamp(json['updated_at']),
      parentCommentId: _readNullableString(json['parent_comment_id']),
      callSign: _readNullableString(json['call_sign']),
      avatarUrl: _readNullableString(json['avatar_url']),
      reactionCount: (json['reaction_count'] as num?)?.toInt() ?? 0,
      myReaction: myReaction,
    );
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}

const Object _eventCommentNoChange = Object();
