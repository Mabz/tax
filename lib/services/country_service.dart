import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../models/country.dart';

/// Service for managing countries in the EasyTax system
class CountryService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = AppConstants.tableCountries;

  /// Get all countries
  static Future<List<Country>> getAllCountries() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .order(AppConstants.fieldCountryName);

      return (response as List).map((json) => Country.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ CountryService.getAllCountries error: $e');
      rethrow;
    }
  }

  /// Get only active countries
  static Future<List<Country>> getActiveCountries() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq(AppConstants.fieldCountryIsActive, true)
          .order(AppConstants.fieldCountryName);

      return (response as List).map((json) => Country.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ CountryService.getActiveCountries error: $e');
      rethrow;
    }
  }

  /// Get a country by ID
  static Future<Country?> getCountryById(String id) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq(AppConstants.fieldId, id)
          .maybeSingle();

      if (response == null) return null;
      return Country.fromJson(response);
    } catch (e) {
      debugPrint('❌ CountryService.getCountryById error: $e');
      rethrow;
    }
  }

  /// Get a country by country code
  static Future<Country?> getCountryByCode(String countryCode) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq(AppConstants.fieldCountryCode, countryCode)
          .maybeSingle();

      if (response == null) return null;
      return Country.fromJson(response);
    } catch (e) {
      debugPrint('❌ CountryService.getCountryByCode error: $e');
      rethrow;
    }
  }

  /// Create a new country
  static Future<Country> createCountry({
    required String name,
    required String countryCode,
    required String revenueServiceName,
    bool isActive = false,
    bool isGlobal = false,
  }) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .insert({
            AppConstants.fieldCountryName: name,
            AppConstants.fieldCountryCode: countryCode,
            AppConstants.fieldCountryRevenueServiceName: revenueServiceName,
            AppConstants.fieldCountryIsActive: isActive,
            AppConstants.fieldCountryIsGlobal: isGlobal,
          })
          .select()
          .single();

      return Country.fromJson(response);
    } catch (e) {
      debugPrint('❌ CountryService.createCountry error: $e');
      rethrow;
    }
  }

  /// Update an existing country
  static Future<Country> updateCountry({
    required String id,
    String? name,
    String? countryCode,
    String? revenueServiceName,
    bool? isActive,
    bool? isGlobal,
  }) async {
    try {
      final updateData = <String, dynamic>{
        AppConstants.fieldUpdatedAt: DateTime.now().toIso8601String(),
      };

      if (name != null) updateData[AppConstants.fieldCountryName] = name;
      if (countryCode != null) {
        updateData[AppConstants.fieldCountryCode] = countryCode;
      }
      if (revenueServiceName != null) {
        updateData[AppConstants.fieldCountryRevenueServiceName] =
            revenueServiceName;
      }
      if (isActive != null) {
        updateData[AppConstants.fieldCountryIsActive] = isActive;
      }
      if (isGlobal != null) {
        updateData[AppConstants.fieldCountryIsGlobal] = isGlobal;
      }

      final response = await _supabase
          .from(_tableName)
          .update(updateData)
          .eq(AppConstants.fieldId, id)
          .select()
          .single();

      return Country.fromJson(response);
    } catch (e) {
      debugPrint('❌ CountryService.updateCountry error: $e');
      rethrow;
    }
  }

  /// Delete a country
  static Future<void> deleteCountry(String id) async {
    try {
      await _supabase.from(_tableName).delete().eq(AppConstants.fieldId, id);
    } catch (e) {
      debugPrint('❌ CountryService.deleteCountry error: $e');
      rethrow;
    }
  }

  /// Check if a country code already exists
  static Future<bool> countryCodeExists(String countryCode,
      {String? excludeId}) async {
    try {
      var query = _supabase
          .from(_tableName)
          .select(AppConstants.fieldId)
          .eq(AppConstants.fieldCountryCode, countryCode);

      if (excludeId != null) {
        query = query.neq(AppConstants.fieldId, excludeId);
      }

      final response = await query.maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('❌ CountryService.countryCodeExists error: $e');
      return false;
    }
  }

  /// Toggle country active status
  static Future<Country> toggleCountryStatus(String id) async {
    try {
      // First get the current country to know its current status
      final currentCountry = await getCountryById(id);
      if (currentCountry == null) {
        throw Exception('Country not found');
      }

      // Toggle the status
      return await updateCountry(
        id: id,
        isActive: !currentCountry.isActive,
      );
    } catch (e) {
      debugPrint('❌ CountryService.toggleCountryStatus error: $e');
      rethrow;
    }
  }

  /// Get active countries excluding Global country (for superusers)
  static Future<List<Country>> getActiveCountriesExcludingGlobal() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq(AppConstants.fieldCountryIsActive, true)
          .neq(AppConstants.fieldCountryCode, AppConstants.countryGlobal)
          .order(AppConstants.fieldCountryName);

      return (response as List).map((json) => Country.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ CountryService.getActiveCountriesExcludingGlobal error: $e');
      rethrow;
    }
  }

  /// Validate country code format (ISO 3166-1 alpha-3)
  static bool isValidCountryCode(String countryCode) {
    return RegExp(r'^[A-Z]{3}$').hasMatch(countryCode);
  }
}
