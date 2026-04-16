class DirectMessageThreadModel {
  const DirectMessageThreadModel({
    required this.otherUserId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final String otherUserId;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  factory DirectMessageThreadModel.fromJson(Map<String, dynamic> json) {
    return DirectMessageThreadModel(
      otherUserId: json['other_user_id'].toString(),
      lastMessage: (json['last_message_body'] ?? '').toString(),
      lastMessageAt: DateTime.tryParse(
            (json['last_message_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}