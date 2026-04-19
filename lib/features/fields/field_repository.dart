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

  Future<List<FieldReviewModel>> getFieldReviews(String fieldId) async {
    final response = await _client
        .from('field_reviews')
        .select(
          'id, field_id, user_id, rating, review_text, created_at, profiles:profiles!field_reviews_user_id_fkey(call_sign, avatar_url)',
        )
        .eq('field_id', fieldId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((dynamic row) => FieldReviewModel.fromJson(row))
        .toList();
  }

  Future<void> upsertFieldReview({
    required String fieldId,
    required int rating,
    required String reviewText,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to review fields.');
    }

    await _client.from('field_reviews').upsert({
      'field_id': fieldId,
      'user_id': user.id,
      'rating': rating,
      'review_text': reviewText.trim(),
    }, onConflict: 'field_id,user_id');
  }
}

class FieldReviewModel {
  const FieldReviewModel({
    required this.id,
    required this.fieldId,
    required this.userId,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
    this.callSign,
    this.avatarUrl,
  });

  final String id;
  final String fieldId;
  final String userId;
  final int rating;
  final String reviewText;
  final DateTime createdAt;
  final String? callSign;
  final String? avatarUrl;

  factory FieldReviewModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? profile = json['profiles'] is Map
        ? Map<String, dynamic>.from(json['profiles'] as Map)
        : null;

    return FieldReviewModel(
      id: (json['id'] ?? '').toString(),
      fieldId: (json['field_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      reviewText: (json['review_text'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
      callSign: profile?['call_sign']?.toString(),
      avatarUrl: profile?['avatar_url']?.toString(),
    );
  }
}