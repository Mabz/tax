import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle_tax_rate.dart';
import '../models/vehicle_type.dart';
import '../models/border.dart' as border_model;
import '../models/currency.dart';

class VehicleTaxRateService {
  static final _supabase = Supabase.instance.client;

  /// Get all vehicle tax rates for a country
  static Future<List<VehicleTaxRate>> getTaxRatesForCountry(
    String countryId,
  ) async {
    try {
      final response = await _supabase.rpc('get_vehicle_tax_rates_for_country', params: {
        'target_country_id': countryId,
      });

      return (response as List)
          .map((item) => VehicleTaxRate.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get tax rates: $e');
    }
  }

  /// Create a new vehicle tax rate
  static Future<void> createTaxRate({
    required String countryId,
    required String vehicleTypeId,
    required double taxAmount,
    required String currency,
    String? borderId,
  }) async {
    try {
      await _supabase.rpc('create_vehicle_tax_rate', params: {
        'target_country_id': countryId,
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
  static Future<void> updateTaxRate({
    required String countryId,
    required String vehicleTypeId,
    required double taxAmount,
    required String currency,
    String? borderId,
  }) async {
    try {
      await _supabase.rpc('update_vehicle_tax_rate', params: {
        'target_country_id': countryId,
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
  static Future<void> deleteTaxRate({
    required String countryId,
    required String vehicleTypeId,
    String? borderId,
  }) async {
    try {
      await _supabase.rpc('delete_vehicle_tax_rate', params: {
        'target_country_id': countryId,
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
      final response = await _supabase
          .rpc('get_vehicle_types');

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

      return (response as List)
          .map((item) => Currency.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get currencies: $e');
    }
  }

  /// Get borders for a country (for border-specific tax rates)
  static Future<List<border_model.Border>> getBordersForCountry(
    String countryId,
  ) async {
    try {
      final response = await _supabase
          .rpc('get_borders_for_country', params: {
            'target_country_id': countryId,
          });

      return (response as List)
          .map((item) {
            // Map the function result to match Border model expectations
            final mappedItem = {
              'border_id': item['border_id'],
              'country_id': countryId, // Add the country_id since it's not returned by the function
              'border_name': item['border_name'],
              'border_type_id': '', // Function doesn't return this, but Border model needs it
              'border_type_label': item['border_type'],
              'is_active': true, // Function only returns active borders
              'latitude': item['latitude'],
              'longitude': item['longitude'],
              'description': item['description'],
              'created_at': DateTime.now().toIso8601String(), // Default since not returned
              'updated_at': DateTime.now().toIso8601String(), // Default since not returned
            };
            return border_model.Border.fromJson(mappedItem);
          })
          .toList();
    } catch (e) {
      throw Exception('Failed to get borders: $e');
    }
  }
}
