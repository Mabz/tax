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
              is_active
            ),
            authorities(
              id,
              name,
              code,
              country_id,
              countries(name, country_code)
            )
          ''')
          .or('vehicle_registration_number.ilike.%$cleanedPlate%')
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toIso8601String())
          .gt('entries_remaining', 0)
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
              is_active
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
          .gt('expires_at', DateTime.now().toIso8601String())
          .gt('entries_remaining', 0)
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

      final cleanedTerm = searchTerm.trim();

      // Try using the database function first (if available)
      try {
        final rpcResponse =
            await _supabase.rpc('search_passes_by_vehicle', params: {
          'search_term': cleanedTerm,
        });

        if (rpcResponse != null &&
            rpcResponse is List &&
            rpcResponse.isNotEmpty) {
          debugPrint(
              '🔍 Found ${rpcResponse.length} passes using RPC function');
          return (rpcResponse as List).map((json) {
            final passData = json as Map<String, dynamic>;
            // Convert RPC response format to match expected format
            passData['id'] = passData['pass_id'];
            passData['amount'] = passData['tax_amount'];
            passData['currency'] = passData['currency_code'];
            return PurchasedPass.fromJson(passData);
          }).toList();
        }
      } catch (rpcError) {
        debugPrint('RPC function not available, using direct query: $rpcError');
      }

      // Fallback to direct query
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
              is_active
            ),
            authorities(
              id,
              name,
              code,
              country_id,
              countries(name, country_code)
            )
          ''')
          .or('vehicle_registration_number.ilike.%$cleanedTerm%,vehicle_vin.ilike.%$cleanedTerm%')
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toIso8601String())
          .gt('entries_remaining', 0)
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
      if (e.toString().contains('could not embed') ||
          e.toString().contains('more than one relationship')) {
        throw Exception(
            'Database relationship error. Please contact support to fix the schema configuration.');
      }
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

    // Border information should already be denormalized in the purchased_passes table
    // as entry_point_name and exit_point_name columns, so no need to fetch from relationships

    return PurchasedPass.fromJson(passData);
  }
}
