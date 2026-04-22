import 'package:supabase_flutter/supabase_flutter.dart';

import 'shop_model.dart';

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
}
