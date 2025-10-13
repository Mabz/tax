import 'package:supabase_flutter/supabase_flutter.dart';
import 'role_service.dart';

class AuthorityProfile {
  final String id;
  final String profileId;
  final String displayName;
  final bool isActive;
  final String? notes;
  final DateTime assignedAt;
  final String? assignedByName;
  final String profileEmail;
  final String? profileFullName;
  final String? profileImageUrl;
  final List<String> roleNames;
  final DateTime createdAt;
  final DateTime updatedAt;

  AuthorityProfile({
    required this.id,
    required this.profileId,
    required this.displayName,
    required this.isActive,
    this.notes,
    required this.assignedAt,
    this.assignedByName,
    required this.profileEmail,
    this.profileFullName,
    this.profileImageUrl,
    required this.roleNames,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AuthorityProfile.fromJson(Map<String, dynamic> json) {
    return AuthorityProfile(
      id: json['id'],
      profileId: json['profile_id'],
      displayName: json['display_name'],
      isActive: json['is_active'],
      notes: json['notes'],
      assignedAt: DateTime.parse(json['assigned_at']),
      assignedByName: json['assigned_by_name'],
      profileEmail: json['profile_email'],
      profileFullName: json['profile_full_name'],
      profileImageUrl: json['profile_image_url'],
      roleNames: List<String>.from(json['role_names'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class AuthorityProfilesService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all authority profiles for a specific authority
  Future<List<AuthorityProfile>> getAuthorityProfiles(
      String authorityId) async {
    try {
      // First check if user can manage this authority
      final canManage = await _canManageAuthority(authorityId);
      if (!canManage) {
        throw Exception(
            'User is not a country administrator for this authority');
      }

      // Call the database function to get authority profiles
      final response = await _supabase.rpc(
        'get_authority_profiles_for_admin',
        params: {'admin_authority_id': authorityId},
      );

      print(
          '🔍 AuthorityProfiles: Database function returned: ${response?.length ?? 0} records');

      if (response != null && response.isNotEmpty) {
        print('🔍 AuthorityProfiles: Sample record: ${response[0]}');
        print(
            '🔍 AuthorityProfiles: Profile image URL in first record: ${response[0]['profile_image_url']}');
      }

      if (response == null) return [];

      final profiles = (response as List)
          .map((json) => AuthorityProfile.fromJson(json))
          .toList();

      print(
          '✅ AuthorityProfiles: Successfully parsed ${profiles.length} authority profiles');
      if (profiles.isNotEmpty) {
        print(
            '🔍 AuthorityProfiles: First profile image URL: ${profiles[0].profileImageUrl}');
      }

      return profiles;
    } catch (e) {
      throw Exception('Failed to fetch authority profiles: $e');
    }
  }

  /// Update an authority profile
  Future<bool> updateAuthorityProfile({
    required String profileId,
    required String displayName,
    required bool isActive,
    String? notes,
  }) async {
    try {
      print('🔍 AuthorityProfiles: Updating profile $profileId');
      print('🔍 AuthorityProfiles: Display name: $displayName');
      print('🔍 AuthorityProfiles: Is active: $isActive');
      print('🔍 AuthorityProfiles: Notes: $notes');

      final response = await _supabase.rpc(
        'update_authority_profile',
        params: {
          'profile_record_id': profileId,
          'new_display_name': displayName,
          'new_is_active': isActive,
          'new_notes': notes,
        },
      );

      print('🔍 AuthorityProfiles: Update response: $response');

      final success = response == true;
      print(success
          ? '✅ AuthorityProfiles: Update successful'
          : '❌ AuthorityProfiles: Update failed - response was not true');

      return success;
    } catch (e) {
      print('❌ AuthorityProfiles: Update error: $e');
      throw Exception('Failed to update authority profile: $e');
    }
  }

  /// Check if current user can manage a specific authority
  Future<bool> _canManageAuthority(String authorityId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      print(
          '🔍 AuthorityProfiles: Checking permissions for user $userId, authority $authorityId');

      if (userId == null) {
        print('❌ AuthorityProfiles: No user ID found');
        return false;
      }

      // Check if user is superuser
      final isSuperuser = await RoleService.isSuperuser();
      print('🔍 AuthorityProfiles: Is superuser: $isSuperuser');
      if (isSuperuser) {
        print('✅ AuthorityProfiles: Access granted - superuser');
        return true;
      }

      // Check if user has admin role (like other management screens do)
      final hasAdminRole = await RoleService.hasAdminRole();
      print('🔍 AuthorityProfiles: Has admin role: $hasAdminRole');
      if (hasAdminRole) {
        print('✅ AuthorityProfiles: Access granted - country administrator');
        return true;
      }

      print('❌ AuthorityProfiles: Access denied - no admin privileges');
      return false;
    } catch (e) {
      print('❌ AuthorityProfiles: Permission check error: $e');
      return false;
    }
  }

  /// Check if current user is a country administrator for any authority
  Future<bool> isCountryAdministrator() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('profile_roles')
          .select('authority_id, roles!inner(name)')
          .eq('profile_id', userId)
          .eq('is_active', true)
          .eq('roles.name', 'country_administrator')
          .limit(1)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Get authority profiles with real-time updates for a specific authority
  Stream<List<AuthorityProfile>> getAuthorityProfilesStream(
      String authorityId) {
    return Stream.periodic(const Duration(seconds: 30))
        .asyncMap((_) => getAuthorityProfiles(authorityId))
        .handleError((error) {
      // Handle errors gracefully
      return <AuthorityProfile>[];
    });
  }
}
