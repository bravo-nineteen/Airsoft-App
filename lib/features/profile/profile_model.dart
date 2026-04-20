class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.userCode,
    required this.callSign,
    this.area,
    this.teamName,
    this.loadout,
    this.loadoutCards = const <ProfileLoadoutCard>[],
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
  final List<ProfileLoadoutCard> loadoutCards;
  final String? instagram;
  final String? facebook;
  final String? youtube;
  final String? avatarUrl;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: _readString(json['id']),
      userCode: _readString(json['user_code']),
      callSign: _readString(json['call_sign'], fallback: 'Operator'),
      area: _readNullableString(json['area']),
      teamName: _readNullableString(json['team_name']),
      loadout: _readNullableString(json['loadout']),
      loadoutCards: ProfileLoadoutCard.parseList(json['loadout_cards']),
      instagram: _readNullableString(json['instagram']),
      facebook: _readNullableString(json['facebook']),
      youtube: _readNullableString(json['youtube']),
      avatarUrl: _readNullableString(json['avatar_url']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_code': userCode,
      'call_sign': callSign,
      'area': area,
      'team_name': teamName,
      'loadout': loadout,
      'loadout_cards': loadoutCards.map((card) => card.toJson()).toList(),
      'instagram': instagram,
      'facebook': facebook,
      'youtube': youtube,
      'avatar_url': avatarUrl,
    };
  }

  ProfileModel copyWith({
    String? id,
    String? userCode,
    String? callSign,
    String? area,
    String? teamName,
    String? loadout,
    List<ProfileLoadoutCard>? loadoutCards,
    String? instagram,
    String? facebook,
    String? youtube,
    String? avatarUrl,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      userCode: userCode ?? this.userCode,
      callSign: callSign ?? this.callSign,
      area: area ?? this.area,
      teamName: teamName ?? this.teamName,
      loadout: loadout ?? this.loadout,
      loadoutCards: loadoutCards ?? this.loadoutCards,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      youtube: youtube ?? this.youtube,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  String get displayName => callSign.trim().isEmpty ? 'Operator' : callSign.trim();

  bool get hasAvatar => avatarUrl != null && avatarUrl!.trim().isNotEmpty;
  bool get hasAnySocial =>
      (instagram?.trim().isNotEmpty ?? false) ||
      (facebook?.trim().isNotEmpty ?? false) ||
      (youtube?.trim().isNotEmpty ?? false);

  List<ProfileLoadoutCard> get normalizedLoadoutCards {
    final List<ProfileLoadoutCard> items = List<ProfileLoadoutCard>.from(
      loadoutCards,
    );
    while (items.length < 3) {
      items.add(const ProfileLoadoutCard());
    }
    return items.take(3).toList();
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

class ProfileLoadoutCard {
  const ProfileLoadoutCard({
    this.title,
    this.description,
    this.imageUrl,
  });

  final String? title;
  final String? description;
  final String? imageUrl;

  bool get isEmpty {
    return (title ?? '').trim().isEmpty &&
        (description ?? '').trim().isEmpty &&
        (imageUrl ?? '').trim().isEmpty;
  }

  ProfileLoadoutCard copyWith({
    String? title,
    String? description,
    String? imageUrl,
  }) {
    return ProfileLoadoutCard(
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': _nullIfEmpty(title),
      'description': _nullIfEmpty(description),
      'image_url': _nullIfEmpty(imageUrl),
    };
  }

  static List<ProfileLoadoutCard> parseList(dynamic value) {
    if (value is! List) {
      return const <ProfileLoadoutCard>[];
    }

    return value
        .whereType<Map>()
        .map((Map item) {
          return ProfileLoadoutCard(
            title: _readNullableItem(item['title']),
            description: _readNullableItem(item['description']),
            imageUrl: _readNullableItem(item['image_url']),
          );
        })
        .toList();
  }

  static String? _readNullableItem(dynamic value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

String? _nullIfEmpty(String? value) {
  if (value == null) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
