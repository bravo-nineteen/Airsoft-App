import 'package:supabase_flutter/supabase_flutter.dart';

import 'field_model.dart';

class FieldRepository {
  FieldRepository();

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<FieldModel>> getFields({
    String search = '',
    String location = 'All',
    String fieldType = 'All',
    double minRating = 0,
  }) async {
    final response = await _client
        .from('fields')
        .select()
        .order('name', ascending: true);

    var fields = response.map<FieldModel>((e) => FieldModel.fromJson(e)).toList();

    final trimmedSearch = search.trim().toLowerCase();
    if (trimmedSearch.isNotEmpty) {
      fields = fields.where((field) {
        final haystack = [
          field.name,
          field.locationName,
          field.prefecture ?? '',
          field.city ?? '',
          field.fieldType ?? '',
          field.description,
        ].join(' ').toLowerCase();

        return haystack.contains(trimmedSearch);
      }).toList();
    }

    if (location != 'All') {
      final locationLower = location.toLowerCase();
      fields = fields.where((field) {
        return field.locationName.toLowerCase() == locationLower ||
            (field.prefecture ?? '').toLowerCase() == locationLower ||
            (field.city ?? '').toLowerCase() == locationLower;
      }).toList();
    }

    if (fieldType != 'All') {
      final typeLower = fieldType.toLowerCase();
      fields = fields.where((field) {
        return (field.fieldType ?? '').toLowerCase() == typeLower;
      }).toList();
    }

    if (minRating > 0) {
      fields = fields.where((field) {
        return (field.rating ?? 0) >= minRating;
      }).toList();
    }

    fields.sort((a, b) {
      final ratingCompare = (b.rating ?? 0).compareTo(a.rating ?? 0);
      if (ratingCompare != 0) return ratingCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return fields;
  }
}