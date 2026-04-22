class TeamModel {
  const TeamModel({
    required this.id,
    required this.name,
    required this.leaderId,
    required this.createdBy,
    required this.createdAt,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.isOfficial = false,
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final bool isOfficial;
  final String leaderId;
  final String createdBy;
  final DateTime createdAt;
  final int memberCount;

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      description: _str(json['description']),
      logoUrl: _str(json['logo_url']),
      bannerUrl: _str(json['banner_url']),
      isOfficial: json['is_official'] == true,
      leaderId: (json['leader_id'] ?? '').toString(),
      createdBy: (json['created_by'] ?? '').toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
    );
  }

  static String? _str(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  TeamModel copyWith({
    String? name,
    String? description,
    String? logoUrl,
    String? bannerUrl,
    bool? isOfficial,
    int? memberCount,
  }) {
    return TeamModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      isOfficial: isOfficial ?? this.isOfficial,
      leaderId: leaderId,
      createdBy: createdBy,
      createdAt: createdAt,
      memberCount: memberCount ?? this.memberCount,
    );
  }
}

class TeamMemberModel {
  const TeamMemberModel({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.role,
    required this.status,
    required this.joinedAt,
    this.callSign,
    this.avatarUrl,
  });

  final String id;
  final String teamId;
  final String userId;
  final String role;   // 'leader' | 'member'
  final String status; // 'pending' | 'active'
  final DateTime joinedAt;
  final String? callSign;
  final String? avatarUrl;

  bool get isLeader => role == 'leader';
  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return TeamMemberModel(
      id: json['id'].toString(),
      teamId: json['team_id'].toString(),
      userId: json['user_id'].toString(),
      role: (json['role'] ?? 'member').toString(),
      status: (json['status'] ?? 'pending').toString(),
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? '') ??
          DateTime.now(),
      callSign: profile?['call_sign']?.toString().trim(),
      avatarUrl: profile?['avatar_url']?.toString().trim(),
    );
  }
}
