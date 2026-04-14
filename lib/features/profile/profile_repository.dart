import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_model.dart';

class ProfileRepository {
  ProfileRepository();

  final SupabaseClient _client = Supabase.instance.client;

  Future<ProfileModel> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }

    final data = await _client.from('profiles').select().eq('id', user.id).single();
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

    final refreshed = await _client.from('profiles').select().eq('id', user.id).single();
    return ProfileModel.fromJson(refreshed);
  }

  Future<void> updateProfileFields({
    required String callSign,
    String? area,
    String? teamName,
    String? loadout,
    String? instagram,
    String? facebook,
    String? youtube,
    String? avatarUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }

    final payload = <String, dynamic>{
      'call_sign': callSign,
      'area': area,
      'team_name': teamName,
      'loadout': loadout,
      'instagram': instagram,
      'facebook': facebook,
      'youtube': youtube,
      'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _client.from('profiles').update(payload).eq('id', user.id);
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
}
