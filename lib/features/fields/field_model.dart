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
    this.featuresText,
    this.prosText,
    this.consText,
    this.isOfficial = false,
    this.claimStatus = 'unclaimed',
    this.claimedByUserId,
    this.bookingEnabled = false,
    this.bookingContactName,
    this.bookingPhone,
    this.bookingEmail,
    this.status = 'approved',
    this.submittedByUserId,
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
  final String? featuresText;
  final String? prosText;
  final String? consText;
  final bool isOfficial;
  final String claimStatus;
  final String? claimedByUserId;
  final bool bookingEnabled;
  final String? bookingContactName;
  final String? bookingPhone;
  final String? bookingEmail;
  final String status;
  final String? submittedByUserId;

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
      featuresText: _readNullableString(
        json['feature_list'] ?? json['features'] ?? json['features_text'],
      ),
      prosText: _readNullableString(
        json['pros_list'] ?? json['pros'] ?? json['pros_text'],
      ),
      consText: _readNullableString(
        json['cons_list'] ?? json['cons'] ?? json['cons_text'],
      ),
      isOfficial: (json['is_official'] as bool?) ?? false,
      claimStatus: _readNullableString(json['claim_status']) ?? 'unclaimed',
      claimedByUserId: _readNullableString(json['claimed_by_user_id']),
      bookingEnabled: (json['booking_enabled'] as bool?) ?? false,
      bookingContactName: _readNullableString(json['booking_contact_name']),
      bookingPhone: _readNullableString(json['booking_phone']),
      bookingEmail: _readNullableString(json['booking_email']),
      status: (json['status'] ?? 'approved').toString(),
      submittedByUserId: _readNullableString(json['submitted_by_user_id']),
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

  List<String> get features => _parseCsvLines(featuresText);
  List<String> get pros => _parseCsvLines(prosText);
  List<String> get cons => _parseCsvLines(consText);

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

  static List<String> _parseCsvLines(String? value) {
    final String input = (value ?? '').trim();
    if (input.isEmpty) {
      return const <String>[];
    }

    return input
        .split(RegExp(r'[,\n;|]'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }
}