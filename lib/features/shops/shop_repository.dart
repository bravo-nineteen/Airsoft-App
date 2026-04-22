import 'package:supabase_flutter/supabase_flutter.dart';

import 'shop_model.dart';
import 'shop_review_model.dart';

class ShopRepository {
  ShopRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<ShopModel>> getShops() async {
    try {
      final response = await _client
          .from('shops')
          .select()
          .order('name', ascending: true);

      return response.map<ShopModel>((e) => ShopModel.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      if (_isMissingTableError(e)) return const [];
      rethrow;
    }
  }

  List<ShopModel> applyFilters(
    List<ShopModel> source, {
    String search = '',
    String prefecture = 'All',
  }) {
    var shops = List<ShopModel>.from(source);

    final trimmed = search.trim().toLowerCase();
    if (trimmed.isNotEmpty) {
      shops = shops.where((s) {
        final haystack = [
          s.name,
          s.address,
          s.prefecture ?? '',
          s.city ?? '',
          s.featuresText ?? '',
        ].join(' ').toLowerCase();
        return haystack.contains(trimmed);
      }).toList();
    }

    if (prefecture != 'All') {
      final pfLower = prefecture.toLowerCase();
      shops = shops.where((s) {
        return (s.prefecture ?? '').toLowerCase() == pfLower ||
            (s.city ?? '').toLowerCase() == pfLower;
      }).toList();
    }

    return shops;
  }

  static bool _isMissingTableError(PostgrestException e) {
    return e.code == '42P01' || e.code == 'PGRST205';
  }

  Future<List<ShopReviewModel>> getShopReviews(String shopId) async {
    try {
      final response = await _client
          .from('shop_reviews')
          .select('*, profiles(call_sign)')
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);
      return response
          .map<ShopReviewModel>((e) => ShopReviewModel.fromJson(e))
          .toList();
    } on PostgrestException catch (e) {
      if (_isMissingTableError(e)) return const [];
      rethrow;
    }
  }

  Future<void> submitShopReview({
    required String shopId,
    required int rating,
    String? body,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated.');

    await _client.from('shop_reviews').upsert({
      'shop_id': shopId,
      'user_id': userId,
      'rating': rating,
      'body': body?.trim().isEmpty == true ? null : body?.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'shop_id,user_id');
  }

  Future<void> deleteShopReview({required String reviewId}) async {
    await _client.from('shop_reviews').delete().eq('id', reviewId);
  }
}
