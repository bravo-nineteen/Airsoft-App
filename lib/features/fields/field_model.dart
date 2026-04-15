class FieldModel {
  const FieldModel({
    required this.id,
    required this.name,
    required this.locationName,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.prefecture,
    this.city,
    this.fieldType,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String locationName;
  final String description;
  final double latitude;
  final double longitude;
  final String? prefecture;
  final String? city;
  final String? fieldType;
  final String? imageUrl;

  factory FieldModel.fromJson(Map<String, dynamic> json) {
    return FieldModel(
      id: json['id'].toString(),
      name: (json['name'] ?? '') as String,
      locationName: (json['location_name'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      prefecture: json['prefecture'] as String?,
      city: json['city'] as String?,
      fieldType: json['field_type'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}
