import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../models/profile.dart';
import '../services/role_service.dart';

/// Country user profile with roles
class CountryUserProfile {
  final String profileId;
  final String? fullName;
  final String? email;
  final String roles;
  final DateTime? latestAssignedAt;
  final bool anyActive;

  CountryUserProfile({
    required this.profileId,
    this.fullName,
    this.email,
    required this.roles,
    this.latestAssignedAt,
    required this.anyActive,
  });

  factory CountryUserProfile.fromJson(Map<String, dynamic> json) {
    return CountryUserProfile(
      profileId: json['profile_id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      roles: json['roles'] as String? ?? '',
      latestAssignedAt: json['latest_assigned_at'] != null
          ? DateTime.parse(json['latest_assigned_at'] as String)
          : null,
      anyActive: json['any_active'] as bool? ?? false,
    );
  }
}

/// Service for managing users within a specific country
class CountryUserService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all users in a specific country
  static Future<List<CountryUserProfile>> getProfilesByCountry(
      String countryId) async {
    try {
      debugPrint('🔍 Fetching profiles for country: $countryId');

      final response = await _supabase.rpc('get_profiles_by_country', params: {
        'target_country_id': countryId,
      });

      debugPrint('✅ Fetched ${response.length} profiles for country');

      return response
          .map<CountryUserProfile>((json) => CountryUserProfile.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching profiles by country: $e');
      rethrow;
    }
  }

  /// Get detailed profile information for role management
  static Future<Profile?> getProfileDetails(String profileId) async {
    try {
      debugPrint('🔍 Fetching profile details for: $profileId');

      final response = await _supabase
          .from(AppConstants.tableProfiles)
          .select()
          .eq(AppConstants.fieldId, profileId)
          .single();

      debugPrint('✅ Fetched profile details');
      return Profile.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching profile details: $e');
      return null;
    }
  }

  /// Get user roles for a specific authority (updated from country-based to authority-based)
  static Future<List<Map<String, dynamic>>> getUserRolesInAuthority(
      String profileId, String authorityId) async {
    try {
      debugPrint(
          '🔍 Fetching user roles for profile: $profileId in authority: $authorityId');

      final response = await _supabase
          .from(AppConstants.tableProfileRoles)
          .select('''
            id,
            role_id,
            authority_id,
            is_active,
            assigned_at,
            expires_at,
            roles!inner(name, display_name, description),
            authorities!inner(name, code, country_id, countries!inner(name, country_code))
          ''')
          .eq(AppConstants.fieldProfileRoleProfileId, profileId)
          .eq(AppConstants.fieldProfileRoleAuthorityId, authorityId)
          .order('assigned_at', ascending: false);

      debugPrint('✅ Fetched ${response.length} roles for user in authority');
      return response;
    } catch (e) {
      debugPrint('❌ Error fetching user roles in authority: $e');
      return [];
    }
  }

  /// Get user roles for a specific country (legacy method - gets all roles for authorities in a country)
  static Future<List<Map<String, dynamic>>> getUserRolesInCountry(
      String profileId, String countryId) async {
    try {
      debugPrint(
          '🔍 Fetching user roles for profile: $profileId in country: $countryId');

      final response = await _supabase
          .from(AppConstants.tableProfileRoles)
          .select('''
            id,
            role_id,
            authority_id,
            is_active,
            assigned_at,
            expires_at,
            roles!inner(name, display_name, description),
            authorities!inner(name, code, country_id, countries!inner(name, country_code))
          ''')
          .eq(AppConstants.fieldProfileRoleProfileId, profileId)
          .eq('authorities.country_id', countryId)
          .order('assigned_at', ascending: false);

      debugPrint('✅ Fetched ${response.length} roles for user in country');
      return response;
    } catch (e) {
      debugPrint('❌ Error fetching user roles in country: $e');
      return [];
    }
  }

  /// Remove a role from a user in the current country
  static Future<void> removeUserRole(String profileRoleId) async {
    try {
      debugPrint('🔍 Removing role assignment: $profileRoleId');

      await _supabase
          .from(AppConstants.tableProfileRoles)
          .update({AppConstants.fieldProfileRoleIsActive: false}).eq(
              AppConstants.fieldId, profileRoleId);

      debugPrint('✅ Role assignment removed successfully');
    } catch (e) {
      debugPrint('❌ Error removing role assignment: $e');
      rethrow;
    }
  }

  /// Toggle the active status of a role assignment
  static Future<void> toggleUserRoleStatus(
      String profileRoleId, bool isActive) async {
    try {
      debugPrint(
          '🔍 Toggling role assignment status: $profileRoleId to $isActive');

      await _supabase
          .from(AppConstants.tableProfileRoles)
          .update({AppConstants.fieldProfileRoleIsActive: isActive}).eq(
              AppConstants.fieldId, profileRoleId);

      debugPrint('✅ Role assignment status updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating role assignment status: $e');
      rethrow;
    }
  }

  /// Completely delete a role assignment from a user
  static Future<void> deleteUserRole(String profileRoleId) async {
    try {
      debugPrint('🔍 Deleting role assignment: $profileRoleId');

      await _supabase
          .from(AppConstants.tableProfileRoles)
          .delete()
          .eq(AppConstants.fieldId, profileRoleId);

      debugPrint('✅ Role assignment deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting role assignment: $e');
      rethrow;
    }
  }

  /// Assign a role to a user for a specific authority
  static Future<void> assignUserRole({
    required String profileId,
    required String roleId,
    required String authorityId,
    DateTime? expiresAt,
  }) async {
    try {
      debugPrint(
          '🔍 Assigning role to user: $profileId for authority: $authorityId');

      await _supabase.from(AppConstants.tableProfileRoles).insert({
        AppConstants.fieldProfileRoleProfileId: profileId,
        AppConstants.fieldProfileRoleRoleId: roleId,
        AppConstants.fieldProfileRoleAuthorityId: authorityId,
        AppConstants.fieldProfileRoleAssignedBy: _supabase.auth.currentUser?.id,
        AppConstants.fieldProfileRoleExpiresAt: expiresAt?.toIso8601String(),
        AppConstants.fieldProfileRoleIsActive: true,
      });

      debugPrint('✅ Role assigned successfully');
    } catch (e) {
      debugPrint('❌ Error assigning role: $e');
      rethrow;
    }
  }

  /// Get available roles that can be assigned by country admin
  static Future<List<Map<String, dynamic>>> getAssignableRoles() async {
    try {
      debugPrint('🔍 Fetching assignable roles for country admin');

      final response = await _supabase
          .from(AppConstants.tableRoles)
          .select('id, name, display_name, description')
          .inFilter('name', [
        AppConstants.roleCountryAdmin,
        AppConstants.roleCountryAuditor,
        AppConstants.roleBorderOfficial,
        AppConstants.roleLocalAuthority,
      ]).order('display_name');

      debugPrint('✅ Fetched ${response.length} assignable roles');
      return response;
    } catch (e) {
      debugPrint('❌ Error fetching assignable roles: $e');
      return [];
    }
  }

  /// Get all invitations for a specific authority
  static Future<List<Map<String, dynamic>>> getAllInvitationsForAuthority(
      String authorityId) async {
    try {
      debugPrint('🔍 Fetching all invitations for authority: $authorityId');

      final response = await _supabase.rpc(
        AppConstants.getAllInvitationsForAuthorityFunction,
        params: {'target_authority_id': authorityId},
      );

      debugPrint('✅ Fetched ${response.length} invitations for authority');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching invitations for authority: $e');
      return [];
    }
  }

  /// Legacy method: Get all invitations for a specific country (deprecated)
  static Future<List<Map<String, dynamic>>> getAllInvitationsForCountry(
      String countryId) async {
    try {
      debugPrint(
          '🔍 Fetching all invitations for country (legacy): $countryId');

      final response = await _supabase.rpc(
        AppConstants.getAllInvitationsForCountryFunction,
        params: {'target_country_id': countryId},
      );

      debugPrint(
          '✅ Fetched ${response.length} invitations for country (legacy)');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching invitations for country (legacy): $e');
      return [];
    }
  }

  /// Check if current user can manage users in a country
  static Future<bool> canManageCountryUsers(String countryId) async {
    try {
      final isSuperuser = await RoleService.isSuperuser();
      if (isSuperuser) return true;

      final hasAdminRole = await RoleService.hasAdminRole();
      if (!hasAdminRole) return false;

      // Check if user is admin for this specific country
      final countries = await RoleService.getCountryAdminCountries();
      return countries.any((country) => country['id'] == countryId);
    } catch (e) {
      debugPrint('❌ Error checking country user management permissions: $e');
      return false;
    }
  }
}
