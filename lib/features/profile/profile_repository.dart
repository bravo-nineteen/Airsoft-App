import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/user_avatar_cache.dart';
import 'profile_model.dart';

class ProfileRepository {
  ProfileRepository();

  final SupabaseClient _client = Supabase.instance.client;

  Future<ProfileModel?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      final fallbackCallSign = _buildFallbackCallSign(user.email);
      final newProfile = <String, dynamic>{
        'id': user.id,
        'user_code': user.id.substring(0, 6).toUpperCase(),
        'call_sign': fallbackCallSign,
        'area': null,
        'team_name': null,
        'loadout': null,
        'loadout_cards': <Map<String, dynamic>>[],
        'instagram': null,
        'facebook': null,
        'youtube': null,
        'avatar_url': null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await _client.from('profiles').insert(newProfile);
      } on PostgrestException catch (error) {
        if (!_isMissingColumnError(error, 'loadout_cards')) {
          rethrow;
        }
        newProfile.remove('loadout_cards');
        await _client.from('profiles').insert(newProfile);
      }
      return ProfileModel.fromJson(newProfile);
    }

    final profile = ProfileModel.fromJson(data);
    UserAvatarCache.instance.warmCurrentUser(user.id, profile.avatarUrl);
    return profile;
  }

  Future<ProfileModel> updateCurrentProfile(ProfileModel profile) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }

    final payload = <String, dynamic>{
      'user_code': profile.userCode,
      'call_sign': profile.callSign,
      'area': profile.area,
      'team_name': profile.teamName,
      'loadout': profile.loadout,
        'loadout_cards': profile.loadoutCards
          .map((ProfileLoadoutCard card) => card.toJson())
          .toList(),
      'instagram': profile.instagram,
      'facebook': profile.facebook,
      'youtube': profile.youtube,
      'avatar_url': profile.avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _client.from('profiles').update(payload).eq('id', user.id);
    } on PostgrestException catch (error) {
      if (!_isMissingColumnError(error, 'loadout_cards')) {
        rethrow;
      }
      payload.remove('loadout_cards');
      await _client.from('profiles').update(payload).eq('id', user.id);
    }

    final refreshed = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (refreshed == null) {
      throw Exception('Failed to reload updated profile.');
    }

    final updated = ProfileModel.fromJson(refreshed);
    UserAvatarCache.instance.warmCurrentUser(user.id, updated.avatarUrl);
    return updated;
  }

  Future<void> updateAvatarUrl(String avatarUrl) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }

    await _client.from('profiles').update({
      'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
    UserAvatarCache.instance.set(user.id, avatarUrl);
  }

  /// Deletes all user data and the auth account.  The SQL function
  /// `delete_my_account()` handles cascading deletion server-side.
  Future<void> deleteAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated.');

    try {
      // Try the server-side RPC first (requires a SQL function).
      await _client.rpc('delete_my_account');
    } on PostgrestException {
      // Fallback: just delete the profile row and sign out.
      await _client.from('profiles').delete().eq('id', user.id);
    }

    await _client.auth.signOut();
  }

  Future<List<ProfileModel>> searchProfiles(String query) async {
    final currentUser = _client.auth.currentUser;
    final trimmed = query.trim();

    if (currentUser == null) {
      throw Exception('User not authenticated.');
    }

    if (trimmed.isEmpty) {
      final response = await _client
          .from('profiles')
          .select()
          .neq('id', currentUser.id)
          .order('updated_at', ascending: false)
          .limit(20);

      return response
          .map<ProfileModel>((e) => ProfileModel.fromJson(e))
          .toList();
    }

    final lower = trimmed.toLowerCase();

    final response = await _client
        .from('profiles')
        .select()
        .neq('id', currentUser.id)
        .order('updated_at', ascending: false)
        .limit(100);

    final profiles = response
        .map<ProfileModel>((e) => ProfileModel.fromJson(e))
        .toList();

    return profiles.where((profile) {
      final haystack = [
        profile.callSign,
        profile.userCode,
        profile.area ?? '',
        profile.teamName ?? '',
        profile.loadout ?? '',
        ...profile.loadoutCards.map((ProfileLoadoutCard card) {
          return '${card.title ?? ''} ${card.description ?? ''} ${card.imageUrl ?? ''}';
        }),
      ].join(' ').toLowerCase();

      return haystack.contains(lower);
    }).toList();
  }

  String _buildFallbackCallSign(String? email) {
    final trimmed = (email ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Operator';
    }

    final localPart = trimmed.split('@').first.trim();
    if (localPart.isEmpty) {
      return 'Operator';
    }

    return localPart;
  }

  bool _isMissingColumnError(PostgrestException error, String columnName) {
    if (error.code != 'PGRST204' && error.code != '42703') {
      return false;
    }
    final String summary =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    final String needle = columnName.toLowerCase();
    return summary.contains(needle);
  }
}