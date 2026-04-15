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
    this.rating,
    this.reviewCount,
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
  final double? rating;
  final int? reviewCount;

  factory FieldModel.fromJson(Map<String, dynamic> json) {
    return FieldModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      locationName: (json['location_name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      prefecture: _readNullableString(json['prefecture']),
      city: _readNullableString(json['city']),
      fieldType: _readNullableString(json['field_type']),
      imageUrl: _readNullableString(json['image_url']),
      rating: _readNullableDouble(json['rating']),
      reviewCount: _readNullableInt(json['review_count']),
    );
  }

  String get fullLocation {
    final parts = <String>[
      if ((locationName).trim().isNotEmpty) locationName.trim(),
      if ((prefecture ?? '').trim().isNotEmpty) prefecture!.trim(),
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
    ];

    return parts.toSet().join(' • ');
  }

  bool get hasImage => (imageUrl ?? '').trim().isNotEmpty;

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double? _readNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _readNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}