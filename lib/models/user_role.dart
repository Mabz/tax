enum UserRole {
  traveller(
      'traveller', 'Traveller', 'Regular traveller crossing borders', false),
  borderOfficial('border_official', 'Border Official',
      'Official processing border crossings', true),
  countryAdmin('country_admin', 'Country Administrator',
      'Administrator managing country-specific settings', true),
  superuser(
      'superuser', 'Superuser', 'System administrator with full access', false);

  const UserRole(
      this.value, this.displayName, this.description, this.requiresCountry);

  final String value;
  final String displayName;
  final String description;
  final bool requiresCountry;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.traveller,
    );
  }
}

class RoleAssignment {
  final String id;
  final String userId;
  final String roleId;
  final UserRole role;
  final String? countryCode;
  final String? assignedBy;
  final DateTime assignedAt;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoleAssignment({
    required this.id,
    required this.userId,
    required this.roleId,
    required this.role,
    this.countryCode,
    this.assignedBy,
    required this.assignedAt,
    this.expiresAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RoleAssignment.fromJson(Map<String, dynamic> json) {
    return RoleAssignment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      roleId: json['role_id'] as String,
      role: UserRole.fromString(json['role_name'] as String? ?? 'traveller'),
      countryCode: json['country_code'] as String?,
      assignedBy: json['assigned_by'] as String?,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isValid => isActive && !isExpired;
}

class UserRoleData {
  final String userId;
  final String? email;
  final List<RoleAssignment> roleAssignments;
  final DateTime lastUpdated;

  UserRoleData({
    required this.userId,
    this.email,
    required this.roleAssignments,
    required this.lastUpdated,
  });

  factory UserRoleData.fromJson(Map<String, dynamic> json) {
    return UserRoleData(
      userId: json['user_id'] as String,
      email: json['email'] as String?,
      roleAssignments: [], // Will be populated separately
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  factory UserRoleData.fromViewJson(Map<String, dynamic> json) {
    final roleNames = (json['roles'] as List<dynamic>?)?.cast<String>() ?? [];
    final countryCodes =
        (json['country_codes'] as List<dynamic>?)?.cast<String>() ?? [];

    // Create role assignments from the view data
    final assignments = <RoleAssignment>[];
    
    for (int i = 0; i < roleNames.length; i++) {
      final roleName = roleNames[i];
      final countryCode = i < countryCodes.length ? countryCodes[i] : null;
      
      assignments.add(RoleAssignment(
        id: '', // Not available in view
        userId: json['user_id'] as String,
        roleId: '', // Not available in view
        role: UserRole.fromString(roleName),
        countryCode: countryCode,
        assignedBy: null,
        assignedAt: DateTime.now(),
        expiresAt: null,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    return UserRoleData(
      userId: json['user_id'] as String,
      email: json['email'] as String?,
      roleAssignments: assignments,
      lastUpdated: DateTime.now(),
    );
  }

  Set<UserRole> get roles => roleAssignments
      .where((assignment) => assignment.isValid)
      .map((assignment) => assignment.role)
      .toSet();

  List<String> get countryCodes => roleAssignments
      .where(
          (assignment) => assignment.isValid && assignment.countryCode != null)
      .map((assignment) => assignment.countryCode!)
      .toSet()
      .toList();

  bool hasRole(UserRole role) => roles.contains(role);

  bool hasAnyRole(List<UserRole> checkRoles) {
    return checkRoles.any((role) => roles.contains(role));
  }

  bool hasRoleInCountry(UserRole role, String countryCode) {
    return roleAssignments.any((assignment) =>
        assignment.isValid &&
        assignment.role == role &&
        (assignment.countryCode == countryCode || role == UserRole.superuser));
  }

  bool isSuperuser() => hasRole(UserRole.superuser);
  bool isCountryAdmin() => hasRole(UserRole.countryAdmin);
  bool isBorderOfficial() => hasRole(UserRole.borderOfficial);
  bool isTraveller() => hasRole(UserRole.traveller);

  String? getCountryForRole(UserRole role) {
    final assignment = roleAssignments.firstWhere(
      (assignment) => assignment.isValid && assignment.role == role,
      orElse: () => roleAssignments.first,
    );
    return assignment.countryCode;
  }
}
