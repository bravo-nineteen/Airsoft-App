import 'package:supabase_flutter/supabase_flutter.dart';

class SafetyRepository {
  SafetyRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _currentUserId {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in.');
    }
    return user.id;
  }

  Future<void> submitReport({
    required String targetType,
    String? targetId,
    required String reasonCategory,
    String? details,
  }) async {
    final String currentUserId = _currentUserId;
    final Map<String, dynamic> payload = <String, dynamic>{
      'reporter_user_id': currentUserId,
      'target_type': targetType,
      'target_id': _nullIfEmpty(targetId),
      'reason_category': reasonCategory,
      'details': _nullIfEmpty(details),
      'status': 'open',
    };

    await _client.from('safety_reports').insert(payload);
  }

  Future<void> blockUser(String otherUserId, {String? reason}) async {
    final String currentUserId = _currentUserId;
    final String normalizedOther = otherUserId.trim();
    if (normalizedOther.isEmpty || normalizedOther == currentUserId) {
      throw Exception('Invalid user.');
    }

    await _client.from('user_blocks').upsert(<String, dynamic>{
      'user_id': currentUserId,
      'blocked_user_id': normalizedOther,
      'reason': _nullIfEmpty(reason),
    });

    await _client
        .from('user_contacts')
        .delete()
        .or(
          'and(requester_id.eq.$currentUserId,addressee_id.eq.$normalizedOther),and(requester_id.eq.$normalizedOther,addressee_id.eq.$currentUserId)',
        );
  }

  Future<void> unblockUser(String otherUserId) async {
    final String currentUserId = _currentUserId;
    await _client
        .from('user_blocks')
        .delete()
        .eq('user_id', currentUserId)
        .eq('blocked_user_id', otherUserId);
  }

  Future<void> muteUser(
    String otherUserId, {
    DateTime? expiresAt,
    String? reason,
  }) async {
    final String currentUserId = _currentUserId;
    final String normalizedOther = otherUserId.trim();
    if (normalizedOther.isEmpty || normalizedOther == currentUserId) {
      throw Exception('Invalid user.');
    }

    await _client.from('user_mutes').upsert(<String, dynamic>{
      'user_id': currentUserId,
      'muted_user_id': normalizedOther,
      'expires_at': expiresAt?.toUtc().toIso8601String(),
      'reason': _nullIfEmpty(reason),
    });
  }

  Future<void> unmuteUser(String otherUserId) async {
    final String currentUserId = _currentUserId;
    await _client
        .from('user_mutes')
        .delete()
        .eq('user_id', currentUserId)
        .eq('muted_user_id', otherUserId);
  }

  Future<SafetyRelationshipState> getRelationshipState(String otherUserId) async {
    final String currentUserId = _currentUserId;
    final String nowIso = DateTime.now().toUtc().toIso8601String();

    final Map<String, dynamic>? myBlock = await _client
        .from('user_blocks')
        .select('user_id')
        .eq('user_id', currentUserId)
        .eq('blocked_user_id', otherUserId)
        .maybeSingle();

    final Map<String, dynamic>? blockedMe = await _client
        .from('user_blocks')
        .select('user_id')
        .eq('user_id', otherUserId)
        .eq('blocked_user_id', currentUserId)
        .maybeSingle();

    final List<dynamic> muteRows = await _client
        .from('user_mutes')
        .select('muted_user_id')
        .eq('user_id', currentUserId)
        .eq('muted_user_id', otherUserId)
        .or('expires_at.is.null,expires_at.gt.$nowIso')
        .limit(1);

    return SafetyRelationshipState(
      blockedByMe: myBlock != null,
      blockedMe: blockedMe != null,
      mutedByMe: muteRows.isNotEmpty,
    );
  }

  Future<Set<String>> getHiddenAuthorIds() async {
    final String currentUserId = _currentUserId;
    final String nowIso = DateTime.now().toUtc().toIso8601String();

    final List<dynamic> blockedRows = await _client
        .from('user_blocks')
        .select('blocked_user_id')
        .eq('user_id', currentUserId);

    final List<dynamic> mutedRows = await _client
        .from('user_mutes')
        .select('muted_user_id')
        .eq('user_id', currentUserId)
        .or('expires_at.is.null,expires_at.gt.$nowIso');

    final Set<String> hidden = <String>{};
    for (final dynamic row in blockedRows) {
      final String id = (row['blocked_user_id'] ?? '').toString();
      if (id.isNotEmpty) {
        hidden.add(id);
      }
    }
    for (final dynamic row in mutedRows) {
      final String id = (row['muted_user_id'] ?? '').toString();
      if (id.isNotEmpty) {
        hidden.add(id);
      }
    }
    return hidden;
  }

  Future<bool> canMessageUser(String otherUserId) async {
    final SafetyRelationshipState state = await getRelationshipState(otherUserId);
    return !state.blockedByMe && !state.blockedMe;
  }

  Future<List<BlockedUserRecord>> getBlockedUsers() async {
    final String currentUserId = _currentUserId;
    final List<dynamic> rows = await _client
        .from('user_blocks')
        .select('blocked_user_id, reason, created_at')
        .eq('user_id', currentUserId)
        .order('created_at', ascending: false);

    final List<String> userIds = rows
        .map((dynamic row) => (row['blocked_user_id'] ?? '').toString())
        .where((String id) => id.isNotEmpty)
        .toList();

    final Map<String, String> namesById = await _fetchCallSigns(userIds);
    return rows.map((dynamic row) {
      final String userId = (row['blocked_user_id'] ?? '').toString();
      return BlockedUserRecord(
        userId: userId,
        callSign: namesById[userId] ?? userId,
        reason: row['reason']?.toString(),
        createdAt:
            DateTime.tryParse((row['created_at'] ?? '').toString())?.toUtc() ??
            DateTime.now().toUtc(),
      );
    }).toList();
  }

  Future<List<MutedUserRecord>> getMutedUsers() async {
    final String currentUserId = _currentUserId;
    final List<dynamic> rows = await _client
        .from('user_mutes')
        .select('muted_user_id, reason, created_at, expires_at')
        .eq('user_id', currentUserId)
        .order('created_at', ascending: false);

    final List<String> userIds = rows
        .map((dynamic row) => (row['muted_user_id'] ?? '').toString())
        .where((String id) => id.isNotEmpty)
        .toList();

    final Map<String, String> namesById = await _fetchCallSigns(userIds);
    return rows.map((dynamic row) {
      final String userId = (row['muted_user_id'] ?? '').toString();
      return MutedUserRecord(
        userId: userId,
        callSign: namesById[userId] ?? userId,
        reason: row['reason']?.toString(),
        createdAt:
            DateTime.tryParse((row['created_at'] ?? '').toString())?.toUtc() ??
            DateTime.now().toUtc(),
        expiresAt: row['expires_at'] == null
            ? null
            : DateTime.tryParse(row['expires_at'].toString())?.toUtc(),
      );
    }).toList();
  }

  Future<Map<String, String>> _fetchCallSigns(List<String> userIds) async {
    if (userIds.isEmpty) {
      return <String, String>{};
    }

    try {
      final List<dynamic> profileRows = await _client
          .from('profiles')
          .select('id, call_sign')
          .inFilter('id', userIds);
      return <String, String>{
        for (final dynamic row in profileRows)
          row['id'].toString():
              (row['call_sign']?.toString().trim().isNotEmpty == true)
              ? row['call_sign'].toString().trim()
              : row['id'].toString(),
      };
    } catch (_) {
      return <String, String>{};
    }
  }

  String? _nullIfEmpty(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class SafetyRelationshipState {
  const SafetyRelationshipState({
    required this.blockedByMe,
    required this.blockedMe,
    required this.mutedByMe,
  });

  final bool blockedByMe;
  final bool blockedMe;
  final bool mutedByMe;
}

class BlockedUserRecord {
  const BlockedUserRecord({
    required this.userId,
    required this.callSign,
    required this.createdAt,
    this.reason,
  });

  final String userId;
  final String callSign;
  final String? reason;
  final DateTime createdAt;
}

class MutedUserRecord {
  const MutedUserRecord({
    required this.userId,
    required this.callSign,
    required this.createdAt,
    this.reason,
    this.expiresAt,
  });

  final String userId;
  final String callSign;
  final String? reason;
  final DateTime createdAt;
  final DateTime? expiresAt;
}