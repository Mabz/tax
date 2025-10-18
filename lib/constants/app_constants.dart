/// Application constants for EasyTax
/// Contains role names, function names, and other app-wide constants
library;

class AppConstants {
  // Prevent instantiation
  AppConstants._();

  /// Database function names
  static const String userHasRoleFunction = 'user_has_role';
  static const String profileHasRoleFunction = 'profile_has_role';
  static const String isSuperuserFunction = 'is_superuser';
  static const String getProfileByEmailFunction = 'get_profile_by_email';
  static const String getProfilesByCountryFunction = 'get_profiles_by_country';
  static const String getPassesForUserFunction = 'get_passes_for_user';
  static const String getPassesForProfileFunction = 'get_passes_for_profile';
  static const String getVehiclesForUserFunction = 'get_vehicles_for_user';
  static const String getVehiclesForProfileFunction =
      'get_vehicles_for_profile';

  /// Invitation function names
  static const String inviteUserToRoleFunction = 'invite_user_to_role';
  static const String inviteProfileToRoleFunction = 'invite_profile_to_role';
  static const String deleteRoleInvitationFunction = 'delete_role_invitation';
  static const String acceptRoleInvitationFunction = 'accept_role_invitation';
  static const String declineRoleInvitationFunction = 'decline_role_invitation';
  static const String getPendingInvitationsFunction =
      'get_pending_invitations_for_user';
  static const String getPendingInvitationsForProfileFunction =
      'get_pending_invitations_for_profile';
  static const String getAllInvitationsForCountryFunction =
      'get_all_invitations_for_country';
  static const String getAllInvitationsForAuthorityFunction =
      'get_all_invitations_for_authority';
  static const String resendInvitationFunction = 'resend_invitation';

  /// Role names (must match database roles table)
  static const String roleTraveller = 'traveller';
  static const String roleCountryAdmin = 'country_admin';
  static const String roleCountryAuditor = 'country_auditor';
  static const String roleBorderOfficial = 'border_official';
  static const String roleBusinessIntelligence = 'business_intelligence';
  static const String roleLocalAuthority = 'local_authority';
  static const String roleBorderManager = 'border_manager';
  static const String roleComplianceOfficer = 'compliance_officer';
  static const String roleSuperuser = 'superuser';

  /// Country codes (ISO 3166-1 alpha-3)
  static const String countryGlobal = 'ALL';
  static const String countryEswatini = 'SWZ';
  static const String countrySouthAfrica = 'ZAF';
  static const String countryKenya = 'KEN';
  static const String countryNigeria = 'NGA';
  static const String countryNamibia = 'NAM';
  static const String countryMozambique = 'MOZ';
  static const String countryBotswana = 'BWA';
  static const String countryZambia = 'ZMB';
  static const String countryZimbabwe = 'ZWE';
  static const String countryTanzania = 'TZA';
  static const String countryLesotho = 'LSO';
  static const String countryAngola = 'AGO';

  /// Function parameter names
  static const String paramRoleName = 'role_name';
  static const String paramCountryCode = 'country_code';
  static const String paramUserId = 'user_id';
  static const String paramEmail = 'p_email';

  /// Database table names
  static const String tableRoles = 'roles';
  static const String tableProfiles = 'profiles';
  static const String tableCountries = 'countries';
  static const String tableAuthorities = 'authorities';
  static const String tableProfileRoles = 'profile_roles';
  static const String tableAuditLogs = 'audit_logs';
  static const String tableBorderTypes = 'border_types';
  static const String tableBorders = 'borders';
  static const String tableRoleInvitations = 'role_invitations';

  /// Common database field names
  static const String fieldId = 'id';
  static const String fieldCreatedAt = 'created_at';
  static const String fieldUpdatedAt = 'updated_at';

  /// Roles table fields
  static const String fieldRoleName = 'name';
  static const String fieldRoleDisplayName = 'display_name';
  static const String fieldRoleDescription = 'description';

  /// Profiles table fields
  static const String fieldProfileFullName = 'full_name';
  static const String fieldProfileEmail = 'email';
  static const String fieldProfileIsActive = 'is_active';

  /// Countries table fields
  static const String fieldCountryName = 'name';
  static const String fieldCountryCode = 'country_code';
  static const String fieldCountryRevenueServiceName = 'revenue_service_name';
  static const String fieldCountryIsActive = 'is_active';
  static const String fieldCountryIsGlobal = 'is_global';

  /// Authorities table fields
  static const String fieldAuthorityCountryId = 'country_id';
  static const String fieldAuthorityName = 'name';
  static const String fieldAuthorityCode = 'code';
  static const String fieldAuthorityType = 'authority_type';
  static const String fieldAuthorityDescription = 'description';
  static const String fieldAuthorityIsActive = 'is_active';

  /// Border Types table fields
  static const String fieldBorderTypeCode = 'code';
  static const String fieldBorderTypeLabel = 'label';
  static const String fieldBorderTypeDescription = 'description';

  /// Borders table fields
  static const String fieldBorderCountryId = 'country_id';
  static const String fieldBorderAuthorityId = 'authority_id';
  static const String fieldBorderName = 'name';
  static const String fieldBorderTypeId = 'border_type_id';
  static const String fieldBorderIsActive = 'is_active';
  static const String fieldBorderLatitude = 'latitude';
  static const String fieldBorderLongitude = 'longitude';
  static const String fieldBorderDescription = 'description';

  /// Profile Roles table fields
  static const String fieldProfileRoleProfileId = 'profile_id';
  static const String fieldProfileRoleRoleId = 'role_id';
  static const String fieldProfileRoleCountryId = 'country_id';
  static const String fieldProfileRoleAuthorityId = 'authority_id';
  static const String fieldProfileRoleAssignedBy = 'assigned_by_profile_id';
  static const String fieldProfileRoleAssignedAt = 'assigned_at';
  static const String fieldProfileRoleExpiresAt = 'expires_at';
  static const String fieldProfileRoleIsActive = 'is_active';

  /// Audit Logs table fields
  static const String fieldAuditLogActorProfileId = 'actor_profile_id';
  static const String fieldAuditLogTargetProfileId = 'target_profile_id';
  static const String fieldAuditLogAction = 'action';
  static const String fieldAuditLogMetadata = 'metadata';

  /// Role Invitations table fields
  static const String fieldRoleInvitationEmail = 'email';
  static const String fieldRoleInvitationRoleId = 'role_id';
  static const String fieldRoleInvitationCountryId = 'country_id';
  static const String fieldRoleInvitationAuthorityId = 'authority_id';
  static const String fieldRoleInvitationInvitedBy = 'invited_by_profile_id';
  static const String fieldRoleInvitationInvitedAt = 'invited_at';
  static const String fieldRoleInvitationStatus = 'status';
  static const String fieldRoleInvitationRespondedAt = 'responded_at';

  /// Database function return field names (for get_pending_invitations_for_user)
  static const String dbFieldId = 'id';
  static const String dbFieldEmail = 'email';
  static const String dbFieldRoleName = 'role_name';
  static const String dbFieldRoleDescription = 'role_description';
  static const String dbFieldCountryName = 'country_name';
  static const String dbFieldCountryCode = 'country_code';
  static const String dbFieldInvitedAt = 'invited_at';

  /// Database function return field names (for get_profiles_by_country)
  static const String dbFieldProfileId = 'profile_id';
  static const String dbFieldFullName = 'full_name';
  static const String dbFieldAssignedAt = 'assigned_at';
  static const String dbFieldIsActive = 'is_active';

  /// Invitation status values
  static const String invitationStatusPending = 'pending';
  static const String invitationStatusAccepted = 'accepted';
  static const String invitationStatusDeclined = 'declined';

  /// UI Constants
  static const String appName = 'EasyTax';
  static const String adminPanelTitle = 'Admin Panel';
  static const String superuserBadge = 'SUPERUSER';
}
