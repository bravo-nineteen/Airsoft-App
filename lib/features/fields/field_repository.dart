import 'package:supabase_flutter/supabase_flutter.dart';

import 'field_model.dart';

class FieldRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<FieldModel>> getFields({
    String search = '',
    String location = 'All',
    String fieldType = 'All',
  }) async {
    final response = await _client
        .from('fields')
        .select()
        .order('name', ascending: true);

    var fields = response.map<FieldModel>((e) => FieldModel.fromJson(e)).toList();

    final trimmedSearch = search.trim().toLowerCase();
    if (trimmedSearch.isNotEmpty) {
      fields = fields.where((field) {
        return field.name.toLowerCase().contains(trimmedSearch) ||
            field.locationName.toLowerCase().contains(trimmedSearch) ||
            (field.prefecture ?? '').toLowerCase().contains(trimmedSearch) ||
            (field.city ?? '').toLowerCase().contains(trimmedSearch);
      }).toList();
    }

    if (location != 'All') {
      fields = fields.where((field) {
        return field.locationName == location ||
            field.prefecture == location ||
            field.city == location;
      }).toList();
    }

    if (fieldType != 'All') {
      fields = fields.where((field) => field.fieldType == fieldType).toList();
    }

    return fields;
  }
}
