import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../models/authority_profile.dart';

/// Service for managing user profiles within authorities (User Management)
/// This service handles authority_profiles table - separate from role management
class AuthorityProfilesService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all profiles for a specific authority
  static Future<List<AuthorityProfile>> getAuthorityProfiles(
      String authorityId) async {
    try {
      final response = await _supabase
          .from('authority_profiles')
          .select('''
            id,
            profile_id,
            authority_id,
            is_active,
            created_at,
            updated_at,
            display_name,
            profiles!authority_profiles_profile_id_fkey(
              id,
              full_name,
              email,
              profile_image_url
            ),
            authorities!inner(
              id,
              name,
              code
            )
          ''')
          .eq('authority_id', authorityId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => AuthorityProfile.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ AuthorityProfilesService.getAuthorityProfiles error: $e');
      rethrow;
    }
  }

  /// Add a user to an authority (User Management function)
  /// This affects authority_profiles table only
  static Future<void> addUserToAuthority({
    required String profileId,
    required String authorityId,
  }) async {
    try {
      debugPrint('🔍 Adding user to authority: $profileId -> $authorityId');

      // Check if user is already in the authority
      final existing = await _supabase
          .from('authority_profiles')
          .select('id, is_active')
          .eq('profile_id', profileId)
          .eq('authority_id', authorityId)
          .maybeSingle();

      if (existing != null) {
        if (existing['is_active'] == false) {
          // Reactivate existing inactive record
          await _supabase.from('authority_profiles').update({
            'is_active': true,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', existing['id']);
          debugPrint('✅ User reactivated in authority');
        } else {
          throw Exception('User is already active in this authority');
        }
      } else {
        // Create new authority profile record
        await _supabase.from('authority_profiles').insert({
          'profile_id': profileId,
          'authority_id': authorityId,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ User added to authority successfully');
      }
    } catch (e) {
      debugPrint('❌ AuthorityProfilesService.addUserToAuthority error: $e');
      rethrow;
    }
  }

  /// Remove a user from an authority (User Management function)
  /// This affects authority_profiles table only - deactivates the user completely
  /// This is different from role management which only affects specific roles
  static Future<void> removeUserFromAuthority({
    required String profileId,
    required String authorityId,
  }) async {
    try {
      debugPrint(
          '🔍 Removing user from authority: $profileId from $authorityId');

      // Deactivate the user in authority_profiles
      await _supabase
          .from('authority_profiles')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('profile_id', profileId)
          .eq('authority_id', authorityId);

      // Also deactivate all their roles in this authority
      await _supabase
          .from(AppConstants.tableProfileRoles)
          .update({
            AppConstants.fieldProfileRoleIsActive: false,
            AppConstants.fieldUpdatedAt: DateTime.now().toIso8601String(),
          })
          .eq(AppConstants.fieldProfileRoleProfileId, profileId)
          .eq('authority_id', authorityId);

      debugPrint('✅ User removed from authority (and all roles deactivated)');
    } catch (e) {
      debugPrint(
          '❌ AuthorityProfilesService.removeUserFromAuthority error: $e');
      rethrow;
    }
  }

  /// Reactivate a user in an authority (User Management function)
  /// This affects authority_profiles table only
  static Future<void> reactivateUserInAuthority({
    required String profileId,
    required String authorityId,
  }) async {
    try {
      debugPrint(
          '🔍 Reactivating user in authority: $profileId in $authorityId');

      await _supabase
          .from('authority_profiles')
          .update({
            'is_active': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('profile_id', profileId)
          .eq('authority_id', authorityId);

      debugPrint('✅ User reactivated in authority (roles remain as they were)');
    } catch (e) {
      debugPrint(
          '❌ AuthorityProfilesService.reactivateUserInAuthority error: $e');
      rethrow;
    }
  }

  /// Check if a user is active in an authority
  static Future<bool> isUserActiveInAuthority({
    required String profileId,
    required String authorityId,
  }) async {
    try {
      final response = await _supabase
          .from('authority_profiles')
          .select('is_active')
          .eq('profile_id', profileId)
          .eq('authority_id', authorityId)
          .maybeSingle();

      return response?['is_active'] == true;
    } catch (e) {
      debugPrint(
          '❌ AuthorityProfilesService.isUserActiveInAuthority error: $e');
      return false;
    }
  }

  /// Get all authorities a user belongs to
  static Future<List<Map<String, dynamic>>> getUserAuthorities(
      String profileId) async {
    try {
      final response = await _supabase
          .from('authority_profiles')
          .select('''
            id,
            is_active,
            created_at,
            authorities!inner(
              id,
              name,
              code,
              countries(name, country_code)
            )
          ''')
          .eq('profile_id', profileId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ AuthorityProfilesService.getUserAuthorities error: $e');
      rethrow;
    }
  }

  /// Get user statistics for an authority
  static Future<Map<String, dynamic>> getAuthorityUserStats(
      String authorityId) async {
    try {
      // Get total users
      final totalUsers = await _supabase
          .from('authority_profiles')
          .select('id')
          .eq('authority_id', authorityId)
          .count();

      // Get active users
      final activeUsers = await _supabase
          .from('authority_profiles')
          .select('id')
          .eq('authority_id', authorityId)
          .eq('is_active', true)
          .count();

      // Get inactive users
      final inactiveUsers = await _supabase
          .from('authority_profiles')
          .select('id')
          .eq('authority_id', authorityId)
          .eq('is_active', false)
          .count();

      return {
        'total_users': totalUsers,
        'active_users': activeUsers,
        'inactive_users': inactiveUsers,
      };
    } catch (e) {
      debugPrint('❌ AuthorityProfilesService.getAuthorityUserStats error: $e');
      return {
        'total_users': 0,
        'active_users': 0,
        'inactive_users': 0,
      };
    }
  }

  /// Update authority profile information (display name, status)
  /// profileId should be the profile_id from the authority_profiles table (UUID of the user)
  /// authorityId should be provided to ensure we update the correct record
  static Future<bool> updateAuthorityProfile({
    required String profileId,
    String? authorityId,
    String? displayName,
    bool? isActive,
    String? notes, // Keep parameter for compatibility but don't use it
  }) async {
    try {
      debugPrint('🔍 Updating authority profile: $profileId');
      debugPrint('🔍 Authority ID: $authorityId');
      debugPrint('🔍 Display name: $displayName');
      debugPrint('🔍 Is active: $isActive');

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isActive != null) {
        updateData['is_active'] = isActive;
      }

      // If display name is provided, add it to the update data
      if (displayName != null && displayName.isNotEmpty) {
        updateData['display_name'] = displayName;
      }

      // Note: notes field is not stored in authority_profiles table
      // It's kept as parameter for UI compatibility but not persisted

      // Build the query to find the specific authority_profiles record
      var query = _supabase
          .from('authority_profiles')
          .select('id')
          .eq('profile_id', profileId);

      // If authority ID is provided, use it to ensure we get the right record
      if (authorityId != null) {
        query = query.eq('authority_id', authorityId);
      }

      final existingRecord = await query.single();

      debugPrint('🔍 Found authority profile record: ${existingRecord['id']}');

      // Update authority profile using the primary key
      debugPrint('🔍 Update data: $updateData');
      await _supabase
          .from('authority_profiles')
          .update(updateData)
          .eq('id', existingRecord['id']);

      debugPrint('✅ Authority profile updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ AuthorityProfilesService.updateAuthorityProfile error: $e');
      return false;
    }
  }

  /// Permanently delete a user from an authority (HARD DELETE)
  /// Use with extreme caution - this cannot be undone
  static Future<void> permanentlyDeleteUserFromAuthority({
    required String profileId,
    required String authorityId,
  }) async {
    try {
      debugPrint(
          '🔍 PERMANENTLY deleting user from authority: $profileId from $authorityId');

      // First delete all role assignments
      await _supabase
          .from(AppConstants.tableProfileRoles)
          .delete()
          .eq(AppConstants.fieldProfileRoleProfileId, profileId)
          .eq('authority_id', authorityId);

      // Then delete the authority profile
      await _supabase
          .from('authority_profiles')
          .delete()
          .eq('profile_id', profileId)
          .eq('authority_id', authorityId);

      debugPrint('✅ User permanently deleted from authority');
    } catch (e) {
      debugPrint(
          '❌ AuthorityProfilesService.permanentlyDeleteUserFromAuthority error: $e');
      rethrow;
    }
  }
}
