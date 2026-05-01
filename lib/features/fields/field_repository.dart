import 'package:supabase_flutter/supabase_flutter.dart';

import 'field_model.dart';

class FieldRepository {
  FieldRepository();

  final SupabaseClient _client = Supabase.instance.client;

  String get _currentUserId {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in.');
    }
    return user.id;
  }

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

    final List<FieldModel> fields = response
        .map<FieldModel>((e) => FieldModel.fromJson(e))
        .toList();

    return applyFilters(
      fields,
      search: search,
      location: location,
      fieldType: fieldType,
      minRating: minRating,
    );
  }

  List<FieldModel> applyFilters(
    List<FieldModel> source, {
    String search = '',
    String location = 'All',
    String fieldType = 'All',
    double minRating = 0,
  }) {
    var fields = List<FieldModel>.from(source);

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

  Future<void> updateFieldReview({
    required String reviewId,
    required int rating,
    required String reviewText,
  }) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to edit reviews.');
    }

    await _client
        .from('field_reviews')
        .update({
          'rating': rating,
          'review_text': reviewText.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', reviewId)
        .eq('user_id', user.id);
  }

  Future<void> deleteFieldReview(String reviewId) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to delete reviews.');
    }

    await _client
        .from('field_reviews')
        .delete()
        .eq('id', reviewId)
        .eq('user_id', user.id);
  }

  Future<void> submitFieldClaimRequest({
    required String fieldId,
    required String staffName,
    required String officialIdNumber,
    String? officialIdImageUrl,
    required String officialPhone,
    required String officialEmail,
    String? verificationNote,
    String paymentPlatform = 'google_play',
  }) async {
    final String requesterId = _currentUserId;

    await _client.from('field_claim_requests').insert({
      'field_id': fieldId,
      'requester_user_id': requesterId,
      'staff_name': staffName.trim(),
      'official_id_number': officialIdNumber.trim(),
      'official_id_image_url': _nullIfEmpty(officialIdImageUrl),
      'official_phone': officialPhone.trim(),
      'official_email': officialEmail.trim(),
      'verification_note': _nullIfEmpty(verificationNote),
      'payment_amount_yen': 5000,
      'payment_platform': paymentPlatform,
      'payment_status': 'pending',
      'verification_status': 'pending',
    });

    await _client
        .from('fields')
        .update({'claim_status': 'pending'})
        .eq('id', fieldId)
        .neq('claim_status', 'verified');
  }

  Future<List<FieldBookingOptionModel>> getBookingOptions(String fieldId) async {
    final response = await _client
        .from('field_booking_options')
        .select()
        .eq('field_id', fieldId)
        .eq('is_active', true)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    return (response as List<dynamic>)
        .map(
          (dynamic row) =>
              FieldBookingOptionModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<void> addBookingOption({
    required String fieldId,
    required String optionType,
    required String label,
    int? priceYen,
  }) async {
    await _client.from('field_booking_options').insert({
      'field_id': fieldId,
      'option_type': optionType,
      'label': label.trim(),
      'price_yen': priceYen,
    });
  }

  Future<void> createBookingRequest({
    required String fieldId,
    required String bookingName,
    required String bookingPhone,
    required String bookingEmail,
    required String message,
    required List<FieldBookingOptionModel> selectedOptions,
  }) async {
    await _client.from('field_bookings').insert({
      'field_id': fieldId,
      'user_id': _currentUserId,
      'booking_name': bookingName.trim(),
      'booking_phone': bookingPhone.trim(),
      'booking_email': bookingEmail.trim(),
      'message': message.trim(),
      'selected_options': selectedOptions
          .map(
            (FieldBookingOptionModel option) => {
              'id': option.id,
              'label': option.label,
              'type': option.optionType,
              'price_yen': option.priceYen,
            },
          )
          .toList(),
      'status': 'pending',
    });
  }

  Future<List<FieldBookingRequestModel>> getBookingsForField(String fieldId) async {
    final response = await _client
        .from('field_bookings')
        .select()
        .eq('field_id', fieldId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map(
          (dynamic row) =>
              FieldBookingRequestModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    await _client
        .from('field_bookings')
        .update({'status': status})
        .eq('id', bookingId);
  }

  String? _nullIfEmpty(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Returns a list of photo URLs for the given field.
  /// Queries the `field_photos` table if it exists; falls back to the
  /// single `image_url` column on the field row.
  Future<List<String>> getFieldPhotos(String fieldId) async {
    try {
      final rows = await _client
          .from('field_photos')
          .select('photo_url')
          .eq('field_id', fieldId)
          .order('created_at', ascending: true);
      final urls = rows
          .map<String>((r) => (r['photo_url'] ?? '').toString())
          .where((u) => u.isNotEmpty)
          .toList();
      return urls;
    } on PostgrestException catch (e) {
      // Table does not exist yet — return empty list gracefully.
      if (e.code == '42P01' || e.code == 'PGRST205') return const [];
      rethrow;
    }
  }

  /// Uploads a photo for a field (field managers only).
  Future<void> addFieldPhoto({
    required String fieldId,
    required String photoUrl,
  }) async {
    await _client.from('field_photos').insert({
      'field_id': fieldId,
      'photo_url': photoUrl,
      'uploaded_by': _currentUserId,
    });
  }

  // ─── User submissions ──────────────────────────────────────────────────────

  /// Submit a new field for admin review (status will be set to 'pending' by
  /// the database trigger).
  Future<void> submitField({
    required String name,
    required String locationName,
    String? country,
    String? prefecture,
    String? city,
    String? fieldType,
    String? description,
    double? latitude,
    double? longitude,
  }) async {
    await _client.from('fields').insert(<String, dynamic>{
      'name': name.trim(),
      'location_name': locationName.trim(),
      'country': _nullIfEmpty(country),
      'description': (description ?? '').trim(),
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
      'prefecture': _nullIfEmpty(prefecture),
      'city': _nullIfEmpty(city),
      'field_type': _nullIfEmpty(fieldType),
    });
  }

  /// Returns the current user's own field submissions (pending / rejected).
  Future<List<FieldModel>> getMyFieldSubmissions() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final response = await _client
        .from('fields')
        .select()
        .eq('submitted_by_user_id', user.id)
        .order('created_at', ascending: false);
    return (response as List<dynamic>)
        .map<FieldModel>((e) => FieldModel.fromJson(e))
        .toList();
  }
}

class FieldBookingOptionModel {
  const FieldBookingOptionModel({
    required this.id,
    required this.fieldId,
    required this.optionType,
    required this.label,
    this.priceYen,
    required this.isActive,
  });

  final String id;
  final String fieldId;
  final String optionType;
  final String label;
  final int? priceYen;
  final bool isActive;

  factory FieldBookingOptionModel.fromJson(Map<String, dynamic> json) {
    return FieldBookingOptionModel(
      id: (json['id'] ?? '').toString(),
      fieldId: (json['field_id'] ?? '').toString(),
      optionType: (json['option_type'] ?? 'other').toString(),
      label: (json['label'] ?? '').toString(),
      priceYen: (json['price_yen'] as num?)?.toInt(),
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}

class FieldBookingRequestModel {
  const FieldBookingRequestModel({
    required this.id,
    required this.fieldId,
    this.userId,
    required this.bookingName,
    required this.bookingPhone,
    required this.bookingEmail,
    required this.message,
    required this.selectedOptions,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String fieldId;
  final String? userId;
  final String bookingName;
  final String bookingPhone;
  final String bookingEmail;
  final String message;
  final List<Map<String, dynamic>> selectedOptions;
  final String status;
  final DateTime createdAt;

  factory FieldBookingRequestModel.fromJson(Map<String, dynamic> json) {
    final dynamic selectedRaw = json['selected_options'];
    final List<Map<String, dynamic>> options = (selectedRaw is List)
        ? selectedRaw
              .map((dynamic item) {
                if (item is Map<String, dynamic>) {
                  return item;
                }
                if (item is Map) {
                  return Map<String, dynamic>.from(item);
                }
                return <String, dynamic>{'label': item.toString()};
              })
              .toList()
        : const <Map<String, dynamic>>[];

    return FieldBookingRequestModel(
      id: (json['id'] ?? '').toString(),
      fieldId: (json['field_id'] ?? '').toString(),
      userId: json['user_id']?.toString(),
      bookingName: (json['booking_name'] ?? '').toString(),
      bookingPhone: (json['booking_phone'] ?? '').toString(),
      bookingEmail: (json['booking_email'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      selectedOptions: options,
      status: (json['status'] ?? 'pending').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
    );
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
