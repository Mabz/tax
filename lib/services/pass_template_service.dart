import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pass_template.dart';
import '../models/vehicle_tax_rate.dart';
import '../models/vehicle_type.dart';
import '../models/border.dart' as border_model;
import '../models/currency.dart';

class PassTemplateService {
  static final _supabase = Supabase.instance.client;

  /// Creates a new pass template
  static Future<void> createPassTemplate({
    required String authorityId,
    required String creatorProfileId,
    required String vehicleTypeId,
    required String description,
    required int entryLimit,
    required int expirationDays,
    required double taxAmount,
    required String currencyCode,
    String? borderId,
  }) async {
    try {
      await _supabase.rpc('create_pass_template', params: {
        'target_authority_id': authorityId,
        'creator_profile_id': creatorProfileId,
        'vehicle_type_id': vehicleTypeId,
        'description': description,
        'entry_limit': entryLimit,
        'expiration_days': expirationDays,
        'tax_amount': taxAmount,
        'currency_code': currencyCode,
        'target_border_id': borderId,
      });
    } catch (e) {
      throw Exception('Failed to create pass template: $e');
    }
  }

  /// Updates an existing pass template
  static Future<void> updatePassTemplate({
    required String templateId,
    required String description,
    required int entryLimit,
    required int expirationDays,
    required double taxAmount,
    required String currencyCode,
    required bool isActive,
  }) async {
    try {
      await _supabase.rpc('update_pass_template', params: {
        'template_id': templateId,
        'new_description': description,
        'new_entry_limit': entryLimit,
        'new_expiration_days': expirationDays,
        'new_tax_amount': taxAmount,
        'new_currency_code': currencyCode,
        'new_is_active': isActive,
      });
    } catch (e) {
      throw Exception('Failed to update pass template: $e');
    }
  }

  /// Deletes a pass template
  static Future<void> deletePassTemplate(String templateId) async {
    try {
      await _supabase.rpc('delete_pass_template', params: {
        'template_id': templateId,
      });
    } catch (e) {
      throw Exception('Failed to delete pass template: $e');
    }
  }

  /// Gets pass templates for an authority (with JOIN data)
  static Future<List<PassTemplate>> getPassTemplatesForAuthority(
      String authorityId) async {
    try {
      final response =
          await _supabase.rpc('get_pass_templates_for_authority', params: {
        'target_authority_id': authorityId,
      });

      if (response == null) return [];

      return (response as List)
          .map((item) => PassTemplate.fromJson({
                'id': item['id'],
                'authority_id': authorityId,
                'border_id': null, // Will be handled by border_name
                'created_by_profile_id': '', // Not returned by function
                'vehicle_type_id': '', // Will be handled by vehicle_type
                'description': item['description'],
                'entry_limit': item['entry_limit'],
                'expiration_days': item['expiration_days'],
                'tax_amount': item['tax_amount'],
                'currency_code': item['currency_code'],
                'is_active': item['is_active'],
                'created_at': DateTime.now()
                    .toIso8601String(), // Not returned by function
                'updated_at': DateTime.now()
                    .toIso8601String(), // Not returned by function
                'border_name': item['border_name'],
                'vehicle_type': item['vehicle_type'],
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to get pass templates: $e');
    }
  }

  /// Gets vehicle tax rates for an authority to use as templates
  static Future<List<VehicleTaxRate>> getTaxRatesForAuthority(
      String authorityId) async {
    try {
      final response =
          await _supabase.rpc('get_vehicle_tax_rates_for_authority', params: {
        'target_authority_id': authorityId,
      });

      if (response == null) return [];

      return (response as List)
          .map((item) => VehicleTaxRate.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get tax rates: $e');
    }
  }

  /// Gets vehicle types for dropdown
  static Future<List<VehicleType>> getVehicleTypes() async {
    try {
      final response = await _supabase.rpc('get_vehicle_types');

      if (response == null) return [];

      return (response as List)
          .map((item) => VehicleType.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get vehicle types: $e');
    }
  }

  /// Gets borders for an authority
  static Future<List<border_model.Border>> getBordersForAuthority(
      String authorityId) async {
    try {
      final response =
          await _supabase.rpc('get_borders_for_authority', params: {
        'target_authority_id': authorityId,
      });

      if (response == null) return [];

      return (response as List).map((item) {
        return border_model.Border.fromJson({
          'border_id': item['border_id'],
          'border_name': item['border_name'],
          'authority_id': authorityId,
          'border_type_id': '', // Not needed for this use case
          'border_type': item['border_type'] ?? '',
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to get borders: $e');
    }
  }

  /// Gets active currencies for dropdown
  static Future<List<Currency>> getActiveCurrencies() async {
    try {
      final response = await _supabase.rpc('get_active_currencies');

      if (response == null) return [];

      return (response as List).map((item) => Currency.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to get currencies: $e');
    }
  }

  // Note: Bridge methods removed - now using authority-based approach directly
  // All screens should get authority ID first, then use authority-based methods
}
