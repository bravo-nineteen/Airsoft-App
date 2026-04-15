class DirectMessageModel {
  const DirectMessageModel({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String recipientId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  factory DirectMessageModel.fromJson(Map<String, dynamic> json) {
    return DirectMessageModel(
      id: json['id'].toString(),
      senderId: json['sender_id'].toString(),
      recipientId: json['recipient_id'].toString(),
      body: (json['body'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      readAt: json['read_at'] == null
          ? null
          : DateTime.tryParse(json['read_at'].toString()),
    );
  }

  bool isRead() => readAt != null;
}