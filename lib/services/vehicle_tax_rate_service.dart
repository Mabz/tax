import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle_tax_rate.dart';
import '../models/vehicle_type.dart';
import '../models/border.dart' as border_model;
import '../models/currency.dart';

class VehicleTaxRateService {
  static final _supabase = Supabase.instance.client;

  /// Get all vehicle tax rates for an authority
  static Future<List<VehicleTaxRate>> getTaxRatesForAuthority(
    String authorityId,
  ) async {
    try {
      final response =
          await _supabase.rpc('get_vehicle_tax_rates_for_authority', params: {
        'target_authority_id': authorityId,
      });

      return (response as List)
          .map((item) => VehicleTaxRate.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get tax rates: $e');
    }
  }

  /// Create a new vehicle tax rate
  static Future<void> createTaxRateForAuthority({
    required String authorityId,
    required String vehicleTypeId,
    required double taxAmount,
    required String currency,
    String? borderId,
  }) async {
    try {
      await _supabase.rpc('create_vehicle_tax_rate', params: {
        'target_authority_id': authorityId,
        'target_vehicle_type_id': vehicleTypeId,
        'tax_amount': taxAmount,
        'currency': currency,
        'target_border_id': borderId,
      });
    } catch (e) {
      throw Exception('Failed to create tax rate: $e');
    }
  }

  /// Update an existing vehicle tax rate
  static Future<void> updateTaxRateForAuthority({
    required String authorityId,
    required String vehicleTypeId,
    required double taxAmount,
    required String currency,
    String? borderId,
  }) async {
    try {
      await _supabase.rpc('update_vehicle_tax_rate', params: {
        'target_authority_id': authorityId,
        'target_vehicle_type_id': vehicleTypeId,
        'new_tax_amount': taxAmount,
        'new_currency': currency,
        'target_border_id': borderId,
      });
    } catch (e) {
      throw Exception('Failed to update tax rate: $e');
    }
  }

  /// Delete a vehicle tax rate
  static Future<void> deleteTaxRateForAuthority({
    required String authorityId,
    required String vehicleTypeId,
    String? borderId,
  }) async {
    try {
      await _supabase.rpc('delete_vehicle_tax_rate', params: {
        'target_authority_id': authorityId,
        'target_vehicle_type_id': vehicleTypeId,
        'target_border_id': borderId,
      });
    } catch (e) {
      throw Exception('Failed to delete tax rate: $e');
    }
  }

  /// Get all vehicle types
  static Future<List<VehicleType>> getVehicleTypes() async {
    try {
      final response = await _supabase.rpc('get_vehicle_types');

      return (response as List)
          .map((item) => VehicleType.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get vehicle types: $e');
    }
  }

  /// Delete a vehicle type (soft delete)
  static Future<void> deleteVehicleType(String vehicleTypeId) async {
    try {
      await _supabase.rpc('delete_vehicle_tax_type', params: {
        'target_vehicle_type_id': vehicleTypeId,
      });
    } catch (e) {
      throw Exception('Failed to delete vehicle type: $e');
    }
  }

  /// Get all active currencies
  static Future<List<Currency>> getActiveCurrencies() async {
    try {
      final response = await _supabase.rpc('get_active_currencies');

      return (response as List).map((item) => Currency.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to get currencies: $e');
    }
  }

  /// Get borders for an authority (for border-specific tax rates)
  static Future<List<border_model.Border>> getBordersForAuthority(
    String authorityId,
  ) async {
    try {
      final response =
          await _supabase.rpc('get_borders_for_authority', params: {
        'target_authority_id': authorityId,
      });

      return (response as List).map((item) {
        // Map the function result to match Border model expectations
        final mappedItem = {
          'border_id': item['border_id'],
          'authority_id':
              authorityId, // Add the authority_id since it's not returned by the function
          'border_name': item['border_name'],
          'border_type_id':
              '', // Function doesn't return this, but Border model needs it
          'border_type_label': item['border_type'],
          'is_active': true, // Function only returns active borders
          'latitude': item['latitude'],
          'longitude': item['longitude'],
          'description': item['description'],
          'created_at':
              DateTime.now().toIso8601String(), // Default since not returned
          'updated_at':
              DateTime.now().toIso8601String(), // Default since not returned
        };
        return border_model.Border.fromJson(mappedItem);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get borders: $e');
    }
  }

  // BRIDGE METHODS FOR BACKWARD COMPATIBILITY
  // These methods support the country-centric UI while using authority-centric database functions

  /// Get all vehicle tax rates for a country (bridge method)
  /// Finds the authority for the country and calls getTaxRatesForAuthority
  static Future<List<VehicleTaxRate>> getTaxRatesForCountry(
    String countryId,
  ) async {
    try {
      // Find authority for country
      final authorityResponse = await _supabase
          .from('authorities')
          .select('id')
          .eq('country_id', countryId)
          .eq('is_active', true)
          .maybeSingle();

      if (authorityResponse == null) return [];

      final authorityId = authorityResponse['id'] as String;
      return await getTaxRatesForAuthority(authorityId);
    } catch (e) {
      throw Exception('Failed to get tax rates for country: $e');
    }
  }

  /// Create a new vehicle tax rate (bridge method)
  /// Finds the authority for the country and calls createTaxRateForAuthority
  static Future<void> createTaxRate({
    required String countryId,
    required String vehicleTypeId,
    required double taxAmount,
    required String currency,
    String? borderId,
  }) async {
    try {
      // Find authority for country
      final authorityResponse = await _supabase
          .from('authorities')
          .select('id')
          .eq('country_id', countryId)
          .eq('is_active', true)
          .maybeSingle();

      if (authorityResponse == null) {
        throw Exception('Authority not found for country');
      }

      final authorityId = authorityResponse['id'] as String;
      await createTaxRateForAuthority(
        authorityId: authorityId,
        vehicleTypeId: vehicleTypeId,
        taxAmount: taxAmount,
        currency: currency,
        borderId: borderId,
      );
    } catch (e) {
      throw Exception('Failed to create tax rate: $e');
    }
  }

  /// Update an existing vehicle tax rate (bridge method)
  /// Finds the authority for the country and calls updateTaxRateForAuthority
  static Future<void> updateTaxRate({
    required String countryId,
    required String vehicleTypeId,
    required double taxAmount,
    required String currency,
    String? borderId,
  }) async {
    try {
      // Find authority for country
      final authorityResponse = await _supabase
          .from('authorities')
          .select('id')
          .eq('country_id', countryId)
          .eq('is_active', true)
          .maybeSingle();

      if (authorityResponse == null) {
        throw Exception('Authority not found for country');
      }

      final authorityId = authorityResponse['id'] as String;
      await updateTaxRateForAuthority(
        authorityId: authorityId,
        vehicleTypeId: vehicleTypeId,
        taxAmount: taxAmount,
        currency: currency,
        borderId: borderId,
      );
    } catch (e) {
      throw Exception('Failed to update tax rate: $e');
    }
  }

  /// Delete a vehicle tax rate (bridge method)
  /// Finds the authority for the country and calls deleteTaxRateForAuthority
  static Future<void> deleteTaxRate({
    required String countryId,
    required String vehicleTypeId,
    String? borderId,
  }) async {
    try {
      // Find authority for country
      final authorityResponse = await _supabase
          .from('authorities')
          .select('id')
          .eq('country_id', countryId)
          .eq('is_active', true)
          .maybeSingle();

      if (authorityResponse == null) {
        throw Exception('Authority not found for country');
      }

      final authorityId = authorityResponse['id'] as String;
      await deleteTaxRateForAuthority(
        authorityId: authorityId,
        vehicleTypeId: vehicleTypeId,
        borderId: borderId,
      );
    } catch (e) {
      throw Exception('Failed to delete tax rate: $e');
    }
  }

  /// Get borders for a country (bridge method)
  /// Finds the authority for the country and calls getBordersForAuthority
  static Future<List<border_model.Border>> getBordersForCountry(
    String countryId,
  ) async {
    try {
      // Find authority for country
      final authorityResponse = await _supabase
          .from('authorities')
          .select('id')
          .eq('country_id', countryId)
          .eq('is_active', true)
          .maybeSingle();

      if (authorityResponse == null) return [];

      final authorityId = authorityResponse['id'] as String;
      return await getBordersForAuthority(authorityId);
    } catch (e) {
      throw Exception('Failed to get borders for country: $e');
    }
  }
}
