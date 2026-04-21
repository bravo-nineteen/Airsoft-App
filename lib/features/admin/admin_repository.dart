import 'package:supabase_flutter/supabase_flutter.dart';

import '../community/community_model.dart';
import '../events/event_model.dart';
import '../fields/field_model.dart';
import '../profile/profile_model.dart';

class AdminRepository {
  AdminRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _currentUserId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in.');
    }
    return user.id;
  }

  Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return false;
    }

    try {
      final response = await _client.rpc(
        'is_admin',
        params: <String, dynamic>{'admin_user_id': user.id},
      );
      if (response is bool) {
        return response;
      }
      if (response is num) {
        return response != 0;
      }
      if (response is String) {
        return response.toLowerCase() == 'true';
      }
    } catch (_) {
      // Fall through to direct table lookup.
    }

    try {
      final response = await _client
          .from('admin_roles')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  Future<AdminBanRecord?> getActiveBanForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    final response = await _client
        .from('user_bans')
        .select()
        .eq('user_id', user.id)
        .isFilter('revoked_at', null)
        .order('created_at', ascending: false);

    final bans = (response as List<dynamic>)
        .map(
          (dynamic row) =>
              AdminBanRecord.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();

    final now = DateTime.now().toUtc();
    for (final ban in bans) {
      if (ban.isPermanent) {
        return ban;
      }
      if (ban.bannedUntil != null && ban.bannedUntil!.isAfter(now)) {
        return ban;
      }
    }

    return null;
  }

  Future<List<CommunityPostModel>> getRecentPosts({int limit = 25}) async {
    final response = await _client
        .from('community_posts')
        .select()
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map(
          (dynamic row) => CommunityPostModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<CommunityCommentModel>> getRecentComments({
    int limit = 25,
  }) async {
    final response = await _client
        .from('community_comments')
        .select(
          'id, created_at, post_id, author_id, user_id, author_name, author_avatar_url, message, body, like_count',
        )
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map(
          (dynamic row) => CommunityCommentModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<EventModel>> getRecentEvents({int limit = 25}) async {
    final response = await _client
        .from('events')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map(
          (dynamic row) =>
              EventModel.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<FieldModel>> getRecentFields({int limit = 25}) async {
    final response = await _client
        .from('fields')
        .select()
        .order('updated_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map(
          (dynamic row) =>
              FieldModel.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<ProfileModel>> searchProfiles(String query) async {
    final trimmed = query.trim().toLowerCase();
    final response = await _client
        .from('profiles')
        .select()
        .order('updated_at', ascending: false)
        .limit(trimmed.isEmpty ? 25 : 100);

    final profiles = (response as List<dynamic>)
        .map(
          (dynamic row) =>
              ProfileModel.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();

    if (trimmed.isEmpty) {
      return profiles;
    }

    return profiles.where((profile) {
      final haystack = [
        profile.callSign,
        profile.userCode,
        profile.area ?? '',
        profile.teamName ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(trimmed);
    }).toList();
  }

  Future<List<AdminBanRecord>> getRecentBans({int limit = 50}) async {
    final response = await _client
        .from('user_bans')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map(
          (dynamic row) =>
              AdminBanRecord.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> deletePost(String postId) async {
    await _client.from('community_posts').delete().eq('id', postId);
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('community_comments').delete().eq('id', commentId);
  }

  Future<void> deleteEvent(String eventId) async {
    await _client.from('events').delete().eq('id', eventId);
  }

  Future<void> issueBan({
    required String userId,
    required String reason,
    required bool isPermanent,
    DateTime? bannedUntil,
  }) async {
    await _client.from('user_bans').insert({
      'user_id': userId,
      'issued_by': _currentUserId,
      'reason': reason.trim().isEmpty ? null : reason.trim(),
      'is_permanent': isPermanent,
      'banned_until': isPermanent
          ? null
          : bannedUntil?.toUtc().toIso8601String(),
    });
  }

  Future<void> revokeBan(String banId) async {
    await _client
        .from('user_bans')
        .update({
          'revoked_at': DateTime.now().toUtc().toIso8601String(),
          'revoked_by': _currentUserId,
        })
        .eq('id', banId);
  }

  Future<void> createOfficialField({
    required String name,
    required String locationName,
    required String description,
    required double latitude,
    required double longitude,
    String? prefecture,
    String? city,
    String? fieldType,
    String? imageUrl,
    String? featuresText,
    String? prosText,
    String? consText,
  }) async {
    final Map<String, dynamic> payload = {
      'name': name.trim(),
      'location_name': locationName.trim(),
      'description': description.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'prefecture': _nullIfEmpty(prefecture),
      'city': _nullIfEmpty(city),
      'field_type': _nullIfEmpty(fieldType),
      'image_url': _nullIfEmpty(imageUrl),
      'feature_list': _nullIfEmpty(featuresText),
      'pros_list': _nullIfEmpty(prosText),
      'cons_list': _nullIfEmpty(consText),
      'is_official': true,
    };

    try {
      await _client.from('fields').insert(payload);
    } on PostgrestException catch (error) {
      if (!_isMissingFieldMetaColumnError(error)) {
        rethrow;
      }
      payload.remove('feature_list');
      payload.remove('pros_list');
      payload.remove('cons_list');
      await _client.from('fields').insert(payload);
    }
  }

  Future<void> updateField({
    required String fieldId,
    required String name,
    required String locationName,
    required String description,
    required double latitude,
    required double longitude,
    String? prefecture,
    String? city,
    String? fieldType,
    String? imageUrl,
    String? featuresText,
    String? prosText,
    String? consText,
    bool isOfficial = true,
  }) async {
    final Map<String, dynamic> payload = {
          'name': name.trim(),
          'location_name': locationName.trim(),
          'description': description.trim(),
          'latitude': latitude,
          'longitude': longitude,
          'prefecture': _nullIfEmpty(prefecture),
          'city': _nullIfEmpty(city),
          'field_type': _nullIfEmpty(fieldType),
          'image_url': _nullIfEmpty(imageUrl),
          'feature_list': _nullIfEmpty(featuresText),
          'pros_list': _nullIfEmpty(prosText),
          'cons_list': _nullIfEmpty(consText),
          'is_official': isOfficial,
        };

    try {
      await _client.from('fields').update(payload).eq('id', fieldId);
    } on PostgrestException catch (error) {
      if (!_isMissingFieldMetaColumnError(error)) {
        rethrow;
      }
      payload.remove('feature_list');
      payload.remove('pros_list');
      payload.remove('cons_list');
      await _client.from('fields').update(payload).eq('id', fieldId);
    }
  }

  Future<List<FieldClaimRequestRecord>> getPendingFieldClaimRequests({
    int limit = 50,
  }) async {
    final response = await _client
        .from('field_claim_requests')
        .select('*, fields:field_id(name)')
        .eq('verification_status', 'pending')
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map(
          (dynamic row) => FieldClaimRequestRecord.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<FieldClaimRequestRecord>> getReviewedFieldClaimRequests({
    int limit = 100,
  }) async {
    final response = await _client
        .from('field_claim_requests')
        .select('*, fields:field_id(name)')
        .inFilter('verification_status', <String>['approved', 'rejected'])
        .order('reviewed_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map(
          (dynamic row) => FieldClaimRequestRecord.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<void> approveFieldClaimRequest(FieldClaimRequestRecord request) async {
    final String now = DateTime.now().toUtc().toIso8601String();

    await _client
        .from('field_claim_requests')
        .update({
          'verification_status': 'approved',
          'payment_status': 'paid',
          'reviewed_by': _currentUserId,
          'reviewed_at': now,
        })
        .eq('id', request.id);

    await _client
        .from('fields')
        .update({
          'claim_status': 'verified',
          'claimed_by_user_id': request.requesterUserId,
          'claim_verified_at': now,
          'booking_enabled': true,
          'booking_contact_name': request.staffName,
          'booking_phone': request.officialPhone,
          'booking_email': request.officialEmail,
        })
        .eq('id', request.fieldId);
  }

  Future<void> rejectFieldClaimRequest(String claimRequestId) async {
    await _client
        .from('field_claim_requests')
        .update({
          'verification_status': 'rejected',
          'reviewed_by': _currentUserId,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', claimRequestId);
  }

  String? _nullIfEmpty(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _isMissingFieldMetaColumnError(PostgrestException error) {
    if (error.code != 'PGRST204' && error.code != '42703') {
      return false;
    }
    final String summary =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    return summary.contains('feature_list') ||
        summary.contains('pros_list') ||
        summary.contains('cons_list');
  }
}

class AdminBanRecord {
  const AdminBanRecord({
    required this.id,
    required this.userId,
    required this.issuedBy,
    required this.isPermanent,
    required this.createdAt,
    this.reason,
    this.bannedUntil,
    this.revokedAt,
    this.revokedBy,
  });

  final String id;
  final String userId;
  final String? issuedBy;
  final String? reason;
  final bool isPermanent;
  final DateTime createdAt;
  final DateTime? bannedUntil;
  final DateTime? revokedAt;
  final String? revokedBy;

  bool get isRevoked => revokedAt != null;

  factory AdminBanRecord.fromJson(Map<String, dynamic> json) {
    return AdminBanRecord(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      issuedBy: json['issued_by']?.toString(),
      reason: json['reason']?.toString(),
      isPermanent: json['is_permanent'] == true,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString())?.toUtc() ??
          DateTime.now().toUtc(),
      bannedUntil: json['banned_until'] == null
          ? null
          : DateTime.tryParse(json['banned_until'].toString())?.toUtc(),
      revokedAt: json['revoked_at'] == null
          ? null
          : DateTime.tryParse(json['revoked_at'].toString())?.toUtc(),
      revokedBy: json['revoked_by']?.toString(),
    );
  }
}

class FieldClaimRequestRecord {
  const FieldClaimRequestRecord({
    required this.id,
    required this.fieldId,
    required this.requesterUserId,
    required this.staffName,
    this.fieldName,
    required this.officialIdNumber,
    required this.officialPhone,
    required this.officialEmail,
    required this.verificationStatus,
    required this.paymentStatus,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
  });

  final String id;
  final String fieldId;
  final String requesterUserId;
  final String staffName;
  final String? fieldName;
  final String officialIdNumber;
  final String officialPhone;
  final String officialEmail;
  final String verificationStatus;
  final String paymentStatus;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  factory FieldClaimRequestRecord.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? fieldJson = json['fields'] is Map
        ? Map<String, dynamic>.from(json['fields'] as Map)
        : null;

    return FieldClaimRequestRecord(
      id: (json['id'] ?? '').toString(),
      fieldId: (json['field_id'] ?? '').toString(),
      requesterUserId: (json['requester_user_id'] ?? '').toString(),
      staffName: (json['staff_name'] ?? '').toString(),
      fieldName: fieldJson?['name']?.toString(),
      officialIdNumber: (json['official_id_number'] ?? '').toString(),
      officialPhone: (json['official_phone'] ?? '').toString(),
      officialEmail: (json['official_email'] ?? '').toString(),
      verificationStatus: (json['verification_status'] ?? '').toString(),
      paymentStatus: (json['payment_status'] ?? '').toString(),
        reviewedBy: json['reviewed_by']?.toString(),
        reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.tryParse(json['reviewed_at'].toString())?.toUtc(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString())?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}
