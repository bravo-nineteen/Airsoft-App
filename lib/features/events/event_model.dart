class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
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
  });

  final String id;
  final String title;
  final String description;
  final DateTime startsAt;
  final DateTime endsAt;
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

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final startsAt =
        DateTime.tryParse((json['starts_at'] ?? '').toString()) ??
        DateTime.now();

    final endsAt =
        DateTime.tryParse((json['ends_at'] ?? '').toString()) ??
        startsAt.add(const Duration(hours: 6));

    return EventModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      startsAt: startsAt,
      endsAt: endsAt,
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
    );
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
    }

  static int? _readNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}