import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchased_pass.dart';

class VehicleSearchService {
  static final _supabase = Supabase.instance.client;

  /// Search for passes by vehicle number plate
  static Future<List<PurchasedPass>> searchPassesByNumberPlate(
      String numberPlate) async {
    if (numberPlate.trim().isEmpty) {
      return [];
    }

    try {
      debugPrint('🔍 Searching passes by number plate: $numberPlate');

      final cleanedPlate = numberPlate.trim().toUpperCase();

      final response = await _supabase
          .from('purchased_passes')
          .select('''
            *,
            pass_templates(
              id,
              description,
              entry_limit,
              expiration_days,
              tax_amount,
              currency_code,
              authority_id,
              border_id,
              is_active,
              borders(
                id,
                name
              )
            ),
            authorities(
              id,
              name,
              code,
              country_id,
              countries(name, country_code)
            )
          ''')
          .ilike('vehicle_number_plate', '%$cleanedPlate%')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(20);

      final List<dynamic> data = response as List<dynamic>;
      debugPrint(
          '🔍 Found ${data.length} passes for number plate: $numberPlate');

      return data.map((json) {
        final passData = json as Map<String, dynamic>;
        return _flattenPassData(passData);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error searching passes by number plate: $e');
      throw Exception('Failed to search passes by number plate: $e');
    }
  }

  /// Search for passes by vehicle VIN
  static Future<List<PurchasedPass>> searchPassesByVin(String vin) async {
    if (vin.trim().isEmpty) {
      return [];
    }

    try {
      debugPrint('🔍 Searching passes by VIN: $vin');

      final cleanedVin = vin.trim().toUpperCase();

      final response = await _supabase
          .from('purchased_passes')
          .select('''
            *,
            pass_templates(
              id,
              description,
              entry_limit,
              expiration_days,
              tax_amount,
              currency_code,
              authority_id,
              border_id,
              is_active,
              borders(
                id,
                name
              )
            ),
            authorities(
              id,
              name,
              code,
              country_id,
              countries(name, country_code)
            )
          ''')
          .ilike('vehicle_vin', '%$cleanedVin%')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(20);

      final List<dynamic> data = response as List<dynamic>;
      debugPrint('🔍 Found ${data.length} passes for VIN: $vin');

      return data.map((json) {
        final passData = json as Map<String, dynamic>;
        return _flattenPassData(passData);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error searching passes by VIN: $e');
      throw Exception('Failed to search passes by VIN: $e');
    }
  }

  /// Combined search for passes by number plate or VIN
  static Future<List<PurchasedPass>> searchPassesByVehicle(
      String searchTerm) async {
    if (searchTerm.trim().isEmpty) {
      return [];
    }

    try {
      debugPrint('🔍 Searching passes by vehicle identifier: $searchTerm');

      final cleanedTerm = searchTerm.trim().toUpperCase();

      final response = await _supabase
          .from('purchased_passes')
          .select('''
            *,
            pass_templates(
              id,
              description,
              entry_limit,
              expiration_days,
              tax_amount,
              currency_code,
              authority_id,
              border_id,
              is_active,
              borders(
                id,
                name
              )
            ),
            authorities(
              id,
              name,
              code,
              country_id,
              countries(name, country_code)
            )
          ''')
          .or('vehicle_number_plate.ilike.%$cleanedTerm%,vehicle_vin.ilike.%$cleanedTerm%')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(20);

      final List<dynamic> data = response as List<dynamic>;
      debugPrint('🔍 Found ${data.length} passes for vehicle: $searchTerm');

      return data.map((json) {
        final passData = json as Map<String, dynamic>;
        return _flattenPassData(passData);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error searching passes by vehicle: $e');
      throw Exception('Failed to search passes by vehicle: $e');
    }
  }

  /// Helper method to flatten pass data from database response
  static PurchasedPass _flattenPassData(Map<String, dynamic> passData) {
    // Flatten pass_templates data into the main object
    if (passData['pass_templates'] != null) {
      final template = passData['pass_templates'] as Map<String, dynamic>;

      passData['entry_limit'] = template['entry_limit'];
      passData['amount'] = template['tax_amount'];
      passData['currency'] = template['currency_code'];

      // Flatten border information if available
      if (template['borders'] != null) {
        final border = template['borders'] as Map<String, dynamic>;
        passData['border_name'] = border['name'];
      }
    }

    // Flatten authorities data
    if (passData['authorities'] != null) {
      final authority = passData['authorities'] as Map<String, dynamic>;
      passData['authority_id'] = authority['id'];
      passData['authority_name'] = authority['name'];

      // Flatten country information
      if (authority['countries'] != null) {
        final country = authority['countries'] as Map<String, dynamic>;
        passData['country_name'] = country['name'];
      }
    }

    return PurchasedPass.fromJson(passData);
  }
}
