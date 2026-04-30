import 'package:supabase_flutter/supabase_flutter.dart';

import '../community/community_model.dart';
import '../events/event_model.dart';
import '../fields/field_model.dart';
import '../profile/profile_model.dart';
import '../shops/shop_model.dart';

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

  Future<List<ShopModel>> getRecentShops({int limit = 25}) async {
    final response = await _client
        .from('shops')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map(
          (dynamic row) =>
              ShopModel.fromJson(Map<String, dynamic>.from(row as Map)),
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

  Future<void> createOfficialShop({
    required String name,
    required String address,
    String? prefecture,
    String? city,
    String? openingTimes,
    String? phoneNumber,
    String? featuresText,
    String? imageUrl,
    double? latitude,
    double? longitude,
  }) async {
    await _client.from('shops').insert({
      'name': name.trim(),
      'address': address.trim(),
      'prefecture': _nullIfEmpty(prefecture),
      'city': _nullIfEmpty(city),
      'opening_times': _nullIfEmpty(openingTimes),
      'phone_number': _nullIfEmpty(phoneNumber),
      'features': _nullIfEmpty(featuresText),
      'image_url': _nullIfEmpty(imageUrl),
      'latitude': latitude,
      'longitude': longitude,
      'is_official': true,
    });
  }

  Future<void> updateShop({
    required String shopId,
    required String name,
    required String address,
    String? prefecture,
    String? city,
    String? openingTimes,
    String? phoneNumber,
    String? featuresText,
    String? imageUrl,
    double? latitude,
    double? longitude,
    bool isOfficial = true,
  }) async {
    await _client
        .from('shops')
        .update({
          'name': name.trim(),
          'address': address.trim(),
          'prefecture': _nullIfEmpty(prefecture),
          'city': _nullIfEmpty(city),
          'opening_times': _nullIfEmpty(openingTimes),
          'phone_number': _nullIfEmpty(phoneNumber),
          'features': _nullIfEmpty(featuresText),
          'image_url': _nullIfEmpty(imageUrl),
          'latitude': latitude,
          'longitude': longitude,
          'is_official': isOfficial,
        })
        .eq('id', shopId);
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

  Future<List<SafetyReportRecord>> getSafetyReports({
    int limit = 100,
    String? status,
  }) async {
    dynamic query = _client
        .from('safety_reports')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    if ((status ?? '').trim().isNotEmpty) {
      query = query.eq('status', status!.trim());
    }

    final dynamic response = await query;
    return (response as List<dynamic>)
        .map(
          (dynamic row) => SafetyReportRecord.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<ModerationQueueRecord>> getModerationQueue({
    int limit = 100,
    String? status,
  }) async {
    dynamic query = _client
        .from('moderation_queue')
        .select()
        .order('created_at', ascending: true)
        .limit(limit);

    if ((status ?? '').trim().isNotEmpty) {
      query = query.eq('status', status!.trim());
    }

    final dynamic response = await query;
    return (response as List<dynamic>)
        .map(
          (dynamic row) => ModerationQueueRecord.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<ModerationAuditLogRecord>> getModerationAuditLogs({
    int limit = 100,
  }) async {
    final dynamic response = await _client
        .from('moderation_audit_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map(
          (dynamic row) => ModerationAuditLogRecord.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<void> reviewSafetyReport({
    required SafetyReportRecord report,
    required String reportStatus,
    String? queueItemId,
    String? note,
  }) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('safety_reports')
        .update({
          'status': reportStatus,
          'reviewed_by': _currentUserId,
          'reviewed_at': now,
          'updated_at': now,
        })
        .eq('id', report.id);

    if ((queueItemId ?? '').trim().isNotEmpty) {
      final String queueStatus =
          reportStatus == 'open' || reportStatus == 'triaged'
          ? 'in_review'
          : 'resolved';
      await _client
          .from('moderation_queue')
          .update({
            'status': queueStatus,
            'assigned_to': _currentUserId,
            'updated_at': now,
          })
          .eq('id', queueItemId!);
    }

    await _client.from('moderation_audit_logs').insert({
      'moderator_user_id': _currentUserId,
      'action': 'report_status_$reportStatus',
      'target_type': report.targetType,
      'target_id': report.targetId,
      'report_id': report.id,
      'notes': _nullIfEmpty(note),
      'created_at': now,
    });

    if (report.reporterUserId != _currentUserId) {
      final String statusLabel = switch (reportStatus) {
        'triaged' => 'triaged',
        'actioned' => 'actioned',
        'dismissed' => 'dismissed',
        _ => reportStatus,
      };
      final String targetLabel = report.targetType.isEmpty
          ? 'content'
          : report.targetType;
      await _client.from('notifications').insert({
        'user_id': report.reporterUserId,
        'actor_user_id': _currentUserId,
        'type': 'moderation_report_$statusLabel',
        'entity_id': report.id,
        'title': 'Report update',
        'body': 'Your report for $targetLabel has been marked as $statusLabel.',
        'is_read': false,
      });
    }
  }

  Future<void> assignQueueItemToMe(String queueItemId) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('moderation_queue')
        .update({
          'assigned_to': _currentUserId,
          'status': 'in_review',
          'updated_at': now,
        })
        .eq('id', queueItemId);

    await _client.from('moderation_audit_logs').insert({
      'moderator_user_id': _currentUserId,
      'action': 'queue_assigned',
      'target_type': 'moderation_queue',
      'target_id': queueItemId,
      'notes': 'Assigned queue item to current moderator',
      'created_at': now,
    });
  }

  Future<void> updateQueueItemStatus({
    required String queueItemId,
    required String status,
  }) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('moderation_queue')
        .update({'status': status, 'updated_at': now})
        .eq('id', queueItemId);

    await _client.from('moderation_audit_logs').insert({
      'moderator_user_id': _currentUserId,
      'action': 'queue_status_$status',
      'target_type': 'moderation_queue',
      'target_id': queueItemId,
      'notes': 'Queue status changed to $status',
      'created_at': now,
    });
  }

  Future<ModerationTargetPreview?> getTargetPreview({
    required String targetType,
    required String? targetId,
  }) async {
    final String id = (targetId ?? '').trim();
    if (id.isEmpty) {
      return null;
    }

    try {
      if (targetType == 'post') {
        final Map<String, dynamic>? row = await _client
            .from('community_posts')
            .select('id, title, plain_text, author_name, created_at')
            .eq('id', id)
            .maybeSingle();
        if (row == null) {
          return null;
        }
        return ModerationTargetPreview(
          title: row['title']?.toString() ?? 'Post',
          subtitle: row['author_name']?.toString(),
          body: row['plain_text']?.toString(),
          createdAt: DateTime.tryParse(
            (row['created_at'] ?? '').toString(),
          )?.toUtc(),
        );
      }

      if (targetType == 'comment') {
        final Map<String, dynamic>? row = await _client
            .from('community_comments')
            .select('id, message, author_name, created_at')
            .eq('id', id)
            .maybeSingle();
        if (row == null) {
          return null;
        }
        return ModerationTargetPreview(
          title: 'Comment',
          subtitle: row['author_name']?.toString(),
          body: row['message']?.toString(),
          createdAt: DateTime.tryParse(
            (row['created_at'] ?? '').toString(),
          )?.toUtc(),
        );
      }

      if (targetType == 'event') {
        final Map<String, dynamic>? row = await _client
            .from('events')
            .select('id, title, description, created_at')
            .eq('id', id)
            .maybeSingle();
        if (row == null) {
          return null;
        }
        return ModerationTargetPreview(
          title: row['title']?.toString() ?? 'Event',
          subtitle: null,
          body: row['description']?.toString(),
          createdAt: DateTime.tryParse(
            (row['created_at'] ?? '').toString(),
          )?.toUtc(),
        );
      }

      if (targetType == 'dm') {
        final Map<String, dynamic>? row = await _client
            .from('direct_messages')
            .select('id, body, sender_id, recipient_id, created_at')
            .eq('id', id)
            .maybeSingle();
        if (row == null) {
          return null;
        }
        return ModerationTargetPreview(
          title: 'Direct Message',
          subtitle:
              '${row['sender_id'] ?? '-'} -> ${row['recipient_id'] ?? '-'}',
          body: row['body']?.toString(),
          createdAt: DateTime.tryParse(
            (row['created_at'] ?? '').toString(),
          )?.toUtc(),
        );
      }

      if (targetType == 'user') {
        final Map<String, dynamic>? row = await _client
            .from('profiles')
            .select('id, call_sign, user_code, bio, updated_at')
            .eq('id', id)
            .maybeSingle();
        if (row == null) {
          return null;
        }
        return ModerationTargetPreview(
          title: row['call_sign']?.toString() ?? 'User',
          subtitle: row['user_code']?.toString(),
          body: row['bio']?.toString(),
          createdAt: DateTime.tryParse(
            (row['updated_at'] ?? '').toString(),
          )?.toUtc(),
        );
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  // ── Membership requests ──────────────────────────────────────────────────

  Future<List<MembershipRequestRecord>> getMembershipRequests({
    int limit = 50,
  }) async {
    final response = await _client
        .from('ad_free_membership_requests')
        .select()
        .inFilter('status', <String>['pending', 'payment_requested'])
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map(
          (dynamic row) => MembershipRequestRecord.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<MembershipRequestRecord>> getReviewedMembershipRequests({
    int limit = 100,
  }) async {
    final response = await _client
        .from('ad_free_membership_requests')
        .select()
        .inFilter('status', <String>['approved', 'rejected', 'active', 'expired'])
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map(
          (dynamic row) => MembershipRequestRecord.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<void> sendMembershipPaymentRequest(
    String requestId, {
    String? adminNote,
  }) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    final Map<String, dynamic> payload = {
      'status': 'payment_requested',
      'reviewed_by': _currentUserId,
      'reviewed_at': now,
      'payment_request_sent_at': now,
    };
    if ((adminNote ?? '').trim().isNotEmpty) {
      payload['admin_note'] = adminNote!.trim();
    }
    await _client
        .from('ad_free_membership_requests')
        .update(payload)
        .eq('id', requestId);
  }

  Future<void> rejectMembershipRequest(
    String requestId, {
    String? adminNote,
  }) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    final Map<String, dynamic> payload = {
      'status': 'rejected',
      'reviewed_by': _currentUserId,
      'reviewed_at': now,
    };
    if ((adminNote ?? '').trim().isNotEmpty) {
      payload['admin_note'] = adminNote!.trim();
    }
    await _client
        .from('ad_free_membership_requests')
        .update(payload)
        .eq('id', requestId);
  }

  Future<void> activateMembership(String requestId) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    final String expiresAt = DateTime.now()
        .toUtc()
        .add(const Duration(days: 365))
        .toIso8601String();
    await _client
        .from('ad_free_membership_requests')
        .update({
          'status': 'active',
          'activated_at': now,
          'expires_at': expiresAt,
          'reviewed_by': _currentUserId,
          'reviewed_at': now,
        })
        .eq('id', requestId);
  }

  // ── Field claim payment step ──────────────────────────────────────────────

  Future<void> requestFieldClaimPayment(String claimId) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('field_claim_requests')
        .update({
          'verification_status': 'approved',
          'payment_status': 'payment_requested',
          'reviewed_by': _currentUserId,
          'reviewed_at': now,
        })
        .eq('id', claimId);
  }

  Future<List<FieldClaimRequestRecord>> getPaymentRequestedFieldClaimRequests({
    int limit = 50,
  }) async {
    final response = await _client
        .from('field_claim_requests')
        .select('*, fields:field_id(name)')
        .eq('verification_status', 'approved')
        .eq('payment_status', 'payment_requested')
        .order('reviewed_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map(
          (dynamic row) => FieldClaimRequestRecord.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
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

class SafetyReportRecord {
  const SafetyReportRecord({
    required this.id,
    required this.reporterUserId,
    required this.targetType,
    required this.reasonCategory,
    required this.status,
    required this.createdAt,
    this.targetId,
    this.details,
    this.reviewedBy,
    this.reviewedAt,
  });

  final String id;
  final String reporterUserId;
  final String targetType;
  final String? targetId;
  final String reasonCategory;
  final String? details;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  factory SafetyReportRecord.fromJson(Map<String, dynamic> json) {
    return SafetyReportRecord(
      id: (json['id'] ?? '').toString(),
      reporterUserId: (json['reporter_user_id'] ?? '').toString(),
      targetType: (json['target_type'] ?? '').toString(),
      targetId: json['target_id']?.toString(),
      reasonCategory: (json['reason_category'] ?? '').toString(),
      details: json['details']?.toString(),
      status: (json['status'] ?? '').toString(),
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

class ModerationQueueRecord {
  const ModerationQueueRecord({
    required this.id,
    required this.targetType,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.reportId,
    this.targetId,
    this.assignedTo,
    this.updatedAt,
  });

  final String id;
  final String? reportId;
  final String targetType;
  final String? targetId;
  final String priority;
  final String status;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory ModerationQueueRecord.fromJson(Map<String, dynamic> json) {
    return ModerationQueueRecord(
      id: (json['id'] ?? '').toString(),
      reportId: json['report_id']?.toString(),
      targetType: (json['target_type'] ?? '').toString(),
      targetId: json['target_id']?.toString(),
      priority: (json['priority'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      assignedTo: json['assigned_to']?.toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString())?.toUtc() ??
          DateTime.now().toUtc(),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'].toString())?.toUtc(),
    );
  }
}

class ModerationAuditLogRecord {
  const ModerationAuditLogRecord({
    required this.id,
    required this.action,
    required this.targetType,
    required this.createdAt,
    this.moderatorUserId,
    this.targetId,
    this.reportId,
    this.notes,
  });

  final String id;
  final String? moderatorUserId;
  final String action;
  final String targetType;
  final String? targetId;
  final String? reportId;
  final String? notes;
  final DateTime createdAt;

  factory ModerationAuditLogRecord.fromJson(Map<String, dynamic> json) {
    return ModerationAuditLogRecord(
      id: (json['id'] ?? '').toString(),
      moderatorUserId: json['moderator_user_id']?.toString(),
      action: (json['action'] ?? '').toString(),
      targetType: (json['target_type'] ?? '').toString(),
      targetId: json['target_id']?.toString(),
      reportId: json['report_id']?.toString(),
      notes: json['notes']?.toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString())?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }
}

class ModerationTargetPreview {
  const ModerationTargetPreview({
    required this.title,
    this.subtitle,
    this.body,
    this.createdAt,
  });

  final String title;
  final String? subtitle;
  final String? body;
  final DateTime? createdAt;
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

class MembershipRequestRecord {
  const MembershipRequestRecord({
    required this.id,
    required this.requesterUserId,
    required this.fullName,
    required this.contactEmail,
    required this.annualFeeYen,
    required this.status,
    required this.createdAt,
    this.notes,
    this.adminNote,
    this.paymentRequestSentAt,
    this.activatedAt,
    this.expiresAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  final String id;
  final String requesterUserId;
  final String fullName;
  final String contactEmail;
  final String? notes;
  final int annualFeeYen;
  final String status;
  final String? adminNote;
  final DateTime? paymentRequestSentAt;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  factory MembershipRequestRecord.fromJson(Map<String, dynamic> json) {
    return MembershipRequestRecord(
      id: (json['id'] ?? '').toString(),
      requesterUserId: (json['requester_user_id'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      contactEmail: (json['contact_email'] ?? '').toString(),
      notes: json['notes']?.toString(),
      annualFeeYen: (json['annual_fee_yen'] as num?)?.toInt() ?? 5000,
      status: (json['status'] ?? '').toString(),
      adminNote: json['admin_note']?.toString(),
      paymentRequestSentAt: json['payment_request_sent_at'] == null
          ? null
          : DateTime.tryParse(
              json['payment_request_sent_at'].toString(),
            )?.toUtc(),
      activatedAt: json['activated_at'] == null
          ? null
          : DateTime.tryParse(json['activated_at'].toString())?.toUtc(),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse(json['expires_at'].toString())?.toUtc(),
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
