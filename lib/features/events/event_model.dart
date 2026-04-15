class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startsAt,
    this.location,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String description;
  final DateTime startsAt;
  final String? location;
  final String? imageUrl;

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'].toString(),
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      startsAt: DateTime.tryParse((json['starts_at'] ?? '').toString()) ??
          DateTime.now(),
      location: json['location'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}
