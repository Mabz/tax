import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../models/border.dart';

/// Service for managing border operations
class BorderService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all borders for a specific authority
  static Future<List<Border>> getBordersByAuthority(String authorityId) async {
    try {
      debugPrint('🔍 Fetching borders for authority: $authorityId');

      final response = await _supabase
          .from(AppConstants.tableBorders)
          .select()
          .eq(AppConstants.fieldBorderAuthorityId, authorityId)
          .order(AppConstants.fieldBorderName);

      debugPrint('✅ Retrieved ${response.length} borders');

      return response.map<Border>((json) => Border.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching borders for authority $authorityId: $e');
      rethrow;
    }
  }

  /// Get all borders (for superuser access)
  static Future<List<Border>> getAllBorders() async {
    try {
      debugPrint('🔍 Fetching all borders');

      final response = await _supabase
          .from(AppConstants.tableBorders)
          .select()
          .order(AppConstants.fieldBorderName);

      debugPrint('✅ Retrieved ${response.length} borders');

      return response.map<Border>((json) => Border.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching all borders: $e');
      rethrow;
    }
  }

  /// Get border by ID
  static Future<Border?> getBorderById(String id) async {
    try {
      debugPrint('🔍 Fetching border by ID: $id');

      final response = await _supabase
          .from(AppConstants.tableBorders)
          .select()
          .eq(AppConstants.fieldId, id)
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ Border not found with ID: $id');
        return null;
      }

      debugPrint(
          '✅ Retrieved border: ${response[AppConstants.fieldBorderName]}');
      return Border.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching border by ID $id: $e');
      rethrow;
    }
  }

  /// Create a new border
  static Future<Border> createBorder({
    required String authorityId,
    required String name,
    required String borderTypeId,
    bool isActive = true,
    double? latitude,
    double? longitude,
    String? description,
  }) async {
    try {
      debugPrint('🔄 Creating border: $name');

      // Validate border name doesn't exist for this authority
      final existingBorder = await borderExistsInAuthority(name, authorityId);
      if (existingBorder) {
        throw Exception(
            'A border with name "$name" already exists in this authority');
      }

      // Get the country_id from the authority
      final authorityResponse = await _supabase
          .from(AppConstants.tableAuthorities)
          .select(AppConstants.fieldAuthorityCountryId)
          .eq(AppConstants.fieldId, authorityId)
          .single();

      final countryId =
          authorityResponse[AppConstants.fieldAuthorityCountryId] as String;
      debugPrint('🔍 Found country_id: $countryId for authority: $authorityId');

      final borderData = {
        AppConstants.fieldBorderCountryId: countryId,
        AppConstants.fieldBorderAuthorityId: authorityId,
        AppConstants.fieldBorderName: name,
        AppConstants.fieldBorderTypeId: borderTypeId,
        AppConstants.fieldBorderIsActive: isActive,
        AppConstants.fieldBorderLatitude: latitude,
        AppConstants.fieldBorderLongitude: longitude,
        AppConstants.fieldBorderDescription: description,
      };

      final response = await _supabase
          .from(AppConstants.tableBorders)
          .insert(borderData)
          .select()
          .single();

      debugPrint('✅ Created border: $name');
      return Border.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error creating border $name: $e');
      rethrow;
    }
  }

  /// Update an existing border
  static Future<Border> updateBorder({
    required String id,
    required String name,
    required String borderTypeId,
    bool? isActive,
    double? latitude,
    double? longitude,
    String? description,
  }) async {
    try {
      debugPrint('🔄 Updating border: $id');

      final borderData = {
        AppConstants.fieldBorderName: name,
        AppConstants.fieldBorderTypeId: borderTypeId,
        AppConstants.fieldBorderIsActive: isActive,
        AppConstants.fieldBorderLatitude: latitude,
        AppConstants.fieldBorderLongitude: longitude,
        AppConstants.fieldBorderDescription: description,
        AppConstants.fieldUpdatedAt: DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from(AppConstants.tableBorders)
          .update(borderData)
          .eq(AppConstants.fieldId, id)
          .select()
          .single();

      debugPrint('✅ Updated border: $name');
      return Border.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error updating border $id: $e');
      rethrow;
    }
  }

  /// Delete a border
  static Future<void> deleteBorder(String id) async {
    try {
      debugPrint('🔄 Deleting border: $id');

      await _supabase
          .from(AppConstants.tableBorders)
          .delete()
          .eq(AppConstants.fieldId, id);

      debugPrint('✅ Deleted border: $id');
    } catch (e) {
      debugPrint('❌ Error deleting border $id: $e');
      rethrow;
    }
  }

  /// Check if a border name exists in a specific authority
  static Future<bool> borderExistsInAuthority(
      String name, String authorityId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableBorders)
          .select(AppConstants.fieldId)
          .eq(AppConstants.fieldBorderName, name)
          .eq(AppConstants.fieldBorderAuthorityId, authorityId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ Error checking if border exists: $e');
      return false;
    }
  }

  /// Toggle border active status
  static Future<Border> toggleBorderStatus(String id, bool isActive) async {
    try {
      debugPrint('🔄 Toggling border status: $id to $isActive');

      final response = await _supabase
          .from(AppConstants.tableBorders)
          .update({
            AppConstants.fieldBorderIsActive: isActive,
            AppConstants.fieldUpdatedAt: DateTime.now().toIso8601String(),
          })
          .eq(AppConstants.fieldId, id)
          .select()
          .single();

      debugPrint('✅ Toggled border status: $id');
      return Border.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error toggling border status $id: $e');
      rethrow;
    }
  }

  /// Validate border name format
  static bool isValidBorderName(String name) {
    if (name.trim().isEmpty) return false;
    if (name.length < 2 || name.length > 100) return false;
    return true;
  }

  /// Get all borders for a specific country (temporary bridge method)
  /// This method finds the authority for the country and calls getBordersByAuthority
  static Future<List<Border>> getBordersByCountry(String countryId) async {
    try {
      debugPrint(
          '🔍 Fetching borders for country: $countryId (via authority lookup)');

      final authorityId = await getAuthorityIdForCountry(countryId);
      if (authorityId == null) {
        debugPrint('⚠️ No active authority found for country: $countryId');
        return [];
      }

      debugPrint('✅ Found authority: $authorityId for country: $countryId');

      // Now get borders for this authority
      return await getBordersByAuthority(authorityId);
    } catch (e) {
      debugPrint('❌ Error fetching borders for country $countryId: $e');
      rethrow;
    }
  }

  /// Get authority ID for a specific country (bridge method for authority migration)
  /// This method finds the active authority for a given country
  static Future<String?> getAuthorityIdForCountry(String countryId) async {
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
}
