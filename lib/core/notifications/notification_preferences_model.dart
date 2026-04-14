class NotificationPreferencesModel {
  const NotificationPreferencesModel({
    required this.userId,
    required this.eventNotifications,
    required this.meetupNotifications,
    required this.directMessageNotifications,
    required this.fieldUpdateNotifications,
  });

  final String userId;
  final bool eventNotifications;
  final bool meetupNotifications;
  final bool directMessageNotifications;
  final bool fieldUpdateNotifications;

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      userId: json['user_id'] as String,
      eventNotifications: json['event_notifications'] as bool? ?? true,
      meetupNotifications: json['meetup_notifications'] as bool? ?? true,
      directMessageNotifications:
          json['direct_message_notifications'] as bool? ?? true,
      fieldUpdateNotifications:
          json['field_update_notifications'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'event_notifications': eventNotifications,
      'meetup_notifications': meetupNotifications,
      'direct_message_notifications': directMessageNotifications,
      'field_update_notifications': fieldUpdateNotifications,
    };
  }

  NotificationPreferencesModel copyWith({
    String? userId,
    bool? eventNotifications,
    bool? meetupNotifications,
    bool? directMessageNotifications,
    bool? fieldUpdateNotifications,
  }) {
    return NotificationPreferencesModel(
      userId: userId ?? this.userId,
      eventNotifications: eventNotifications ?? this.eventNotifications,
      meetupNotifications: meetupNotifications ?? this.meetupNotifications,
      directMessageNotifications:
          directMessageNotifications ?? this.directMessageNotifications,
      fieldUpdateNotifications:
          fieldUpdateNotifications ?? this.fieldUpdateNotifications,
    );
  }
}
