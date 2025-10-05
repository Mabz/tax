import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../models/role_invitation.dart';
import '../services/role_service.dart';

/// Service for managing role invitations
class InvitationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Send a role invitation using database function (authority-based)
  static Future<void> inviteUserToRole({
    required String email,
    required String roleName,
    required String authorityId,
  }) async {
    try {
      debugPrint(
          '🔍 Sending invitation - Email: $email, Role: $roleName, Authority: $authorityId');

      // Get current user ID for invited_by_profile_id
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      // Try the fixed RPC function first (with prefixed parameters)
      try {
        await _supabase.rpc(AppConstants.inviteProfileToRoleFunction, params: {
          'p_authority_id': authorityId,
          'p_invited_by_profile_id': currentUser.id,
          'p_role_name': roleName,
          'p_target_email': email.toLowerCase(),
        });
        debugPrint('✅ Invitation sent successfully via fixed RPC function');
        return;
      } catch (rpcError) {
        debugPrint('⚠️ Fixed RPC function failed: $rpcError');
        debugPrint('🔄 Trying original parameter names...');

        // Fallback to original parameter names in case the function hasn't been updated yet
        try {
          await _supabase
              .rpc(AppConstants.inviteProfileToRoleFunction, params: {
            'authority_id': authorityId,
            'invited_by_profile_id': currentUser.id,
            'role_name': roleName,
            'target_email': email.toLowerCase(),
          });
          debugPrint(
              '✅ Invitation sent successfully via original RPC function');
          return;
        } catch (originalError) {
          debugPrint('⚠️ Original RPC function also failed: $originalError');

          // Final error message with instructions
          throw Exception(
              'Unable to send invitation. The database functions need to be fixed.\n\n'
              'SOLUTION: Please run this SQL command in your database:\n\n'
              'CREATE OR REPLACE FUNCTION public.invite_profile_to_role(\n'
              '    p_authority_id UUID,\n'
              '    p_invited_by_profile_id UUID,\n'
              '    p_role_name TEXT,\n'
              '    p_target_email TEXT\n'
              ') RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS \$\$\n'
              'DECLARE v_role_id UUID;\n'
              'BEGIN\n'
              '    SELECT id INTO v_role_id FROM roles WHERE name = p_role_name;\n'
              '    IF v_role_id IS NULL THEN RAISE EXCEPTION \'Role not found\';\n'
              '    END IF;\n'
              '    INSERT INTO role_invitations (email, role_id, authority_id, invited_by_profile_id, invited_at, status)\n'
              '    VALUES (LOWER(p_target_email), v_role_id, p_authority_id, p_invited_by_profile_id, NOW(), \'pending\');\n'
              'END; \$\$;\n\n'
              'Or use the quick_fix.sql file provided.\n\n'
              'Errors:\n'
              '1. Fixed function: $rpcError\n'
              '2. Original function: $originalError');
        }
      }
    } catch (e) {
      debugPrint('❌ Error sending invitation: $e');
      rethrow;
    }
  }

  /// Legacy method: Send a role invitation by country code (deprecated)
  static Future<void> inviteUserToRoleByCountry({
    required String email,
    required String roleName,
    required String countryCode,
  }) async {
    try {
      debugPrint(
          '🔍 Sending invitation (legacy) - Email: $email, Role: $roleName, Country: $countryCode');

      await _supabase.rpc(AppConstants.inviteUserToRoleFunction, params: {
        'target_email': email.toLowerCase(),
        'target_role_name': roleName,
        'target_country_code': countryCode,
      });

      debugPrint('✅ Invitation sent successfully (legacy)');
    } catch (e) {
      debugPrint('❌ Error sending invitation (legacy): $e');
      rethrow;
    }
  }

  /// Get all invitations for a specific authority
  static Future<List<RoleInvitation>> getAllInvitationsForAuthority(
      String authorityId) async {
    try {
      debugPrint('🔍 Fetching all invitations for authority: $authorityId');

      final response = await _supabase.rpc(
        AppConstants.getAllInvitationsForAuthorityFunction,
        params: {'target_authority_id': authorityId},
      );

      debugPrint('✅ Fetched ${response.length} invitations for authority');

      // Debug: Log the first few raw responses to see what we're getting
      for (int i = 0; i < response.length && i < 1; i++) {
        debugPrint('🔍 Raw invitation $i keys: ${response[i].keys.toList()}');
        debugPrint('🔍 Raw invitation $i data: ${response[i]}');
        // Check for common ID field names
        debugPrint('   id: ${response[i]['id']}');
        debugPrint('   invitation_id: ${response[i]['invitation_id']}');
        debugPrint('   invite_id: ${response[i]['invite_id']}');
      }

      // Convert to RoleInvitation objects - temporarily without filtering to see the data
      return response.map<RoleInvitation>((json) {
        // Try different possible ID field names from the database function
        final invitationId = json['invitation_id'] ??
            json['id'] ??
            json['invite_id'] ??
            'temp-${DateTime.now().millisecondsSinceEpoch}-${json['email']}';

        if (json['invitation_id'] == null &&
            json['id'] == null &&
            json['invite_id'] == null) {
          debugPrint(
              '⚠️ Warning: No ID field found for invitation: ${json['email']} - ${json['role_name']}');
          debugPrint('   Available keys: ${json.keys.toList()}');
          debugPrint('   Using temporary ID: $invitationId');
        }

        // Map the database function results to RoleInvitation format
        final mapped = {
          AppConstants.fieldId:
              invitationId, // Use the found ID or temporary one
          AppConstants.fieldRoleInvitationEmail: json['email'] ?? '',
          AppConstants.fieldRoleInvitationStatus: json['status'] ?? 'pending',
          AppConstants.fieldRoleInvitationInvitedAt:
              json['invited_at'] ?? DateTime.now().toIso8601String(),
          AppConstants.fieldRoleInvitationRespondedAt: json['responded_at'],
          // Required fields for RoleInvitation model
          AppConstants.fieldRoleInvitationRoleId: json['role_id'] ?? '',
          AppConstants.fieldRoleInvitationAuthorityId: authorityId,
          AppConstants.fieldRoleInvitationInvitedBy:
              json['invited_by_profile_id'] ?? '',
          // Optional fields from the authority function
          AppConstants.fieldRoleName: json['role_name'] ?? '',
          AppConstants.fieldRoleDisplayName:
              json['role_display_name'] ?? json['role_name'] ?? '',
          AppConstants.fieldRoleDescription: json['role_description'] ?? '',
          'inviter_name': json['inviter_name'] ?? 'Unknown',
          'inviter_email': json['inviter_email'] ?? '',
          'authority_name': json['authority_name'] ?? '',
          'country_name': json['country_name'] ?? '',
          // Add required fields for RoleInvitation model
          AppConstants.fieldCreatedAt:
              json['invited_at'] ?? DateTime.now().toIso8601String(),
          AppConstants.fieldUpdatedAt: json['responded_at'] ??
              json['invited_at'] ??
              DateTime.now().toIso8601String(),
        };

        return RoleInvitation.fromJson(mapped);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching all invitations for authority: $e');
      return [];
    }
  }

  /// Get all invitations for a specific country using the authority-based function
  static Future<List<RoleInvitation>> getAllInvitationsForCountry(
      String countryId) async {
    try {
      if (countryId.isEmpty) {
        debugPrint('❌ Empty country ID provided');
        return [];
      }

      debugPrint('🔍 Fetching all invitations for country: $countryId');

      // First, get the authority ID for this country
      final authorityId = await _getAuthorityIdForCountry(countryId);
      if (authorityId == null || authorityId.isEmpty) {
        debugPrint('⚠️ No active authority found for country: $countryId');
        return [];
      }

      debugPrint('✅ Found authority: $authorityId for country: $countryId');

      // Now get invitations for the authority
      final response = await _supabase.rpc(
        AppConstants.getAllInvitationsForAuthorityFunction,
        params: {'target_authority_id': authorityId},
      );

      debugPrint('✅ Fetched ${response.length} invitations for authority');

      // Convert to RoleInvitation objects
      return response.map<RoleInvitation>((json) {
        // Map the database function results to RoleInvitation format
        final mapped = {
          AppConstants.fieldId: json['invitation_id'] ?? '',
          AppConstants.fieldRoleInvitationEmail: json['email'] ?? '',
          AppConstants.fieldRoleInvitationStatus: json['status'] ?? 'pending',
          AppConstants.fieldRoleInvitationInvitedAt:
              json['invited_at'] ?? DateTime.now().toIso8601String(),
          AppConstants.fieldRoleInvitationRespondedAt: json['responded_at'],
          // Required fields for RoleInvitation model
          AppConstants.fieldRoleInvitationRoleId: json['role_id'] ?? '',
          AppConstants.fieldRoleInvitationCountryId: countryId,
          AppConstants.fieldRoleInvitationInvitedBy:
              json['invited_by_profile_id'] ?? '',
          // Optional fields from the authority function
          AppConstants.fieldRoleName: json['role_name'] ?? '',
          AppConstants.fieldRoleDisplayName:
              json['role_display_name'] ?? json['role_name'] ?? '',
          AppConstants.fieldRoleDescription: json['role_description'] ?? '',
          'inviter_name': json['inviter_name'] ?? 'Unknown',
          'inviter_email': json['inviter_email'] ?? '',
          'authority_name': json['authority_name'] ?? '',
          'country_name': json['country_name'] ?? '',
          // Add required fields for RoleInvitation model
          AppConstants.fieldCreatedAt:
              json['invited_at'] ?? DateTime.now().toIso8601String(),
          AppConstants.fieldUpdatedAt: json['responded_at'] ??
              json['invited_at'] ??
              DateTime.now().toIso8601String(),
        };

        return RoleInvitation.fromJson(mapped);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching all invitations for country: $e');
      return [];
    }
  }

  /// Get authority ID for a specific country (bridge method for authority migration)
  /// This method finds the active authority for a given country
  static Future<String?> _getAuthorityIdForCountry(String countryId) async {
    try {
      debugPrint('🔍 Finding authority for country: $countryId');

      final authorityResponse = await _supabase
          .from(AppConstants.tableAuthorities)
          .select(AppConstants.fieldId)
          .eq(AppConstants.fieldAuthorityCountryId, countryId)
          .eq(AppConstants.fieldAuthorityIsActive, true)
          .maybeSingle();

      if (authorityResponse == null) {
        debugPrint('⚠️ No active authority found for country: $countryId');
        return null;
      }

      final authorityId = authorityResponse[AppConstants.fieldId] as String;
      debugPrint('✅ Found authority: $authorityId for country: $countryId');
      return authorityId;
    } catch (e) {
      debugPrint('❌ Error finding authority for country $countryId: $e');
      rethrow;
    }
  }

  /// Get invitations for a specific country (legacy method)
  static Future<List<RoleInvitation>> getInvitationsForCountry(
      String countryId) async {
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
          AppConstants.fieldId: json['id'],
          AppConstants.fieldRoleInvitationEmail: json['email'] ?? '',
          AppConstants.fieldRoleInvitationRoleId:
              '', // Not provided by function
          AppConstants.fieldRoleInvitationAuthorityId:
              '', // Not provided by function
          AppConstants.fieldRoleInvitationInvitedBy:
              '', // Not provided by function
          AppConstants.fieldRoleInvitationInvitedAt:
              json['invited_at'] ?? DateTime.now().toIso8601String(),
          AppConstants.fieldRoleInvitationStatus:
              AppConstants.invitationStatusPending,
          AppConstants.fieldRoleInvitationRespondedAt: null,
          AppConstants.fieldCreatedAt:
              json['invited_at'] ?? DateTime.now().toIso8601String(),
          AppConstants.fieldUpdatedAt:
              json['invited_at'] ?? DateTime.now().toIso8601String(),
          // Use db field aliases to avoid key collisions with generic 'name'
          AppConstants.dbFieldRoleName: json['role_name'] ?? '',
          AppConstants.fieldRoleDisplayName: json['role_display_name'] ??
              json['role_name'] ??
              '', // Use display_name first, fallback to role_name
          AppConstants.dbFieldRoleDescription: json['role_description'] ?? '',
          'authority_name': json['authority_name'] ?? '',
          AppConstants.dbFieldCountryName: json['country_name'] ?? '',
          AppConstants.dbFieldCountryCode: json['country_code'] ?? '',
          'inviter_name': json['inviter_name'] ?? '',
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
      // Validate invitation ID
      if (invitationId.isEmpty) {
        throw Exception(
            'Cannot accept invitation: Invalid invitation ID (empty)');
      }

      debugPrint('🔍 Accepting invitation: $invitationId');

      // Try with invitation_id parameter first (correct parameter name)
      try {
        await _supabase.rpc(AppConstants.acceptRoleInvitationFunction, params: {
          'invitation_id': invitationId,
        });
        debugPrint('✅ Invitation accepted successfully');
        return;
      } catch (e) {
        debugPrint('⚠️ Failed with invitation_id parameter: $e');
        // Fallback to invite_id parameter
        await _supabase.rpc(AppConstants.acceptRoleInvitationFunction, params: {
          'invite_id': invitationId,
        });
        debugPrint('✅ Invitation accepted successfully (fallback)');
      }
    } catch (e) {
      debugPrint('❌ Error accepting invitation: $e');
      rethrow;
    }
  }

  /// Decline a role invitation using database function
  static Future<void> declineInvitation(String invitationId) async {
    try {
      // Validate invitation ID
      if (invitationId.isEmpty) {
        throw Exception(
            'Cannot decline invitation: Invalid invitation ID (empty)');
      }

      debugPrint('🔍 Declining invitation: $invitationId');

      // Try with invitation_id parameter first (correct parameter name)
      try {
        await _supabase
            .rpc(AppConstants.declineRoleInvitationFunction, params: {
          'invitation_id': invitationId,
        });
        debugPrint('✅ Invitation declined successfully');
        return;
      } catch (e) {
        debugPrint('⚠️ Failed with invitation_id parameter: $e');
        // Fallback to invite_id parameter
        await _supabase
            .rpc(AppConstants.declineRoleInvitationFunction, params: {
          'invite_id': invitationId,
        });
        debugPrint('✅ Invitation declined successfully (fallback)');
      }
    } catch (e) {
      debugPrint('❌ Error declining invitation: $e');
      rethrow;
    }
  }

  /// Delete/cancel a role invitation using database function
  static Future<void> deleteInvitation(String invitationId) async {
    try {
      // Validate invitation ID
      if (invitationId.isEmpty) {
        throw Exception(
            'Cannot delete invitation: Invalid invitation ID (empty)');
      }

      debugPrint('🔍 Deleting invitation: $invitationId');

      // Try with invitation_id parameter first (correct parameter name)
      try {
        await _supabase.rpc(AppConstants.deleteRoleInvitationFunction, params: {
          'invitation_id': invitationId,
        });
        debugPrint('✅ Invitation deleted successfully');
        return;
      } catch (e) {
        debugPrint('⚠️ Failed with invitation_id parameter: $e');
        // Fallback to invite_id parameter
        await _supabase.rpc(AppConstants.deleteRoleInvitationFunction, params: {
          'invite_id': invitationId,
        });
        debugPrint('✅ Invitation deleted successfully (fallback)');
      }
    } catch (e) {
      debugPrint('❌ Error deleting invitation: $e');
      rethrow;
    }
  }

  /// Resend a role invitation using database function
  static Future<void> resendInvitation(String invitationId) async {
    try {
      // Validate invitation ID
      if (invitationId.isEmpty) {
        throw Exception(
            'Cannot resend invitation: Invalid invitation ID (empty)');
      }

      debugPrint('🔍 Resending invitation: $invitationId');

      // Try with invitation_id parameter first (correct parameter name)
      try {
        await _supabase.rpc(AppConstants.resendInvitationFunction, params: {
          'invitation_id': invitationId,
        });
        debugPrint('✅ Invitation resent successfully');
        return;
      } catch (e) {
        debugPrint('⚠️ Failed with invitation_id parameter: $e');
        // Fallback to invite_id parameter
        await _supabase.rpc(AppConstants.resendInvitationFunction, params: {
          'invite_id': invitationId,
        });
        debugPrint('✅ Invitation resent successfully (fallback)');
      }
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
          AppConstants.roleBusinessIntelligence,
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
