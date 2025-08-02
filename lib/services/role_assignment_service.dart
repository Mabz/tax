import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

/// Service for managing user role assignments
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
      final response = await _supabase
          .from(AppConstants.tableRoles)
          .select('''
            ${AppConstants.fieldId},
            ${AppConstants.fieldRoleName},
            ${AppConstants.fieldRoleDisplayName},
            ${AppConstants.fieldRoleDescription}
          ''')
          .order(AppConstants.fieldRoleDisplayName);

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
          .eq('${AppConstants.tableRoles}.${AppConstants.fieldRoleName}', roleName);

      if (countryCode != null) {
        query = query.eq('${AppConstants.tableCountries}.${AppConstants.fieldCountryCode}', countryCode);
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
        query = query.eq('countries.${AppConstants.fieldCountryCode}', countryCode);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.getUsersWithRole error: $e');
      rethrow;
    }
  }

  // Convenience wrapper methods for backward compatibility
  
  /// Assign a role to a user using Supabase function
  static Future<void> assignRoleToUser({
    required String userId,
    required String roleId,
    String? countryId,
    DateTime? expiresAt,
  }) async {
    try {
      final response = await _supabase.rpc('assign_role_to_profile', params: {
        'p_profile_id': userId,
        'p_role_id': roleId,
        'p_country_id': countryId,
        'p_expires_at': expiresAt?.toIso8601String(),
      });

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Failed to assign role');
      }
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.assignRoleToUser error: $e');
      rethrow;
    }
  }

  /// Remove a role from a user using Supabase function
  static Future<void> removeRoleFromUser(String profileRoleId) async {
    try {
      final response = await _supabase.rpc('remove_role_from_profile', params: {
        'p_profile_role_id': profileRoleId,
      });

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Failed to remove role');
      }
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.removeRoleFromUser error: $e');
      rethrow;
    }
  }

  /// Update a role assignment using Supabase function
  static Future<void> updateRoleAssignment({
    required String profileRoleId,
    String? countryId,
    DateTime? expiresAt,
    bool? isActive,
  }) async {
    try {
      final response = await _supabase.rpc('update_role_assignment', params: {
        'p_profile_role_id': profileRoleId,
        'p_country_id': countryId,
        'p_expires_at': expiresAt?.toIso8601String(),
        'p_is_active': isActive,
      });

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Failed to update role assignment');
      }
    } catch (e) {
      debugPrint('❌ RoleAssignmentService.updateRoleAssignment error: $e');
      rethrow;
    }
  }
}
