import 'package:supabase_flutter/supabase_flutter.dart';

import 'team_model.dart';

class TeamRepository {
  TeamRepository() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  // ── Listing ─────────────────────────────────────────────────────────────────

  Future<List<TeamModel>> getTeams({String? search}) async {
    const cols = 'id, name, description, logo_url, banner_url, country, prefecture, city, association, is_official, leader_id, created_by, created_at';
    final List<dynamic> rows;
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().replaceAll('%', '');
      rows = await _client
          .from('teams')
          .select(cols)
          .ilike('name', '%$q%')
          .order('is_official', ascending: false)
          .order('created_at', ascending: false);
    } else {
      rows = await _client
          .from('teams')
          .select(cols)
          .order('is_official', ascending: false)
          .order('created_at', ascending: false);
    }

    final List<TeamModel> teams = [];
    for (final row in rows) {
      final m = Map<String, dynamic>.from(row as Map);
      final List<dynamic> members = await _client
          .from('team_members')
          .select('id')
          .eq('team_id', m['id'] as String)
          .eq('status', 'active');
      m['member_count'] = members.length;
      teams.add(TeamModel.fromJson(m));
    }
    return teams;
  }

  Future<TeamModel?> getTeam(String teamId) async {
    final row = await _client
        .from('teams')
      .select('id, name, description, logo_url, banner_url, country, prefecture, city, association, is_official, leader_id, created_by, created_at')
        .eq('id', teamId)
        .maybeSingle();
    if (row == null) return null;
    final data = Map<String, dynamic>.from(row);
    final List<dynamic> members = await _client
      .from('team_members')
      .select('id')
      .eq('team_id', teamId)
      .eq('status', 'active');
    data['member_count'] = members.length;
    return TeamModel.fromJson(data);
  }

  Future<List<TeamMemberModel>> getMembers(String teamId,
      {String? status}) async {
    var q = _client
        .from('team_members')
        .select('id, team_id, user_id, role, status, joined_at, profiles:profiles!team_members_user_id_fkey(call_sign, avatar_url)')
        .eq('team_id', teamId);

    if (status != null) {
      q = q.eq('status', status) as dynamic;
    }

    final rows = await (q as dynamic).order('joined_at') as List<dynamic>;
    return rows
        .map((r) => TeamMemberModel.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Returns the membership row for the current user in this team, or null.
  Future<TeamMemberModel?> getMyMembership(String teamId) async {
    final uid = _uid;
    if (uid == null) return null;
    final List<dynamic> rows = await _client
        .from('team_members')
        .select('id, team_id, user_id, role, status, joined_at, profiles:profiles!team_members_user_id_fkey(call_sign, avatar_url)')
        .eq('team_id', teamId)
        .eq('user_id', uid)
        .order('joined_at', ascending: false);
    if (rows.isEmpty) return null;

    final List<TeamMemberModel> memberships = rows
        .map((dynamic row) => TeamMemberModel.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();

    memberships.sort((TeamMemberModel a, TeamMemberModel b) {
      int statusRank(TeamMemberModel member) {
        if (member.isActive && member.isLeader) return 0;
        if (member.isActive && member.isSquadLeader) return 1;
        if (member.isActive) return 2;
        if (member.isPending) return 3;
        return 4;
      }

      final int rankCompare = statusRank(a).compareTo(statusRank(b));
      if (rankCompare != 0) {
        return rankCompare;
      }
      return b.joinedAt.compareTo(a.joinedAt);
    });

    return memberships.first;
  }

  /// Returns teams the current user belongs to (active).
  Future<List<TeamModel>> getMyTeams() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _client
        .from('team_members')
        .select('team_id, teams:teams!team_members_team_id_fkey(id, name, description, logo_url, banner_url, country, prefecture, city, association, is_official, leader_id, created_by, created_at)')
        .eq('user_id', uid)
        .eq('status', 'active') as List<dynamic>;
    final List<TeamModel> teams = [];
    for (final row in rows) {
      final teamRow = Map<String, dynamic>.from(
        (row as Map<String, dynamic>)['teams'] as Map<String, dynamic>,
      );
      final List<dynamic> members = await _client
          .from('team_members')
          .select('id')
          .eq('team_id', teamRow['id'])
          .eq('status', 'active');
      teamRow['member_count'] = members.length;
      teams.add(TeamModel.fromJson(teamRow));
    }
    return teams;
  }

  // ── Create / Edit ────────────────────────────────────────────────────────────

  Future<TeamModel> createTeam({
    required String name,
    String? description,
    String? logoUrl,
    String? country,
    String? prefecture,
    String? city,
    String? association,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final row = await _client
        .from('teams')
        .insert({
          'name': name.trim(),
          'description': description?.trim(),
          'logo_url': logoUrl,
          'country': country?.trim(),
          'prefecture': prefecture?.trim(),
          'city': city?.trim(),
          'association': association?.trim(),
          'leader_id': uid,
          'created_by': uid,
        })
        .select()
        .single();

    final team = TeamModel.fromJson(Map<String, dynamic>.from(row));

    // Ensure the creator is in team_members as an active leader so
    // getMyTeams() (which queries team_members) can find this team.
    try {
      await _client.from('team_members').upsert({
        'team_id': team.id,
        'user_id': uid,
        'role': 'leader',
        'status': 'active',
      }, onConflict: 'team_id,user_id');
    } catch (_) {
      // Non-fatal: team was created; membership row may already exist via trigger.
    }

    return team;
  }

  Future<void> updateTeam(
      String teamId, {
      String? name,
      String? description,
      String? logoUrl,
      String? bannerUrl,
      String? country,
      String? prefecture,
      String? city,
      String? association,
  }) async {
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (name != null) payload['name'] = name.trim();
    if (description != null) payload['description'] = description.trim();
    if (logoUrl != null) payload['logo_url'] = logoUrl;
    if (bannerUrl != null) payload['banner_url'] = bannerUrl;
    if (country != null) payload['country'] = country.trim();
    if (prefecture != null) payload['prefecture'] = prefecture.trim();
    if (city != null) payload['city'] = city.trim();
    if (association != null) payload['association'] = association.trim();

    await _client.from('teams').update(payload).eq('id', teamId);
  }

  Future<void> deleteTeam(String teamId) async {
    await _client.from('teams').delete().eq('id', teamId);
  }

  // ── Membership ───────────────────────────────────────────────────────────────

  /// Current user applies to join.
  Future<void> applyToJoin(String teamId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');
    await _client.from('team_members').insert({
      'team_id': teamId,
      'user_id': uid,
      'role': 'member',
      'status': 'pending',
    });
  }

  /// Leader approves a pending application.
  Future<void> approveMember(String memberId) async {
    await _client
        .from('team_members')
        .update({'status': 'active'})
        .eq('id', memberId);
  }

  Future<void> updateMemberRole(String memberId, String role) async {
    await _client.from('team_members').update({'role': role}).eq('id', memberId);
  }

  /// Leader rejects / removes a member.
  Future<void> removeMember(String memberId) async {
    await _client.from('team_members').delete().eq('id', memberId);
  }

  /// Current user leaves a team.
  Future<void> leaveTeam(String teamId) async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', uid);
  }

  // ── Admin ────────────────────────────────────────────────────────────────────

  Future<void> setOfficial(String teamId, {required bool official}) async {
    await _client.rpc('set_team_official',
        params: {'p_team_id': teamId, 'p_official': official});
  }
}
