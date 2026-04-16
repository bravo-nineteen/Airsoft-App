import 'package:supabase_flutter/supabase_flutter.dart';

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
        'instagram': null,
        'facebook': null,
        'youtube': null,
        'avatar_url': null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _client.from('profiles').insert(newProfile);
      return ProfileModel.fromJson(newProfile);
    }

    return ProfileModel.fromJson(data);
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
      'instagram': profile.instagram,
      'facebook': profile.facebook,
      'youtube': profile.youtube,
      'avatar_url': profile.avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _client.from('profiles').update(payload).eq('id', user.id);

    final refreshed = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (refreshed == null) {
      throw Exception('Failed to reload updated profile.');
    }

    return ProfileModel.fromJson(refreshed);
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
}