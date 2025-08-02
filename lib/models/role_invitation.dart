import '../constants/app_constants.dart';

/// Model representing a role invitation in the system
class RoleInvitation {
  final String id;
  final String email;
  final String roleId;
  final String countryId;
  final String invitedByProfileId;
  final DateTime invitedAt;
  final String status;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional fields from joins
  final String? roleName;
  final String? roleDisplayName;
  final String? roleDescription;
  final String? countryName;
  final String? countryCode;
  final String? inviterName;

  const RoleInvitation({
    required this.id,
    required this.email,
    required this.roleId,
    required this.countryId,
    required this.invitedByProfileId,
    required this.invitedAt,
    required this.status,
    this.respondedAt,
    required this.createdAt,
    required this.updatedAt,
    this.roleName,
    this.roleDisplayName,
    this.roleDescription,
    this.countryName,
    this.countryCode,
    this.inviterName,
  });

  /// Create RoleInvitation from JSON (from database)
  factory RoleInvitation.fromJson(Map<String, dynamic> json) {
    return RoleInvitation(
      id: json[AppConstants.fieldId] as String,
      email: json[AppConstants.fieldRoleInvitationEmail] as String,
      roleId: json[AppConstants.fieldRoleInvitationRoleId] as String,
      countryId: json[AppConstants.fieldRoleInvitationCountryId] as String,
      invitedByProfileId: json[AppConstants.fieldRoleInvitationInvitedBy] as String,
      invitedAt: DateTime.parse(json[AppConstants.fieldRoleInvitationInvitedAt] as String),
      status: json[AppConstants.fieldRoleInvitationStatus] as String,
      respondedAt: json[AppConstants.fieldRoleInvitationRespondedAt] != null
          ? DateTime.parse(json[AppConstants.fieldRoleInvitationRespondedAt] as String)
          : null,
      createdAt: DateTime.parse(json[AppConstants.fieldCreatedAt] as String),
      updatedAt: DateTime.parse(json[AppConstants.fieldUpdatedAt] as String),
      roleName: json[AppConstants.fieldRoleName] as String?,
      roleDisplayName: json[AppConstants.fieldRoleDisplayName] as String?,
      roleDescription: json[AppConstants.fieldRoleDescription] as String?,
      countryName: json[AppConstants.fieldCountryName] as String?,
      countryCode: json[AppConstants.fieldCountryCode] as String?,
      inviterName: json['inviter_name'] as String?,
    );
  }

  /// Convert RoleInvitation to JSON
  Map<String, dynamic> toJson() {
    return {
      AppConstants.fieldId: id,
      AppConstants.fieldRoleInvitationEmail: email,
      AppConstants.fieldRoleInvitationRoleId: roleId,
      AppConstants.fieldRoleInvitationCountryId: countryId,
      AppConstants.fieldRoleInvitationInvitedBy: invitedByProfileId,
      AppConstants.fieldRoleInvitationInvitedAt: invitedAt.toIso8601String(),
      AppConstants.fieldRoleInvitationStatus: status,
      AppConstants.fieldRoleInvitationRespondedAt: respondedAt?.toIso8601String(),
      AppConstants.fieldCreatedAt: createdAt.toIso8601String(),
      AppConstants.fieldUpdatedAt: updatedAt.toIso8601String(),
      if (roleName != null) AppConstants.fieldRoleName: roleName,
      if (roleDisplayName != null) AppConstants.fieldRoleDisplayName: roleDisplayName,
      if (roleDescription != null) AppConstants.fieldRoleDescription: roleDescription,
      if (countryName != null) AppConstants.fieldCountryName: countryName,
      if (countryCode != null) AppConstants.fieldCountryCode: countryCode,
      if (inviterName != null) 'inviter_name': inviterName,
    };
  }

  /// Create a copy of this invitation with some fields changed
  RoleInvitation copyWith({
    String? id,
    String? email,
    String? roleId,
    String? countryId,
    String? invitedByProfileId,
    DateTime? invitedAt,
    String? status,
    DateTime? respondedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? roleName,
    String? roleDisplayName,
    String? roleDescription,
    String? countryName,
    String? countryCode,
    String? inviterName,
  }) {
    return RoleInvitation(
      id: id ?? this.id,
      email: email ?? this.email,
      roleId: roleId ?? this.roleId,
      countryId: countryId ?? this.countryId,
      invitedByProfileId: invitedByProfileId ?? this.invitedByProfileId,
      invitedAt: invitedAt ?? this.invitedAt,
      status: status ?? this.status,
      respondedAt: respondedAt ?? this.respondedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      roleName: roleName ?? this.roleName,
      roleDisplayName: roleDisplayName ?? this.roleDisplayName,
      roleDescription: roleDescription ?? this.roleDescription,
      countryName: countryName ?? this.countryName,
      countryCode: countryCode ?? this.countryCode,
      inviterName: inviterName ?? this.inviterName,
    );
  }

  /// Check if invitation is pending
  bool get isPending => status == AppConstants.invitationStatusPending;

  /// Check if invitation is accepted
  bool get isAccepted => status == AppConstants.invitationStatusAccepted;

  /// Check if invitation is declined
  bool get isDeclined => status == AppConstants.invitationStatusDeclined;

  /// Get formatted role display name
  String get formattedRoleName => roleDisplayName ?? roleName ?? 'Unknown Role';

  /// Get formatted country display
  String get formattedCountry {
    if (countryName != null && countryCode != null) {
      return '$countryName ($countryCode)';
    }
    return countryName ?? countryCode ?? 'Unknown Country';
  }

  /// Get status display text
  String get statusDisplay {
    switch (status) {
      case AppConstants.invitationStatusPending:
        return 'Pending';
      case AppConstants.invitationStatusAccepted:
        return 'Accepted';
      case AppConstants.invitationStatusDeclined:
        return 'Declined';
      default:
        return status;
    }
  }

  /// Get time since invitation was sent
  String get timeSinceInvited {
    final now = DateTime.now();
    final difference = now.difference(invitedAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  String toString() {
    return 'RoleInvitation(id: $id, email: $email, role: $roleName, country: $countryCode, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoleInvitation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
