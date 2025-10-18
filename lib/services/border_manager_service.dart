import 'package:flutter_supabase_auth/models/border_official.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/border_manager.dart';
import '../models/border.dart' as border_model;

class BorderManagerService {
  static final _supabase = Supabase.instance.client;

  // Getter for accessing supabase client from widgets
  static SupabaseClient get supabase => _supabase;

  /// Assign a border manager to a specific border
  static Future<void> assignManagerToBorder(
    String profileId,
    String borderId,
  ) async {
    try {
      await _supabase.rpc('assign_manager_to_border', params: {
        'target_profile_id': profileId,
        'target_border_id': borderId,
      });
    } catch (e) {
      throw Exception('Failed to assign manager to border: $e');
    }
  }

  /// Revoke a border manager's access to a border
  static Future<void> revokeManagerFromBorder(
    String profileId,
    String borderId,
  ) async {
    try {
      await _supabase.rpc('revoke_manager_from_border', params: {
        'target_profile_id': profileId,
        'target_border_id': borderId,
      });
    } catch (e) {
      throw Exception('Failed to revoke manager from border: $e');
    }
  }

  /// Get all border managers for a specific authority (with assignment details)
  static Future<List<BorderManager>> getBorderManagersForAuthority(
    String authorityId,
  ) async {
    try {
      final response = await _supabase
          .rpc('get_border_managers_for_authority_enhanced', params: {
        'target_authority_id': authorityId,
      });

      return (response as List)
          .map((item) => BorderManager.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get border managers: $e');
    }
  }

  /// Get all border managers for a specific authority (BACKUP - direct query)
  static Future<List<BorderManager>> _getBorderManagersForAuthorityDirect(
    String authorityId,
  ) async {
    try {
      // Get border managers for this specific authority using profile_roles
      final response = await _supabase
          .from('profile_roles')
          .select('''
            profiles!inner(
              id,
              full_name,
              email,
              profile_image_url
            ),
            roles!inner(name)
          ''')
          .eq('authority_id', authorityId)
          .eq('roles.name', 'border_manager')
          .eq('is_active', true);

      // Convert to BorderManager objects with assignment details
      List<BorderManager> managers = [];
      for (var item in response) {
        final profile = item['profiles'];

        // Get border assignments for this manager
        final assignmentsResponse = await _supabase
            .from('border_manager_borders')
            .select('''
              borders!inner(name, authority_id)
            ''')
            .eq('profile_id', profile['id'])
            .eq('is_active', true)
            .eq('borders.authority_id', authorityId);

        final borderCount = assignmentsResponse.length;
        final assignedBorders = assignmentsResponse
            .map((assignment) => assignment['borders']['name'] as String)
            .join(', ');

        managers.add(BorderManager(
          profileId: profile['id'] ?? '',
          fullName: profile['full_name'] ?? '',
          email: profile['email'] ?? '',
          profileImageUrl: profile['profile_image_url'],
          borderCount: borderCount,
          assignedBorders: assignedBorders,
        ));
      }

      return managers;
    } catch (e) {
      throw Exception('Failed to get border managers: $e');
    }
  }

  /// Get all borders for a country (for assignment purposes)
  static Future<List<border_model.Border>> getBordersForCountry(
      String countryId) async {
    try {
      // Query borders through authorities table for authority-centric model
      final response = await _supabase
          .from('borders')
          .select('''
            id,
            authority_id,
            name,
            border_type_id,
            border_types(label),
            is_active,
            latitude,
            longitude,
            description,
            created_at,
            updated_at,
            authorities!inner(country_id)
          ''')
          .eq('authorities.country_id', countryId)
          .eq('is_active', true)
          .order('name');

      return (response as List)
          .map((item) => border_model.Border.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get borders: $e');
    }
  }

  /// Get border managers with their role assignments for a country
  static Future<List<BorderManager>> getAvailableBorderManagers(
    String countryId,
  ) async {
    try {
      // Use a simpler query to avoid embedding issues
      final response = await _supabase
          .from('profile_roles')
          .select('''
            profiles!inner(
              id,
              full_name,
              email,
              profile_image_url
            ),
            roles!inner(name),
            authorities!inner(country_id)
          ''')
          .eq('authorities.country_id', countryId)
          .eq('roles.name', 'border_manager')
          .eq('is_active', true);

      return (response as List)
          .map((item) => BorderManager(
                profileId: item['profiles']['id'] ?? '',
                fullName: item['profiles']['full_name'] ?? '',
                email: item['profiles']['email'] ?? '',
                profileImageUrl: item['profiles']['profile_image_url'],
                borderCount: 0,
                assignedBorders: '',
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to get available border managers: $e');
    }
  }

  /// Get border managers by country (simple list for assignment)
  static Future<List<BorderManager>> getBorderManagersByCountry(
    String countryId,
  ) async {
    try {
      final response = await _supabase
          .rpc('get_border_managers_by_country_enhanced', params: {
        'target_country_id': countryId,
      });

      return (response as List)
          .map((item) => BorderManager(
                profileId: item['profile_id'] ?? '',
                fullName: item['full_name'] ?? '',
                email: item['email'] ?? '',
                borderCount: 0,
                assignedBorders: '',
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to get border managers by country: $e');
    }
  }

  /// Check if a border manager can manage a specific border
  static Future<bool> canManagerManageBorder(
    String profileId,
    String borderId,
  ) async {
    try {
      final response = await _supabase
          .from('border_manager_borders')
          .select('id')
          .eq('profile_id', profileId)
          .eq('border_id', borderId)
          .eq('is_active', true)
          .maybeSingle();

      return response != null;
    } catch (e) {
      throw Exception('Failed to check border assignment: $e');
    }
  }

  /// Get borders assigned to a specific border manager
  static Future<List<border_model.Border>> getAssignedBordersForManager(
    String profileId,
  ) async {
    try {
      final response = await _supabase
          .from('border_manager_borders')
          .select('''
            borders!inner(
              id,
              name,
              border_type_id,
              authority_id,
              is_active,
              latitude,
              longitude,
              description,
              created_at,
              updated_at,
              border_types(label)
            )
          ''')
          .eq('profile_id', profileId)
          .eq('is_active', true)
          .order('borders.name');

      return (response as List)
          .map((item) => border_model.Border.fromJson(item['borders']))
          .toList();
    } catch (e) {
      throw Exception('Failed to get assigned borders for manager: $e');
    }
  }

  /// Get border assignments from the border's perspective (like Border Officials)
  static Future<List<BorderManagerAssignmentWithDetails>>
      getBorderManagerAssignmentsByAuthority(
    String authorityId,
  ) async {
    try {
      // First, get all borders for this authority (simple query)
      final bordersResponse = await _supabase
          .from('borders')
          .select('''
            id,
            name,
            description,
            border_types(label)
          ''')
          .eq('authority_id', authorityId)
          .eq('is_active', true)
          .order('name');

      List<BorderManagerAssignmentWithDetails> assignments = [];

      for (var borderData in bordersResponse) {
        final borderId = borderData['id'] as String;

        // Get manager assignments for this border separately (simpler query)
        final assignmentsResponse =
            await _supabase.from('border_manager_borders').select('''
              profile_id,
              assigned_at,
              profiles!inner(
                id,
                full_name,
                email,
                profile_image_url
              )
            ''').eq('border_id', borderId).eq('is_active', true);

        final assignedManagers = assignmentsResponse.map((assignment) {
          final profile = assignment['profiles'];
          return BorderManagerAssignment(
            profileId: profile['id'],
            fullName: profile['full_name'],
            email: profile['email'],
            profileImageUrl: profile['profile_image_url'],
            assignedAt: DateTime.parse(assignment['assigned_at']),
          );
        }).toList();

        assignments.add(BorderManagerAssignmentWithDetails(
          borderId: borderId,
          borderName: borderData['name'],
          borderDescription: borderData['description'],
          borderType: borderData['border_types']?['label'],
          assignedManagers: assignedManagers,
        ));
      }

      return assignments;
    } catch (e) {
      throw Exception('Failed to get border manager assignments: $e');
    }
  }

  /// Get borders assigned to the current border manager
  static Future<List<border_model.Border>>
      getAssignedBordersForCurrentManager() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('🔍 Debug: Current user ID: ${user.id}');
      print('🔍 Debug: Current user email: ${user.email}');

      // First, check if user has border_manager role
      final roleCheck = await _supabase
          .from('profile_roles')
          .select('''
            roles!inner(name),
            authorities!inner(name, country_id)
          ''')
          .eq('profile_id', user.id)
          .eq('roles.name', 'border_manager')
          .eq('is_active', true);

      print('🔍 Debug: Border manager roles found: ${roleCheck.length}');
      for (var role in roleCheck) {
        print('   - Authority: ${role['authorities']['name']}');
      }

      final response = await _supabase.from('border_manager_borders').select('''
            borders!inner(
              id,
              name,
              description,
              authority_id
            )
          ''').eq('profile_id', user.id).eq('is_active', true);

      print('🔍 Debug: Border assignments found: ${response.length}');

      return (response as List).map((item) {
        final borderData = item['borders'] as Map<String, dynamic>;
        print('   - Border: ${borderData['name']} (${borderData['id']})');
        return border_model.Border(
          id: borderData['id'] as String,
          name: borderData['name'] as String,
          description: borderData['description'] as String?,
          authorityId: borderData['authority_id'] as String,
          borderTypeId:
              '', // Default empty string since we're not fetching border type
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('🔍 Debug: Error in getAssignedBordersForCurrentManager: $e');
      throw Exception('Failed to get assigned borders: $e');
    }
  }

  /// Get border officials assigned to a specific border (for border managers)
  static Future<List<BorderOfficialWithPermissions>>
      getBorderOfficialsForBorder(String borderId) async {
    try {
      // Get border official assignments without embedding
      final assignmentsResponse = await _supabase
          .from('border_official_borders')
          .select('profile_id, can_check_in, can_check_out, assigned_at')
          .eq('border_id', borderId)
          .eq('is_active', true);

      List<BorderOfficialWithPermissions> officials = [];

      // Get profile details for each assigned official separately
      for (var assignment in assignmentsResponse) {
        try {
          final profileResponse = await _supabase
              .from('profiles')
              .select('id, full_name, email, profile_image_url')
              .eq('id', assignment['profile_id'])
              .single();

          officials.add(BorderOfficialWithPermissions(
            profileId: profileResponse['id'],
            fullName: profileResponse['full_name'],
            email: profileResponse['email'],
            profileImageUrl: profileResponse['profile_image_url'],
            canCheckIn: assignment['can_check_in'] ?? true,
            canCheckOut: assignment['can_check_out'] ?? true,
            assignedAt: DateTime.parse(assignment['assigned_at']),
          ));
        } catch (e) {
          // Skip if profile not found
          print(
              'Profile not found for assignment: ${assignment['profile_id']}');
        }
      }

      return officials;
    } catch (e) {
      throw Exception('Failed to get border officials for border: $e');
    }
  }

  /// Get available border officials that can be assigned to a specific border
  static Future<List<BorderOfficial>> getAvailableBorderOfficialsForBorder(
      String borderId) async {
    try {
      print(
          '🔍 Debug: Getting available border officials for border: $borderId');

      // First get the border's authority
      final borderResponse = await _supabase
          .from('borders')
          .select('authority_id')
          .eq('id', borderId)
          .single();

      final authorityId = borderResponse['authority_id'] as String;
      print('🔍 Debug: Border authority ID: $authorityId');

      // Get all border officials for this authority
      final allOfficials =
          await getAvailableBorderOfficialsForAuthority(authorityId);
      print(
          '🔍 Debug: Total border officials in authority: ${allOfficials.length}');

      // Get currently assigned officials for this border
      final assignedResponse = await _supabase
          .from('border_official_borders')
          .select('profile_id')
          .eq('border_id', borderId)
          .eq('is_active', true);

      final assignedProfileIds = (assignedResponse as List)
          .map((item) => item['profile_id'] as String)
          .toSet();

      print('🔍 Debug: Already assigned officials: $assignedProfileIds');

      // Filter out already assigned officials
      final availableOfficials = allOfficials
          .where((official) => !assignedProfileIds.contains(official.profileId))
          .toList();

      print(
          '🔍 Debug: Available officials for assignment: ${availableOfficials.length}');

      return availableOfficials;
    } catch (e) {
      print(
          '🔍 Debug: Error getting available border officials for border: $e');
      throw Exception(
          'Failed to get available border officials for border: $e');
    }
  }

  /// Get available border officials that can be assigned to borders
  static Future<List<BorderOfficial>> getAvailableBorderOfficialsForAuthority(
      String authorityId) async {
    try {
      print('🔍 Debug: Getting border officials for authority: $authorityId');

      // Get the border_official role ID first
      final borderOfficialRole = await _supabase
          .from('roles')
          .select('id')
          .eq('name', 'border_official')
          .single();

      final borderOfficialRoleId = borderOfficialRole['id'] as String;
      print('🔍 Debug: Border official role ID: $borderOfficialRoleId');

      // Get profile IDs that have border_official role for this authority
      final profileRolesResponse = await _supabase
          .from('profile_roles')
          .select('profile_id')
          .eq('authority_id', authorityId)
          .eq('role_id', borderOfficialRoleId)
          .eq('is_active', true);

      print(
          '🔍 Debug: Border official assignments found: ${profileRolesResponse.length}');

      if (profileRolesResponse.isEmpty) {
        print('🔍 Debug: No border officials found for this authority');
        return [];
      }

      final profileIds = (profileRolesResponse as List)
          .map((item) => item['profile_id'] as String)
          .toSet() // Remove duplicates
          .toList();

      print('🔍 Debug: Unique border official profile IDs: $profileIds');

      // Get profile details for these users
      final profilesResponse = await _supabase
          .from('profiles')
          .select('id, full_name, email, profile_image_url')
          .inFilter('id', profileIds);

      print('🔍 Debug: Profiles found: ${profilesResponse.length}');

      return (profilesResponse as List).map((profile) {
        return BorderOfficial(
          profileId: profile['id'],
          fullName: profile['full_name'] ?? 'Unknown',
          email: profile['email'] ?? 'No email',
          profileImageUrl: profile['profile_image_url'],
          borderCount: 0,
          assignedBorders: '',
        );
      }).toList();
    } catch (e) {
      print('🔍 Debug: Error getting border officials: $e');
      throw Exception('Failed to get available border officials: $e');
    }
  }

  /// Assign a border official to a border (for border managers)
  static Future<void> assignOfficialToBorderAsManager(
      String profileId, String borderId,
      {bool canCheckIn = true, bool canCheckOut = true}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      print('🔍 Debug: Assigning official $profileId to border $borderId');
      print('🔍 Debug: Current user: ${user.id}');
      print(
          '🔍 Debug: Permissions - Check In: $canCheckIn, Check Out: $canCheckOut');

      // Check if current user is assigned to this border as a manager
      final managerCheck = await _supabase
          .from('border_manager_borders')
          .select('id')
          .eq('profile_id', user.id)
          .eq('border_id', borderId)
          .eq('is_active', true)
          .maybeSingle();

      print('🔍 Debug: Manager check result: $managerCheck');

      if (managerCheck == null) {
        throw Exception('You are not authorized to manage this border');
      }

      // Check if official is already assigned
      final existingAssignment = await _supabase
          .from('border_official_borders')
          .select('id, can_check_in, can_check_out')
          .eq('profile_id', profileId)
          .eq('border_id', borderId)
          .eq('is_active', true)
          .maybeSingle();

      print('🔍 Debug: Existing assignment: $existingAssignment');

      if (existingAssignment != null) {
        // Update existing assignment
        print('🔍 Debug: Updating existing assignment');
        await _supabase
            .from('border_official_borders')
            .update({
              'can_check_in': canCheckIn,
              'can_check_out': canCheckOut,
            })
            .eq('profile_id', profileId)
            .eq('border_id', borderId);
      } else {
        // Try direct insert first (simpler approach)
        print('🔍 Debug: Creating new assignment via direct insert');
        try {
          await _supabase.from('border_official_borders').insert({
            'profile_id': profileId,
            'border_id': borderId,
            'can_check_in': canCheckIn,
            'can_check_out': canCheckOut,
            'is_active': true,
            'assigned_at': DateTime.now().toIso8601String(),
          });
          print('🔍 Debug: Direct insert successful');
        } catch (insertError) {
          print('🔍 Debug: Direct insert failed: $insertError');
          print('🔍 Debug: Trying RPC function');

          // Fallback to RPC function
          await _supabase.rpc('assign_official_to_border', params: {
            'target_profile_id': profileId,
            'target_border_id': borderId,
          });

          // Update permissions after RPC
          await _supabase
              .from('border_official_borders')
              .update({
                'can_check_in': canCheckIn,
                'can_check_out': canCheckOut,
              })
              .eq('profile_id', profileId)
              .eq('border_id', borderId);
        }
      }

      print('🔍 Debug: Assignment completed successfully');
    } catch (e) {
      print('🔍 Debug: Assignment failed: $e');
      throw Exception('Failed to assign official to border: $e');
    }
  }

  /// Revoke a border official from a border (for border managers)
  static Future<void> revokeOfficialFromBorderAsManager(
    String profileId,
    String borderId,
  ) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if current user is assigned to this border as a manager
      final managerCheck = await _supabase
          .from('border_manager_borders')
          .select('id')
          .eq('profile_id', user.id)
          .eq('border_id', borderId)
          .eq('is_active', true)
          .maybeSingle();

      if (managerCheck == null) {
        throw Exception('You are not authorized to manage this border');
      }

      // Revoke the official from the border
      await _supabase.rpc('revoke_official_from_border', params: {
        'target_profile_id': profileId,
        'target_border_id': borderId,
      });
    } catch (e) {
      throw Exception('Failed to revoke official from border: $e');
    }
  }

  /// Check if current user can manage all borders of their authority
  static Future<bool> canManageAllAuthorityBorders(String authorityId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Check if user has country_admin or superuser role for this authority
      final response = await _supabase
          .from('profile_roles')
          .select('''
            roles!inner(name)
          ''')
          .eq('profile_id', user.id)
          .eq('authority_id', authorityId)
          .eq('is_active', true)
          .inFilter('roles.name', ['country_admin', 'superuser']);

      return response.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check authority permissions: $e');
    }
  }
}

/// Model for border manager assignment from border's perspective
class BorderManagerAssignmentWithDetails {
  final String borderId;
  final String borderName;
  final String? borderDescription;
  final String? borderType;
  final List<BorderManagerAssignment> assignedManagers;

  BorderManagerAssignmentWithDetails({
    required this.borderId,
    required this.borderName,
    this.borderDescription,
    this.borderType,
    required this.assignedManagers,
  });
}

/// Model for individual manager assignment
class BorderManagerAssignment {
  final String profileId;
  final String fullName;
  final String email;
  final String? profileImageUrl;
  final DateTime assignedAt;

  BorderManagerAssignment({
    required this.profileId,
    required this.fullName,
    required this.email,
    this.profileImageUrl,
    required this.assignedAt,
  });
}

/// Model for border assignment in the assignment widget
class BorderAssignmentForManager {
  final String borderId;
  final String borderName;
  final bool isAssigned;

  BorderAssignmentForManager({
    required this.borderId,
    required this.borderName,
    required this.isAssigned,
  });

  BorderAssignmentForManager copyWith({
    String? borderId,
    String? borderName,
    bool? isAssigned,
  }) {
    return BorderAssignmentForManager(
      borderId: borderId ?? this.borderId,
      borderName: borderName ?? this.borderName,
      isAssigned: isAssigned ?? this.isAssigned,
    );
  }
}

/// Model for border official with permissions
class BorderOfficialWithPermissions {
  final String profileId;
  final String fullName;
  final String email;
  final String? profileImageUrl;
  final bool canCheckIn;
  final bool canCheckOut;
  final DateTime assignedAt;

  BorderOfficialWithPermissions({
    required this.profileId,
    required this.fullName,
    required this.email,
    this.profileImageUrl,
    required this.canCheckIn,
    required this.canCheckOut,
    required this.assignedAt,
  });
}
