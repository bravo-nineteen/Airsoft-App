import '../../core/time/japan_time.dart';
import '../community/community_reaction_types.dart';

class DirectMessageModel {
  const DirectMessageModel({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    this.imageUrl,
    this.expiresAt,
    this.unsentAt,
    this.readAt,
    this.reactionCount = 0,
    this.myReaction,
  });

  final String id;
  final String senderId;
  final String recipientId;
  final String body;
  final DateTime createdAt;
  final String? imageUrl;
  final DateTime? expiresAt;
  final DateTime? unsentAt;
  final DateTime? readAt;
  final int reactionCount;
  final String? myReaction;

  DirectMessageModel copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? body,
    DateTime? createdAt,
    Object? imageUrl = _dmNoChange,
    Object? expiresAt = _dmNoChange,
    Object? unsentAt = _dmNoChange,
    Object? readAt = _dmNoChange,
    int? reactionCount,
    Object? myReaction = _dmNoChange,
  }) {
    return DirectMessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl == _dmNoChange ? this.imageUrl : imageUrl as String?,
      expiresAt: expiresAt == _dmNoChange ? this.expiresAt : expiresAt as DateTime?,
      unsentAt: unsentAt == _dmNoChange ? this.unsentAt : unsentAt as DateTime?,
      readAt: readAt == _dmNoChange ? this.readAt : readAt as DateTime?,
      reactionCount: reactionCount ?? this.reactionCount,
      myReaction: myReaction == _dmNoChange
          ? this.myReaction
          : myReaction as String?,
    );
  }

  factory DirectMessageModel.fromJson(Map<String, dynamic> json) {
    final String? myReaction = CommunityReactionTypes.normalizeNullable(
      _readNullableString(json['my_reaction']) ?? _readNullableString(json['reaction']),
    );
    return DirectMessageModel(
      id: json['id'].toString(),
      senderId: json['sender_id'].toString(),
      recipientId: json['recipient_id'].toString(),
      body: (json['body'] ?? '').toString(),
      createdAt:
          JapanTime.parseServerTimestamp(json['created_at']) ?? DateTime.now(),
      imageUrl: _readNullableString(json['image_url']),
      expiresAt: JapanTime.parseServerTimestamp(json['expires_at']),
      unsentAt: JapanTime.parseServerTimestamp(json['unsent_at']),
      readAt: JapanTime.parseServerTimestamp(json['read_at']),
      reactionCount: (json['reaction_count'] as num?)?.toInt() ?? 0,
      myReaction: myReaction,
    );
  }

  bool isRead() => readAt != null;

  bool get isUnsent => unsentAt != null;

  bool get isExpired {
    if (expiresAt == null) {
      return false;
    }
    return JapanTime.now().isAfter(expiresAt!);
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

const Object _dmNoChange = Object();