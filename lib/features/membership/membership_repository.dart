import 'package:supabase_flutter/supabase_flutter.dart';

class MembershipRequestModel {
  const MembershipRequestModel({
    required this.id,
    required this.status,
    this.expiresAt,
    this.adminNote,
    required this.createdAt,
  });

  final String id;
  final String status;
  final DateTime? expiresAt;
  final String? adminNote;
  final DateTime createdAt;

  bool get isActive {
    if (status.toLowerCase() != 'active') {
      return false;
    }
    final DateTime? expiry = expiresAt;
    if (expiry == null) {
      return false;
    }
    return expiry.toUtc().isAfter(DateTime.now().toUtc());
  }

  factory MembershipRequestModel.fromJson(Map<String, dynamic> json) {
    return MembershipRequestModel(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      expiresAt: DateTime.tryParse((json['expires_at'] ?? '').toString()),
      adminNote: (json['admin_note'] ?? '').toString().trim().isEmpty
          ? null
          : (json['admin_note'] ?? '').toString().trim(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
    );
  }
}

class MembershipRepository {
  MembershipRepository();

  final SupabaseClient _client = Supabase.instance.client;

  String get _currentUserId {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in.');
    }
    return user.id;
  }

  Future<MembershipRequestModel?> getLatestRequest() async {
    final List<dynamic> rows = await _client
        .from('ad_free_membership_requests')
        .select('id, status, expires_at, admin_note, created_at')
        .eq('requester_user_id', _currentUserId)
        .order('created_at', ascending: false)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }

    return MembershipRequestModel.fromJson(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  Future<void> submitAnnualMembershipRequest({
    required String fullName,
    required String contactEmail,
    required String notes,
  }) async {
    final String trimmedName = fullName.trim();
    final String trimmedEmail = contactEmail.trim();
    if (trimmedName.isEmpty || trimmedEmail.isEmpty) {
      throw Exception('Name and email are required.');
    }

    final MembershipRequestModel? latest = await getLatestRequest();
    if (latest != null &&
        latest.status.toLowerCase() != 'rejected' &&
        latest.status.toLowerCase() != 'expired') {
      throw Exception('You already have a membership request in progress.');
    }

    await _client.from('ad_free_membership_requests').insert({
      'requester_user_id': _currentUserId,
      'full_name': trimmedName,
      'contact_email': trimmedEmail,
      'notes': notes.trim().isEmpty ? null : notes.trim(),
      'annual_fee_yen': 800,
      'payment_platform': 'google_play',
      'status': 'pending',
    });
  }
}
