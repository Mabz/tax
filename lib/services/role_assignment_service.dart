import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

/// Service for managing user role assignments (ROLE MANAGEMENT)
///
/// IMPORTANT: This service only manages the profile_roles table.
/// It does NOT affect the authority_profiles table.
///
/// Use AuthorityProfilesService for user management (adding/removing users from authorities).
///
/// Separation of concerns:
/// - RoleAssignmentService: Manages specific roles (profile_roles table)
/// - AuthorityProfilesService: Manages user membership in authorities (authority_profiles table)
class RoleAssignmentService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all roles for a specific user
  static Future<List<Map<String, dynamic>>> getUserRoles(String userId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableProfileRoles)
          .select('''
            ${AppConstants.fieldId},
            ${AppConstants.fieldProfileRoleRoleId},
            ${AppConstants.fieldProfileRoleCountryId},
            ${AppConstants.fieldProfileRoleIsActive},
            ${AppConstants.fieldProfileRoleExpiresAt},
            ${AppConstants.tableRoles}!inner(
              ${AppConstants.fieldRoleName},
              ${AppConstants.fieldRoleDisplayName}
            ),
            ${AppConstants.tableCountries}(
              ${AppConstants.fieldCountryName},
              ${AppConstants.fieldCountryCode}
            )
          ''')
          .eq(AppConstants.fieldProfileRoleProfileId, userId)
          .eq(AppConstants.fieldProfileRoleIsActive, true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.getUserRoles error: $e');
      rethrow;
    }
  }

  /// Get all available roles
  static Future<List<Map<String, dynamic>>> getAllRoles() async {
    try {
      final response = await _supabase.from(AppConstants.tableRoles).select('''
            ${AppConstants.fieldId},
            ${AppConstants.fieldRoleName},
            ${AppConstants.fieldRoleDisplayName},
            ${AppConstants.fieldRoleDescription}
          ''').order(AppConstants.fieldRoleDisplayName);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.getAllRoles error: $e');
      rethrow;
    }
  }

  /// Assign a role to a user
  static Future<void> assignRole({
    required String userId,
    required String roleId,
    String? countryId,
    DateTime? expiresAt,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      await _supabase.from(AppConstants.tableProfileRoles).insert({
        AppConstants.fieldProfileRoleProfileId: userId,
        AppConstants.fieldProfileRoleRoleId: roleId,
        AppConstants.fieldProfileRoleCountryId: countryId,
        AppConstants.fieldProfileRoleAssignedBy: currentUser.id,
        AppConstants.fieldProfileRoleExpiresAt: expiresAt?.toIso8601String(),
        AppConstants.fieldProfileRoleIsActive: true,
      });
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.assignRole error: $e');
      rethrow;
    }
  }

  /// Remove a role from a user
  static Future<void> removeRole({
    required String userId,
    required String roleId,
    String? countryId,
  }) async {
    try {
      var query = _supabase
          .from(AppConstants.tableProfileRoles)
          .delete()
          .eq(AppConstants.fieldProfileRoleProfileId, userId)
          .eq(AppConstants.fieldProfileRoleRoleId, roleId);

      if (countryId != null) {
        query = query.eq(AppConstants.fieldProfileRoleCountryId, countryId);
      } else {
        query = query.isFilter(AppConstants.fieldProfileRoleCountryId, null);
      }

      await query;
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.removeRole error: $e');
      rethrow;
    }
  }

  /// Toggle role active status
  static Future<void> toggleRoleStatus({
    required String userId,
    required String roleId,
    String? countryId,
    required bool isActive,
  }) async {
    try {
      var query = _supabase
          .from(AppConstants.tableProfileRoles)
          .update({
            AppConstants.fieldProfileRoleIsActive: isActive,
            AppConstants.fieldUpdatedAt: DateTime.now().toIso8601String(),
          })
          .eq(AppConstants.fieldProfileRoleProfileId, userId)
          .eq(AppConstants.fieldProfileRoleRoleId, roleId);

      if (countryId != null) {
        query = query.eq(AppConstants.fieldProfileRoleCountryId, countryId);
      } else {
        query = query.isFilter(AppConstants.fieldProfileRoleCountryId, null);
      }

      await query;
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.toggleRoleStatus error: $e');
      rethrow;
    }
  }

  /// Check if user has a specific role
  static Future<bool> userHasRole({
    required String userId,
    required String roleName,
    String? countryCode,
  }) async {
    try {
      // Build the select statement based on whether countryCode is provided
      final selectStatement = countryCode != null
          ? '''
            ${AppConstants.fieldId},
            ${AppConstants.tableRoles}!inner(${AppConstants.fieldRoleName}),
            ${AppConstants.tableCountries}!inner(${AppConstants.fieldCountryCode})
          '''
          : '''
            ${AppConstants.fieldId},
            ${AppConstants.tableRoles}!inner(${AppConstants.fieldRoleName})
          ''';

      var query = _supabase
          .from(AppConstants.tableProfileRoles)
          .select(selectStatement)
          .eq(AppConstants.fieldProfileRoleProfileId, userId)
          .eq(AppConstants.fieldProfileRoleIsActive, true)
          .eq('${AppConstants.tableRoles}.${AppConstants.fieldRoleName}',
              roleName);

      if (countryCode != null) {
        query = query.eq(
            '${AppConstants.tableCountries}.${AppConstants.fieldCountryCode}',
            countryCode);
      }

      final response = await query;
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.userHasRole error: $e');
      return false;
    }
  }

  /// Get users with a specific role
  static Future<List<Map<String, dynamic>>> getUsersWithRole({
    required String roleName,
    String? countryCode,
  }) async {
    try {
      var query = _supabase
          .from(AppConstants.tableProfileRoles)
          .select('''
            profiles!inner(
              ${AppConstants.fieldId},
              ${AppConstants.fieldProfileFullName},
              ${AppConstants.fieldProfileEmail}
            ),
            roles!inner(${AppConstants.fieldRoleName}),
            countries(
              ${AppConstants.fieldCountryName},
              ${AppConstants.fieldCountryCode}
            )
          ''')
          .eq(AppConstants.fieldProfileRoleIsActive, true)
          .eq('roles.${AppConstants.fieldRoleName}', roleName);

      if (countryCode != null) {
        query =
            query.eq('countries.${AppConstants.fieldCountryCode}', countryCode);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.getUsersWithRole error: $e');
      rethrow;
    }
  }

  // Convenience wrapper methods for backward compatibility

  /// Assign a role to a user using direct table insert (FIXED VERSION)
  /// This only affects profile_roles table, not authority_profiles
  static Future<void> assignRoleToUser({
    required String userId,
    required String roleId,
    String? countryId,
    DateTime? expiresAt,
  }) async {
    try {
      debugPrint('🔍 Assigning role to user: $userId, role: $roleId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      // Direct table insert - only insert into profile_roles
      // Do NOT touch authority_profiles table
      await _supabase.from(AppConstants.tableProfileRoles).insert({
        AppConstants.fieldProfileRoleProfileId: userId,
        AppConstants.fieldProfileRoleRoleId: roleId,
        AppConstants.fieldProfileRoleCountryId: countryId,
        AppConstants.fieldProfileRoleAssignedBy: currentUser.id,
        AppConstants.fieldProfileRoleExpiresAt: expiresAt?.toIso8601String(),
        AppConstants.fieldProfileRoleIsActive: true,
        AppConstants.fieldCreatedAt: DateTime.now().toIso8601String(),
        AppConstants.fieldUpdatedAt: DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Role assigned successfully');
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.assignRoleToUser error: $e');
      rethrow;
    }
  }

  /// Deactivate a role assignment (FIXED VERSION - SOFT DELETE)
  /// This only affects profile_roles table, not authority_profiles
  /// The user remains active in authority_profiles - only the specific role is deactivated
  static Future<void> removeRoleFromUser(String profileRoleId) async {
    try {
      debugPrint('🔍 Deactivating role assignment: $profileRoleId');

      // Direct table update - only deactivate the role in profile_roles
      // Do NOT touch authority_profiles table
      await _supabase.from(AppConstants.tableProfileRoles).update({
        AppConstants.fieldProfileRoleIsActive: false,
        AppConstants.fieldUpdatedAt: DateTime.now().toIso8601String(),
      }).eq(AppConstants.fieldId, profileRoleId);

      debugPrint(
          '✅ Role assignment deactivated successfully (user remains active in authority)');
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.removeRoleFromUser error: $e');
      rethrow;
    }
  }

  /// Permanently delete a role assignment (HARD DELETE)
  /// This only affects profile_roles table, not authority_profiles
  /// Use with caution - this cannot be undone
  static Future<void> deleteRoleFromUser(String profileRoleId) async {
    try {
      debugPrint('🔍 Permanently deleting role assignment: $profileRoleId');

      // Direct table delete - only delete from profile_roles
      // Do NOT touch authority_profiles table
      await _supabase
          .from(AppConstants.tableProfileRoles)
          .delete()
          .eq(AppConstants.fieldId, profileRoleId);

      debugPrint(
          '✅ Role assignment deleted permanently (user remains active in authority)');
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.deleteRoleFromUser error: $e');
      rethrow;
    }
  }

  /// Reactivate a previously deactivated role assignment
  /// This only affects profile_roles table, not authority_profiles
  static Future<void> reactivateRoleForUser(String profileRoleId) async {
    try {
      debugPrint('🔍 Reactivating role assignment: $profileRoleId');

      // Direct table update - only reactivate the role in profile_roles
      // Do NOT touch authority_profiles table
      await _supabase.from(AppConstants.tableProfileRoles).update({
        AppConstants.fieldProfileRoleIsActive: true,
        AppConstants.fieldUpdatedAt: DateTime.now().toIso8601String(),
      }).eq(AppConstants.fieldId, profileRoleId);

      debugPrint('✅ Role assignment reactivated successfully');
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.reactivateRoleForUser error: $e');
      rethrow;
    }
  }

  /// Update a role assignment using direct table update (FIXED VERSION)
  /// This only affects profile_roles table, not authority_profiles
  static Future<void> updateRoleAssignment({
    required String profileRoleId,
    String? countryId,
    DateTime? expiresAt,
    bool? isActive,
  }) async {
    try {
      debugPrint('🔍 Updating role assignment: $profileRoleId');

      final updateData = <String, dynamic>{
        AppConstants.fieldUpdatedAt: DateTime.now().toIso8601String(),
      };

      if (countryId != null) {
        updateData[AppConstants.fieldProfileRoleCountryId] = countryId;
      }

      if (expiresAt != null) {
        updateData[AppConstants.fieldProfileRoleExpiresAt] =
            expiresAt.toIso8601String();
      }

      if (isActive != null) {
        updateData[AppConstants.fieldProfileRoleIsActive] = isActive;
      }

      // Direct table update - only update the role in profile_roles
      // Do NOT touch authority_profiles table
      await _supabase
          .from(AppConstants.tableProfileRoles)
          .update(updateData)
          .eq(AppConstants.fieldId, profileRoleId);

      debugPrint('✅ Role assignment updated successfully');
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.updateRoleAssignment error: $e');
      rethrow;
    }
  }
}
