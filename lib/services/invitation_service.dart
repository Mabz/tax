import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../models/role_invitation.dart';
import '../services/role_service.dart';

/// Service for managing role invitations
class InvitationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Send a role invitation using database function
  static Future<void> inviteUserToRole({
    required String email,
    required String roleName,
    required String countryCode,
  }) async {
    try {
      debugPrint(
          '🔍 Sending invitation - Email: $email, Role: $roleName, Country: $countryCode');

      await _supabase.rpc(AppConstants.inviteUserToRoleFunction, params: {
        'target_email': email.toLowerCase(),
        'target_role_name': roleName,
        'target_country_code': countryCode,
      });

      debugPrint('✅ Invitation sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending invitation: $e');
      rethrow;
    }
  }

  /// Get all invitations for a specific country using the new database function
  static Future<List<RoleInvitation>> getAllInvitationsForCountry(String countryId) async {
    try {
      debugPrint('🔍 Fetching all invitations for country using new function: $countryId');

      final response = await _supabase.rpc(
        AppConstants.getAllInvitationsForCountryFunction,
        params: {'target_country_id': countryId},
      );

      debugPrint('✅ Fetched ${response.length} invitations for country');

      // Convert to RoleInvitation objects
      return response.map<RoleInvitation>((json) {
        // Map the database function results to RoleInvitation format
        final mapped = {
          AppConstants.fieldId: json['id'],
          AppConstants.fieldRoleInvitationEmail: json['email'],
          AppConstants.fieldRoleInvitationStatus: json['status'],
          AppConstants.fieldRoleInvitationInvitedAt: json['invited_at'],
          AppConstants.fieldRoleInvitationRespondedAt: json['responded_at'],
          // Now using the actual fields from the updated database function
          AppConstants.fieldRoleInvitationRoleId: json['role_id'],
          AppConstants.fieldRoleInvitationCountryId: json['country_id'],
          AppConstants.fieldRoleInvitationInvitedBy: json['invited_by_profile_id'],
          // Optional fields
          AppConstants.fieldRoleName: json['role_name'],
          AppConstants.fieldRoleDisplayName: json['role_name'], // Use role_name as display name
          AppConstants.fieldRoleDescription: json['role_description'],
          'inviter_name': json['invited_by_name'],
          'inviter_email': json['invited_by_email'],
          // Add required fields for RoleInvitation model
          AppConstants.fieldCreatedAt: json['invited_at'],
          AppConstants.fieldUpdatedAt: json['responded_at'] ?? json['invited_at'],
        };

        return RoleInvitation.fromJson(mapped);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching all invitations for country: $e');
      return [];
    }
  }

  /// Get invitations for a specific country (legacy method)
  static Future<List<RoleInvitation>> getInvitationsForCountry(String countryId) async {
    try {
      debugPrint('🔍 Fetching invitations for country: $countryId');

      final response = await _supabase
          .from(AppConstants.tableRoleInvitations)
          .select('''
            ${AppConstants.fieldId},
            ${AppConstants.fieldRoleInvitationEmail},
            ${AppConstants.fieldRoleInvitationRoleId},
            ${AppConstants.fieldRoleInvitationCountryId},
            ${AppConstants.fieldRoleInvitationInvitedBy},
            ${AppConstants.fieldRoleInvitationInvitedAt},
            ${AppConstants.fieldRoleInvitationStatus},
            ${AppConstants.fieldRoleInvitationRespondedAt},
            ${AppConstants.fieldCreatedAt},
            ${AppConstants.fieldUpdatedAt},
            ${AppConstants.tableRoles}!inner(
              ${AppConstants.fieldRoleName},
              ${AppConstants.fieldRoleDisplayName}
            ),
            ${AppConstants.tableCountries}!inner(
              ${AppConstants.fieldCountryName},
              ${AppConstants.fieldCountryCode}
            ),
            inviter:${AppConstants.tableProfiles}!${AppConstants.fieldRoleInvitationInvitedBy}(
              ${AppConstants.fieldProfileFullName}
            )
          ''')
          .eq(AppConstants.fieldRoleInvitationCountryId, countryId)
          .order(AppConstants.fieldRoleInvitationInvitedAt, ascending: false);

      debugPrint('✅ Fetched ${response.length} invitations for country');

      // Convert to RoleInvitation objects
      return response.map((json) {
        // Flatten nested objects for the model
        final flattened = Map<String, dynamic>.from(json);

        // Extract role information
        if (json[AppConstants.tableRoles] != null) {
          final role = json[AppConstants.tableRoles] as Map<String, dynamic>;
          flattened[AppConstants.fieldRoleName] =
              role[AppConstants.fieldRoleName];
          flattened[AppConstants.fieldRoleDisplayName] =
              role[AppConstants.fieldRoleDisplayName];
        }

        // Extract country information
        if (json[AppConstants.tableCountries] != null) {
          final country =
              json[AppConstants.tableCountries] as Map<String, dynamic>;
          flattened[AppConstants.fieldCountryName] =
              country[AppConstants.fieldCountryName];
          flattened[AppConstants.fieldCountryCode] =
              country[AppConstants.fieldCountryCode];
        }

        // Extract inviter information
        if (json['inviter'] != null) {
          final inviter = json['inviter'] as Map<String, dynamic>;
          flattened['inviter_name'] =
              inviter[AppConstants.fieldProfileFullName];
        }

        return RoleInvitation.fromJson(flattened);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching invitations for country: $e');
      return [];
    }
  }

  /// Get all invitations for admin management (superuser sees all, country admin sees their countries)
  static Future<List<RoleInvitation>> getAllInvitations() async {
    try {
      debugPrint('🔍 Fetching all invitations for admin management');

      // Check if user is superuser
      final isSuperuser = await RoleService.isSuperuser();

      List<Map<String, dynamic>> response;

      if (isSuperuser) {
        // Superusers can see all invitations
        response =
            await _supabase.from(AppConstants.tableRoleInvitations).select('''
              ${AppConstants.fieldId},
              ${AppConstants.fieldRoleInvitationEmail},
              ${AppConstants.fieldRoleInvitationRoleId},
              ${AppConstants.fieldRoleInvitationCountryId},
              ${AppConstants.fieldRoleInvitationInvitedBy},
              ${AppConstants.fieldRoleInvitationInvitedAt},
              ${AppConstants.fieldRoleInvitationStatus},
              ${AppConstants.fieldRoleInvitationRespondedAt},
              ${AppConstants.fieldCreatedAt},
              ${AppConstants.fieldUpdatedAt},
              ${AppConstants.tableRoles}!inner(
                ${AppConstants.fieldRoleName},
                ${AppConstants.fieldRoleDisplayName}
              ),
              ${AppConstants.tableCountries}!inner(
                ${AppConstants.fieldCountryName},
                ${AppConstants.fieldCountryCode}
              ),
              inviter:${AppConstants.tableProfiles}!${AppConstants.fieldRoleInvitationInvitedBy}(
                ${AppConstants.fieldProfileFullName}
              )
            ''').order(AppConstants.fieldRoleInvitationInvitedAt, ascending: false);

        debugPrint('✅ Fetched ${response.length} invitations (superuser)');
      } else {
        // Country admins can only see invitations for their countries
        final countries = await RoleService.getCountryAdminCountries();
        if (countries.isEmpty) return [];

        final countryIds =
            countries.map((c) => c[AppConstants.fieldId]).toList();

        response = await _supabase
            .from(AppConstants.tableRoleInvitations)
            .select('''
              ${AppConstants.fieldId},
              ${AppConstants.fieldRoleInvitationEmail},
              ${AppConstants.fieldRoleInvitationRoleId},
              ${AppConstants.fieldRoleInvitationCountryId},
              ${AppConstants.fieldRoleInvitationInvitedBy},
              ${AppConstants.fieldRoleInvitationInvitedAt},
              ${AppConstants.fieldRoleInvitationStatus},
              ${AppConstants.fieldRoleInvitationRespondedAt},
              ${AppConstants.fieldCreatedAt},
              ${AppConstants.fieldUpdatedAt},
              ${AppConstants.tableRoles}!inner(
                ${AppConstants.fieldRoleName},
                ${AppConstants.fieldRoleDisplayName}
              ),
              ${AppConstants.tableCountries}!inner(
                ${AppConstants.fieldCountryName},
                ${AppConstants.fieldCountryCode}
              ),
              inviter:${AppConstants.tableProfiles}!${AppConstants.fieldRoleInvitationInvitedBy}(
                ${AppConstants.fieldProfileFullName}
              )
            ''')
            .inFilter(AppConstants.fieldRoleInvitationCountryId, countryIds)
            .order(AppConstants.fieldRoleInvitationInvitedAt, ascending: false);

        debugPrint('✅ Fetched ${response.length} invitations (country admin)');
      }

      // Convert to RoleInvitation objects
      return response.map((json) {
        // Flatten nested objects for the model
        final flattened = Map<String, dynamic>.from(json);

        // Extract role information
        if (json[AppConstants.tableRoles] != null) {
          final role = json[AppConstants.tableRoles] as Map<String, dynamic>;
          flattened[AppConstants.fieldRoleName] =
              role[AppConstants.fieldRoleName];
          flattened[AppConstants.fieldRoleDisplayName] =
              role[AppConstants.fieldRoleDisplayName];
        }

        // Extract country information
        if (json[AppConstants.tableCountries] != null) {
          final country =
              json[AppConstants.tableCountries] as Map<String, dynamic>;
          flattened[AppConstants.fieldCountryName] =
              country[AppConstants.fieldCountryName];
          flattened[AppConstants.fieldCountryCode] =
              country[AppConstants.fieldCountryCode];
        }

        // Extract inviter information
        if (json['inviter'] != null) {
          final inviter = json['inviter'] as Map<String, dynamic>;
          flattened['inviter_name'] =
              inviter[AppConstants.fieldProfileFullName];
        }

        return RoleInvitation.fromJson(flattened);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching invitations: $e');
      return [];
    }
  }

  /// Get pending invitations for current user (for invitation dashboard)
  static Future<List<RoleInvitation>> getPendingInvitationsForUser() async {
    try {
      debugPrint('🔍 Fetching pending invitations for current user');

      final response =
          await _supabase.rpc(AppConstants.getPendingInvitationsFunction);

      debugPrint('✅ Fetched ${response.length} pending invitations for user');

      // Convert response to RoleInvitation objects
      return (response as List).map((json) {
        // Map function response to RoleInvitation format
        final mapped = {
          AppConstants.fieldId: json[AppConstants.dbFieldId],
          AppConstants.fieldRoleInvitationEmail:
              json[AppConstants.dbFieldEmail] ?? '',
          AppConstants.fieldRoleInvitationRoleId:
              '', // Not provided by function
          AppConstants.fieldRoleInvitationCountryId:
              '', // Not provided by function
          AppConstants.fieldRoleInvitationInvitedBy:
              '', // Not provided by function
          AppConstants.fieldRoleInvitationInvitedAt:
              json[AppConstants.dbFieldInvitedAt] ??
                  DateTime.now().toIso8601String(),
          AppConstants.fieldRoleInvitationStatus:
              AppConstants.invitationStatusPending,
          AppConstants.fieldRoleInvitationRespondedAt: null,
          AppConstants.fieldCreatedAt: json[AppConstants.dbFieldInvitedAt] ??
              DateTime.now().toIso8601String(),
          AppConstants.fieldUpdatedAt: json[AppConstants.dbFieldInvitedAt] ??
              DateTime.now().toIso8601String(),
          'role_name': json[AppConstants.dbFieldRoleName] ?? '',
          AppConstants.fieldRoleDisplayName:
              json[AppConstants.dbFieldRoleName] ??
                  '', // Use role_name as display name
          AppConstants.fieldRoleDescription:
              json[AppConstants.dbFieldRoleDescription] ?? '',
          'country_name':
              json[AppConstants.dbFieldCountryName] ?? '',
          AppConstants.fieldCountryCode:
              json[AppConstants.dbFieldCountryCode] ?? '',
        };

        return RoleInvitation.fromJson(mapped);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching pending invitations for user: $e');
      return [];
    }
  }

  /// Accept a role invitation using database function
  static Future<void> acceptInvitation(String invitationId) async {
    try {
      debugPrint('🔍 Accepting invitation: $invitationId');

      await _supabase.rpc(AppConstants.acceptRoleInvitationFunction, params: {
        'invite_id': invitationId,
      });

      debugPrint('✅ Invitation accepted successfully');
    } catch (e) {
      debugPrint('❌ Error accepting invitation: $e');
      rethrow;
    }
  }

  /// Decline a role invitation using database function
  static Future<void> declineInvitation(String invitationId) async {
    try {
      debugPrint('🔍 Declining invitation: $invitationId');

      await _supabase.rpc(AppConstants.declineRoleInvitationFunction, params: {
        'invite_id': invitationId,
      });

      debugPrint('✅ Invitation declined successfully');
    } catch (e) {
      debugPrint('❌ Error declining invitation: $e');
      rethrow;
    }
  }

  /// Delete/cancel a role invitation using database function
  static Future<void> deleteInvitation(String invitationId) async {
    try {
      debugPrint('🔍 Deleting invitation: $invitationId');

      await _supabase.rpc(AppConstants.deleteRoleInvitationFunction, params: {
        'invite_id': invitationId,
      });

      debugPrint('✅ Invitation deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting invitation: $e');
      rethrow;
    }
  }

  /// Resend a role invitation using database function
  static Future<void> resendInvitation(String invitationId) async {
    try {
      debugPrint('🔍 Resending invitation: $invitationId');

      await _supabase.rpc(AppConstants.resendInvitationFunction, params: {
        'invite_id': invitationId,
      });

      debugPrint('✅ Invitation resent successfully');
    } catch (e) {
      debugPrint('❌ Error resending invitation: $e');
      rethrow;
    }
  }

  /// Get available roles that can be invited
  static Future<List<Map<String, dynamic>>> getInvitableRoles() async {
    try {
      debugPrint('🔍 Fetching invitable roles');

      final isSuperuser = await RoleService.isSuperuser();

      if (isSuperuser) {
        // Superusers can invite to any role except traveller (including superuser)
        final response = await _supabase
            .from(AppConstants.tableRoles)
            .select(
                '${AppConstants.fieldRoleName}, ${AppConstants.fieldRoleDisplayName}, ${AppConstants.fieldRoleDescription}')
            .neq(AppConstants.fieldRoleName, AppConstants.roleTraveller)
            .order(AppConstants.fieldRoleDisplayName);

        debugPrint('✅ Fetched ${response.length} invitable roles (superuser)');
        return response;
      } else {
        // Country admins can only invite to country-specific roles (no superuser)
        final response = await _supabase
            .from(AppConstants.tableRoles)
            .select(
                '${AppConstants.fieldRoleName}, ${AppConstants.fieldRoleDisplayName}, ${AppConstants.fieldRoleDescription}')
            .inFilter(AppConstants.fieldRoleName, [
          AppConstants.roleCountryAdmin,
          AppConstants.roleCountryAuditor,
          AppConstants.roleBorderOfficial,
          AppConstants.roleLocalAuthority,
        ]).order(AppConstants.fieldRoleDisplayName);

        debugPrint(
            '✅ Fetched ${response.length} invitable roles (country admin)');
        return response;
      }
    } catch (e) {
      debugPrint('❌ Error fetching invitable roles: $e');
      return [];
    }
  }

  /// Check if current user can send invitations
  static Future<bool> canSendInvitations() async {
    try {
      final isSuperuser = await RoleService.isSuperuser();
      if (isSuperuser) return true;

      final hasAdminRole = await RoleService.hasAdminRole();
      return hasAdminRole;
    } catch (e) {
      debugPrint('❌ Error checking invitation permissions: $e');
      return false;
    }
  }
}
