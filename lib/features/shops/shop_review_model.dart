class ShopReviewModel {
  const ShopReviewModel({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.rating,
    this.body,
    this.callSign,
    required this.createdAt,
  });

  final String id;
  final String shopId;
  final String userId;
  final int rating;
  final String? body;
  final String? callSign;
  final DateTime createdAt;

  factory ShopReviewModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return ShopReviewModel(
      id: (json['id'] ?? '').toString(),
      shopId: (json['shop_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      body: json['body'] as String?,
      callSign: profile?['call_sign'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
