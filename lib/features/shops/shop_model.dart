class ShopModel {
  const ShopModel({
    required this.id,
    required this.name,
    required this.address,
    this.country,
    this.prefecture,
    this.city,
    this.openingTimes,
    this.phoneNumber,
    this.featuresText,
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.isOfficial = false,
    this.status = 'approved',
    this.submittedByUserId,
  });

  final String id;
  final String name;
  final String address;
  final String? country;
  final String? prefecture;
  final String? city;
  final String? openingTimes;
  final String? phoneNumber;
  final String? featuresText;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final bool isOfficial;
  final String status;
  final String? submittedByUserId;

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      country: _readNullable(json['country']),
      prefecture: _readNullable(json['prefecture']),
      city: _readNullable(json['city']),
      openingTimes: _readNullable(json['opening_times']),
      phoneNumber: _readNullable(json['phone_number']),
      featuresText: _readNullable(json['features']),
      imageUrl: _readNullable(json['image_url']),
      latitude: _readDouble(json['latitude']),
      longitude: _readDouble(json['longitude']),
      isOfficial: (json['is_official'] as bool?) ?? false,
      status: (json['status'] ?? 'approved').toString(),
      submittedByUserId: _readNullable(json['submitted_by_user_id']),
    );
  }

  bool get hasImage => (imageUrl ?? '').trim().isNotEmpty;

  String get locationDisplay {
    final parts = <String>[
      if ((prefecture ?? '').trim().isNotEmpty) prefecture!.trim(),
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
    ];
    return parts.isEmpty ? address : parts.join(', ');
  }

  List<String> get features {
    final String input = (featuresText ?? '').trim();
    if (input.isEmpty) return const [];
    return input
        .split(RegExp(r'[\n,]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String? _readNullable(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
