enum FamilyRole { admin, member }

class FamilySummary {
  const FamilySummary({
    required this.id,
    required this.name,
    required this.role,
    required this.memberCount,
  });

  factory FamilySummary.fromJson(Map<String, Object?> json) {
    return FamilySummary(
      id: json['id']! as String,
      name: json['name']! as String,
      role: FamilyRole.values.byName(json['role']! as String),
      memberCount: json['member_count']! as int,
    );
  }

  final String id;
  final String name;
  final FamilyRole role;
  final int memberCount;
}

class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  factory FamilyMember.fromJson(Map<String, Object?> json) {
    return FamilyMember(
      userId: json['user_id']! as String,
      displayName: json['display_name']! as String,
      role: FamilyRole.values.byName(json['role']! as String),
      joinedAt: DateTime.parse(json['joined_at']! as String),
    );
  }

  final String userId;
  final String displayName;
  final FamilyRole role;
  final DateTime joinedAt;
}

class FamilyInvitation {
  const FamilyInvitation({
    required this.id,
    required this.expiresAt,
    required this.maxUses,
    required this.usedCount,
    required this.status,
  });

  factory FamilyInvitation.fromJson(Map<String, Object?> json) {
    return FamilyInvitation(
      id: json['id']! as String,
      expiresAt: DateTime.parse(json['expires_at']! as String),
      maxUses: json['max_uses']! as int,
      usedCount: json['used_count']! as int,
      status: json['status']! as String,
    );
  }

  final String id;
  final DateTime expiresAt;
  final int maxUses;
  final int usedCount;
  final String status;
}

class CreatedFamilyInvitation {
  const CreatedFamilyInvitation({
    required this.invitation,
    required this.code,
  });

  factory CreatedFamilyInvitation.fromJson(Map<String, Object?> json) {
    return CreatedFamilyInvitation(
      invitation: FamilyInvitation.fromJson(json),
      code: json['code']! as String,
    );
  }

  final FamilyInvitation invitation;
  final String code;
}
