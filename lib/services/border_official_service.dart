import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/border_assignment.dart';
import '../models/border_official.dart';
import '../models/border.dart' as border_model;

class BorderOfficialService {
  static final _supabase = Supabase.instance.client;

  /// Assign a border official to a specific border
  static Future<void> assignOfficialToBorder(
    String profileId,
    String borderId,
  ) async {
    try {
      await _supabase.rpc('assign_official_to_border', params: {
        'target_profile_id': profileId,
        'target_border_id': borderId,
      });
    } catch (e) {
      throw Exception('Failed to assign official to border: $e');
    }
  }

  /// Revoke a border official's access to a border
  static Future<void> revokeOfficialFromBorder(
    String profileId,
    String borderId,
  ) async {
    try {
      await _supabase.rpc('revoke_official_from_border', params: {
        'target_profile_id': profileId,
        'target_border_id': borderId,
      });
    } catch (e) {
      throw Exception('Failed to revoke official from border: $e');
    }
  }

  /// Get assigned borders for a country or current user
  static Future<List<BorderAssignment>> getAssignedBorders({
    String? countryId,
  }) async {
    try {
      final response = await _supabase.rpc('get_assigned_borders', params: {
        'target_country_id': countryId,
      });

      return (response as List)
          .map((item) => BorderAssignment.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get assigned borders: $e');
    }
  }

  /// Get all border officials for a specific country (with assignment details)
  static Future<List<BorderOfficial>> getBorderOfficialsForCountry(
    String countryId,
  ) async {
    try {
      final response =
          await _supabase.rpc('get_border_officials_for_country', params: {
        'target_country_id': countryId,
      });

      return (response as List)
          .map((item) => BorderOfficial.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get border officials: $e');
    }
  }

  /// Get unassigned borders for a country
  static Future<List<border_model.Border>> getUnassignedBordersForCountry(
    String countryId,
  ) async {
    try {
      final response =
          await _supabase.rpc('get_unassigned_borders_for_country', params: {
        'target_country_id': countryId,
      });

      return (response as List)
          .map((item) => border_model.Border.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get unassigned borders: $e');
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

  /// Get border officials with their role assignments for a country
  static Future<List<BorderOfficial>> getAvailableBorderOfficials(
    String countryId,
  ) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('''
            id,
            full_name,
            email,
            profile_roles!inner(
              is_active,
              expires_at,
              roles!inner(name),
              authorities!inner(country_id)
            )
          ''')
          .eq('profile_roles.authorities.country_id', countryId)
          .eq('profile_roles.roles.name', 'border_official')
          .eq('profile_roles.is_active', true)
          .order('full_name');

      return (response as List)
          .map((item) => BorderOfficial.fromProfileData(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get available border officials: $e');
    }
  }

  /// Get border officials by country (simple list for assignment)
  static Future<List<BorderOfficial>> getBorderOfficialsByCountry(
    String countryId,
  ) async {
    try {
      final response =
          await _supabase.rpc('get_border_officials_by_country', params: {
        'target_country_id': countryId,
      });

      return (response as List)
          .map((item) => BorderOfficial(
                profileId: item['profile_id'] ?? '',
                fullName: item['full_name'] ?? '',
                email: item['email'] ?? '',
                borderCount: 0,
                assignedBorders: '',
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to get border officials by country: $e');
    }
  }

  /// Check if a border official can process passes for a specific border
  static Future<bool> canOfficialProcessBorder(
    String profileId,
    String borderId,
  ) async {
    try {
      final response = await _supabase
          .from('border_official_borders')
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

  /// Get borders assigned to a specific border official
  static Future<List<border_model.Border>> getAssignedBordersForOfficial(
    String profileId,
  ) async {
    try {
      final response = await _supabase
          .from('border_official_borders')
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
      throw Exception('Failed to get assigned borders for official: $e');
    }
  }

  /// Check if current user can process passes for all borders of their authority
  static Future<bool> canProcessAllAuthorityBorders(String authorityId) async {
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
