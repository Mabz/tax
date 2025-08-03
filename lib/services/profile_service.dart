import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../models/profile.dart';

/// Service for managing user profiles in the EasyTax system
class ProfileService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = AppConstants.tableProfiles;

  /// Get all profiles
  static Future<List<Profile>> getAllProfiles() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .order(AppConstants.fieldProfileFullName);

      return (response as List).map((json) => Profile.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ ProfileService.getAllProfiles error: $e');
      rethrow;
    }
  }

  /// Get a profile by ID
  static Future<Profile?> getProfileById(String id) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq(AppConstants.fieldId, id)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromJson(response);
    } catch (e) {
      debugPrint('❌ ProfileService.getProfileById error: $e');
      rethrow;
    }
  }

  /// Get a profile by email using the database function
  static Future<Profile?> getProfileByEmail(String email) async {
    try {
      final result = await _supabase.rpc(
        AppConstants.getProfileByEmailFunction,
        params: {
          AppConstants.paramEmail: email,
        },
      );

      if (result == null || (result as List).isEmpty) return null;
      
      // The function returns a list, get the first item
      final profileData = result.first;
      return Profile.fromJson(profileData);
    } catch (e) {
      debugPrint('❌ ProfileService.getProfileByEmail error: $e');
      rethrow;
    }
  }

  /// Get profiles by country using the database function
  static Future<List<Map<String, dynamic>>> getProfilesByCountry(String countryId) async {
    try {
      final result = await _supabase.rpc(
        AppConstants.getProfilesByCountryFunction,
        params: {
          'target_country_id': countryId,
        },
      );

      if (result == null) return [];
      
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('❌ ProfileService.getProfilesByCountry error: $e');
      rethrow;
    }
  }

  /// Update an existing profile
  static Future<Profile> updateProfile({
    required String id,
    String? fullName,
    String? email,
  }) async {
    try {
      final updateData = <String, dynamic>{
        AppConstants.fieldUpdatedAt: DateTime.now().toIso8601String(),
      };

      if (fullName != null) {
        updateData[AppConstants.fieldProfileFullName] = fullName;
      }
      if (email != null) {
        updateData[AppConstants.fieldProfileEmail] = email;
      }

      final response = await _supabase
          .from(_tableName)
          .update(updateData)
          .eq(AppConstants.fieldId, id)
          .select()
          .single();

      return Profile.fromJson(response);
    } catch (e) {
      debugPrint('❌ ProfileService.updateProfile error: $e');
      rethrow;
    }
  }

  /// Update profile active status
  static Future<Profile> updateProfileStatus({
    required String id,
    required bool isActive,
  }) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .update({
            AppConstants.fieldProfileIsActive: isActive,
            AppConstants.fieldUpdatedAt: DateTime.now().toIso8601String(),
          })
          .eq(AppConstants.fieldId, id)
          .select()
          .single();

      return Profile.fromJson(response);
    } catch (e) {
      debugPrint('❌ ProfileService.updateProfileStatus error: $e');
      rethrow;
    }
  }

  /// Delete a profile
  static Future<void> deleteProfile(String id) async {
    try {
      await _supabase.from(_tableName).delete().eq(AppConstants.fieldId, id);
    } catch (e) {
      debugPrint('❌ ProfileService.deleteProfile error: $e');
      rethrow;
    }
  }

  /// Check if an email already exists
  static Future<bool> emailExists(String email, {String? excludeId}) async {
    try {
      var query = _supabase
          .from(_tableName)
          .select(AppConstants.fieldId)
          .eq(AppConstants.fieldProfileEmail, email);

      if (excludeId != null) {
        query = query.neq(AppConstants.fieldId, excludeId);
      }

      final response = await query.maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('❌ ProfileService.emailExists error: $e');
      return false;
    }
  }

  /// Search profiles by name or email
  static Future<List<Profile>> searchProfiles(String query) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .or('full_name.ilike.%$query%,email.ilike.%$query%')
          .order(AppConstants.fieldProfileFullName);

      return (response as List).map((json) => Profile.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ ProfileService.searchProfiles error: $e');
      rethrow;
    }
  }
}
