import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

/// Service for handling user role checks and permissions
class RoleService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if a user has a specific role
  ///
  /// [roleName] - The role to check for (use AppConstants.role* constants)
  /// [countryCode] - Optional country code for country-specific roles
  /// [userId] - Optional user ID, defaults to current user
  static Future<bool> profileHasRole(
    String roleName, {
    String? countryCode,
    String? userId,
  }) async {
    try {
      final params = <String, dynamic>{
        AppConstants.paramRoleName: roleName,
      };

      if (countryCode != null) {
        params[AppConstants.paramCountryCode] = countryCode;
      }

      if (userId != null) {
        params[AppConstants.paramUserId] = userId;
      }

      final result = await _supabase.rpc(
        AppConstants.profileHasRoleFunction,
        params: params,
      );

      return result as bool;
    } catch (e) {
      // Log error but don't throw - return false for safety
      debugPrint('❌ RoleService.userHasRole error: $e');
      return false;
    }
  }

  /// Check if current user is a superuser
  static Future<bool> isSuperuser() async {
    return profileHasRole(AppConstants.roleSuperuser);
  }

  /// Check if current user is a traveller
  static Future<bool> isTraveller() async {
    return profileHasRole(AppConstants.roleTraveller);
  }

  /// Check if current user is a country admin for a specific country
  static Future<bool> isCountryAdmin(String countryCode) async {
    return profileHasRole(
      AppConstants.roleCountryAdmin,
      countryCode: countryCode,
    );
  }

  /// Check if current user is a border official for a specific country
  static Future<bool> isBorderOfficial(String countryCode) async {
    return profileHasRole(
      AppConstants.roleBorderOfficial,
      countryCode: countryCode,
    );
  }

  /// Check if current user is a local authority for a specific country
  static Future<bool> isLocalAuthority(String countryCode) async {
    return profileHasRole(
      AppConstants.roleLocalAuthority,
      countryCode: countryCode,
    );
  }

  /// Check if current user is a country auditor for a specific country
  static Future<bool> isCountryAuditor(String countryCode) async {
    return profileHasRole(
      AppConstants.roleCountryAuditor,
      countryCode: countryCode,
    );
  }

  /// Check if current user has any admin role (superuser or country admin)
  static Future<bool> hasAdminRole() async {
    final isSuperuser = await RoleService.isSuperuser();
    if (isSuperuser) return true;

    // Check if user is country admin for any country
    return profileHasRole(AppConstants.roleCountryAdmin);
  }

  /// Check if current user has border official role (without country restriction)
  static Future<bool> hasBorderOfficialRole() async {
    return profileHasRole(AppConstants.roleBorderOfficial);
  }

  /// Check if current user has local authority role (without country restriction)
  static Future<bool> hasLocalAuthorityRole() async {
    return profileHasRole(AppConstants.roleLocalAuthority);
  }

  /// Check if current user has business intelligence role (without country restriction)
  static Future<bool> hasBusinessIntelligenceRole() async {
    return profileHasRole(AppConstants.roleBusinessIntelligence);
  }

  /// Check if current user has any auditor role (country auditor or superuser)
  static Future<bool> hasAuditorRole() async {
    final isSuperuser = await RoleService.isSuperuser();
    if (isSuperuser) return true;

    // Check if user is country auditor for any country
    return profileHasRole(AppConstants.roleCountryAuditor);
  }

  /// Get all roles for current user (for debugging/display purposes)
  static Future<List<String>> getCurrentUserRoles() async {
    final roles = <String>[];

    if (await isSuperuser()) roles.add(AppConstants.roleSuperuser);
    if (await isTraveller()) roles.add(AppConstants.roleTraveller);
    if (await profileHasRole(AppConstants.roleCountryAdmin)) {
      roles.add(AppConstants.roleCountryAdmin);
    }
    if (await profileHasRole(AppConstants.roleCountryAuditor)) {
      roles.add(AppConstants.roleCountryAuditor);
    }
    if (await profileHasRole(AppConstants.roleBorderOfficial)) {
      roles.add(AppConstants.roleBorderOfficial);
    }
    if (await profileHasRole(AppConstants.roleBusinessIntelligence)) {
      roles.add(AppConstants.roleBusinessIntelligence);
    }
    if (await profileHasRole(AppConstants.roleLocalAuthority)) {
      roles.add(AppConstants.roleLocalAuthority);
    }

    return roles;
  }

  /// Get countries where current user has country admin role
  static Future<List<Map<String, dynamic>>> getCountryAdminCountries() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No authenticated user');
        return [];
      }

      debugPrint(
          '🔍 Fetching country admin countries for user: ${currentUser.id}');

      final response = await _supabase
          .from(AppConstants.tableProfileRoles)
          .select('''
            ${AppConstants.fieldProfileRoleAuthorityId},
            ${AppConstants.tableAuthorities}!inner(
              ${AppConstants.fieldAuthorityCountryId},
              ${AppConstants.tableCountries}!inner(
                ${AppConstants.fieldId},
                ${AppConstants.fieldCountryName},
                ${AppConstants.fieldCountryCode},
                ${AppConstants.fieldCountryIsActive},
                ${AppConstants.fieldCountryIsGlobal},
                ${AppConstants.fieldCreatedAt},
                ${AppConstants.fieldUpdatedAt}
              )
            ),
            ${AppConstants.tableRoles}!inner(
              ${AppConstants.fieldRoleName}
            )
          ''')
          .eq(AppConstants.fieldProfileRoleProfileId, currentUser.id)
          .eq('${AppConstants.tableRoles}.${AppConstants.fieldRoleName}',
              AppConstants.roleCountryAdmin)
          .eq(AppConstants.fieldProfileRoleIsActive, true)
          .eq('${AppConstants.tableAuthorities}.${AppConstants.fieldAuthorityIsActive}',
              true)
          .eq('${AppConstants.tableAuthorities}.${AppConstants.tableCountries}.${AppConstants.fieldCountryIsActive}',
              true);

      debugPrint('✅ Retrieved ${response.length} country admin assignments');

      return response.map<Map<String, dynamic>>((item) {
        final authority = item[AppConstants.tableAuthorities];
        final country = authority[AppConstants.tableCountries];
        return {
          AppConstants.fieldId: country[AppConstants.fieldId],
          AppConstants.fieldCountryName: country[AppConstants.fieldCountryName],
          AppConstants.fieldCountryCode: country[AppConstants.fieldCountryCode],
          AppConstants.fieldCountryIsActive:
              country[AppConstants.fieldCountryIsActive],
          AppConstants.fieldCountryIsGlobal:
              country[AppConstants.fieldCountryIsGlobal],
          AppConstants.fieldCreatedAt: country[AppConstants.fieldCreatedAt],
          AppConstants.fieldUpdatedAt: country[AppConstants.fieldUpdatedAt],
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching country admin countries: $e');
      return [];
    }
  }
}
