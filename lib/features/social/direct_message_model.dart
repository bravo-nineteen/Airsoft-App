import '../../core/time/japan_time.dart';

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

  factory DirectMessageModel.fromJson(Map<String, dynamic> json) {
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