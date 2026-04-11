class AppUserProfile {
  const AppUserProfile({
    required this.id,
    required this.userCode,
    required this.callSign,
    this.area,
    this.teamName,
    this.loadout,
    this.instagram,
    this.facebook,
    this.youtube,
    this.avatarUrl,
  });

  final String id;
  final String userCode;
  final String callSign;
  final String? area;
  final String? teamName;
  final String? loadout;
  final String? instagram;
  final String? facebook;
  final String? youtube;
  final String? avatarUrl;

  AppUserProfile copyWith({
    String? id,
    String? userCode,
    String? callSign,
    String? area,
    String? teamName,
    String? loadout,
    String? instagram,
    String? facebook,
    String? youtube,
    String? avatarUrl,
  }) {
    return AppUserProfile(
      id: id ?? this.id,
      userCode: userCode ?? this.userCode,
      callSign: callSign ?? this.callSign,
      area: area ?? this.area,
      teamName: teamName ?? this.teamName,
      loadout: loadout ?? this.loadout,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      youtube: youtube ?? this.youtube,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'user_code': userCode,
      'call_sign': callSign,
      'area': area,
      'team_name': teamName,
      'loadout': loadout,
      'instagram': instagram,
      'facebook': facebook,
      'youtube': youtube,
      'avatar_url': avatarUrl,
    };
  }

  factory AppUserProfile.fromMap(Map<String, dynamic> map) {
    return AppUserProfile(
      id: map['id'] as String? ?? '',
      userCode: map['user_code'] as String? ?? '',
      callSign: map['call_sign'] as String? ?? '',
      area: map['area'] as String?,
      teamName: map['team_name'] as String?,
      loadout: map['loadout'] as String?,
      instagram: map['instagram'] as String?,
      facebook: map['facebook'] as String?,
      youtube: map['youtube'] as String?,
      avatarUrl: map['avatar_url'] as String?,
    );
  }

  factory AppUserProfile.sample() {
    return const AppUserProfile(
      id: '00000000-0000-0000-0000-000000000001',
      userCode: 'AOJ-1901',
      callSign: 'Nineteen',
      area: 'Chiba / Tokyo',
      teamName: 'Airsoft Online Japan',
      loadout: 'Modern tactical rifleman',
      instagram: 'https://instagram.com/airsoftonlinejapan',
      facebook: '',
      youtube: '',
      avatarUrl: null,
    );
  }
}
