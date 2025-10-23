import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pass_movement.dart';

class BorderMovementService {
  static final SupabaseClient supabase = Supabase.instance.client;

  /// Get all movements for a specific border
  static Future<List<PassMovement>> getBorderMovements(
    String borderId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await supabase
          .from('pass_movements')
          .select('''
            id,
            pass_id,
            movement_type,
            timestamp,
            latitude,
            longitude,
            notes,
            borders!inner(name),
            border_officials(
              profiles(first_name, last_name, profile_image_url)
            ),
            purchased_passes!inner(
              vehicle_registration_number,
              vehicle_number_plate,
              vehicle_vin,
              vehicle_make,
              vehicle_model,
              vehicle_year,
              vehicle_color,
              vehicle_description,
              profiles(first_name, last_name, email, phone)
            )
          ''')
          .eq('border_id', borderId)
          .order('timestamp', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((item) {
        // Extract nested data
        final borderData = item['borders'] as Map<String, dynamic>?;
        final officialData = item['border_officials'] as Map<String, dynamic>?;
        final officialProfile =
            officialData?['profiles'] as Map<String, dynamic>?;
        final passData = item['purchased_passes'] as Map<String, dynamic>?;
        final ownerProfile = passData?['profiles'] as Map<String, dynamic>?;

        return PassMovement.fromJson({
          'movement_id': item['id'],
          'pass_id': item['pass_id'],
          'movement_type': item['movement_type'],
          'timestamp': item['timestamp'],
          'latitude': item['latitude'],
          'longitude': item['longitude'],
          'notes': item['notes'],
          'border_name': borderData?['name'],
          'official_name': officialProfile != null
              ? '${officialProfile['first_name'] ?? ''} ${officialProfile['last_name'] ?? ''}'
                  .trim()
              : null,
          'official_profile_image_url': officialProfile?['profile_image_url'],
          'vehicle_registration_number':
              passData?['vehicle_registration_number'],
          'vehicle_vin': passData?['vehicle_vin'],
          'vehicle_make': passData?['vehicle_make'],
          'vehicle_model': passData?['vehicle_model'],
          'vehicle_year': passData?['vehicle_year'],
          'vehicle_color': passData?['vehicle_color'],
          'vehicle_description': passData?['vehicle_description'],
          'owner_name': ownerProfile != null
              ? '${ownerProfile['first_name'] ?? ''} ${ownerProfile['last_name'] ?? ''}'
                  .trim()
              : null,
          'owner_email': ownerProfile?['email'],
          'owner_phone': ownerProfile?['phone'],
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to load border movements: $e');
    }
  }

  /// Search vehicles by VIN, make, model, or registration number for a specific border
  static Future<List<VehicleMovementSummary>> searchVehicles(
    String borderId,
    String searchQuery, {
    int limit = 20,
  }) async {
    try {
      final response = await supabase.rpc('search_border_vehicles', params: {
        'border_id_param': borderId,
        'search_query': searchQuery.toLowerCase(),
        'result_limit': limit,
      });

      return (response as List).map((item) {
        return VehicleMovementSummary.fromJson(item);
      }).toList();
    } catch (e) {
      // Fallback to manual search if RPC function doesn't exist
      return await _fallbackVehicleSearch(borderId, searchQuery, limit);
    }
  }

  /// Fallback vehicle search using regular queries
  static Future<List<VehicleMovementSummary>> _fallbackVehicleSearch(
    String borderId,
    String searchQuery,
    int limit,
  ) async {
    try {
      final response = await supabase
          .from('pass_movements')
          .select('''
            purchased_passes!inner(
              pass_id,
              vehicle_registration_number,
              vehicle_vin,
              vehicle_make,
              vehicle_model,
              vehicle_year,
              vehicle_color,
              vehicle_description
            ),
            movement_type,
            timestamp
          ''')
          .eq('border_id', borderId)
          .or(
            'purchased_passes.vehicle_vin.ilike.%$searchQuery%,'
            'purchased_passes.vehicle_make.ilike.%$searchQuery%,'
            'purchased_passes.vehicle_model.ilike.%$searchQuery%,'
            'purchased_passes.vehicle_registration_number.ilike.%$searchQuery%',
          )
          .order('timestamp', ascending: false)
          .limit(limit * 3); // Get more to group by vehicle

      // Group by vehicle
      final Map<String, VehicleMovementSummary> vehicleMap = {};

      for (final item in response as List) {
        final passData = item['purchased_passes'] as Map<String, dynamic>;
        final vehicleKey = _getVehicleKey(passData);

        if (vehicleMap.containsKey(vehicleKey)) {
          final existing = vehicleMap[vehicleKey]!;
          vehicleMap[vehicleKey] = VehicleMovementSummary(
            vehicleRegistrationNumber: existing.vehicleRegistrationNumber,
            vehicleVin: existing.vehicleVin,
            vehicleMake: existing.vehicleMake,
            vehicleModel: existing.vehicleModel,
            vehicleYear: existing.vehicleYear,
            vehicleColor: existing.vehicleColor,
            vehicleDescription: existing.vehicleDescription,
            totalMovements: existing.totalMovements + 1,
            lastMovement: DateTime.parse(item['timestamp']),
            lastMovementType: item['movement_type'],
            passIds: [...existing.passIds, passData['pass_id']],
          );
        } else {
          vehicleMap[vehicleKey] = VehicleMovementSummary(
            vehicleRegistrationNumber: passData['vehicle_registration_number'],
            vehicleVin: passData['vehicle_vin'],
            vehicleMake: passData['vehicle_make'],
            vehicleModel: passData['vehicle_model'],
            vehicleYear: passData['vehicle_year'],
            vehicleColor: passData['vehicle_color'],
            vehicleDescription: passData['vehicle_description'],
            totalMovements: 1,
            lastMovement: DateTime.parse(item['timestamp']),
            lastMovementType: item['movement_type'],
            passIds: [passData['pass_id']],
          );
        }
      }

      return vehicleMap.values.take(limit).toList();
    } catch (e) {
      throw Exception('Failed to search vehicles: $e');
    }
  }

  /// Get all movements for a specific vehicle (by VIN or registration number)
  static Future<List<PassMovement>> getVehicleMovements(
    String borderId,
    String? vehicleVin,
    String? vehicleRegistrationNumber,
  ) async {
    try {
      var query = supabase.from('pass_movements').select('''
            id,
            pass_id,
            movement_type,
            timestamp,
            latitude,
            longitude,
            notes,
            borders!inner(name),
            border_officials(
              profiles(first_name, last_name, profile_image_url)
            ),
            purchased_passes!inner(
              vehicle_registration_number,
              vehicle_vin,
              vehicle_make,
              vehicle_model,
              vehicle_year,
              vehicle_color,
              vehicle_description,
              profiles(first_name, last_name, email, phone)
            )
          ''').eq('border_id', borderId);

      if (vehicleVin != null && vehicleVin.isNotEmpty) {
        query = query.eq('purchased_passes.vehicle_vin', vehicleVin);
      } else if (vehicleRegistrationNumber != null &&
          vehicleRegistrationNumber.isNotEmpty) {
        query = query.eq('purchased_passes.vehicle_registration_number',
            vehicleRegistrationNumber);
      } else {
        throw Exception('Either VIN or registration number must be provided');
      }

      final response = await query.order('timestamp', ascending: false);

      return (response as List).map((item) {
        // Extract nested data
        final borderData = item['borders'] as Map<String, dynamic>?;
        final officialData = item['border_officials'] as Map<String, dynamic>?;
        final officialProfile =
            officialData?['profiles'] as Map<String, dynamic>?;
        final passData = item['purchased_passes'] as Map<String, dynamic>?;
        final ownerProfile = passData?['profiles'] as Map<String, dynamic>?;

        return PassMovement.fromJson({
          'movement_id': item['id'],
          'pass_id': item['pass_id'],
          'movement_type': item['movement_type'],
          'timestamp': item['timestamp'],
          'latitude': item['latitude'],
          'longitude': item['longitude'],
          'notes': item['notes'],
          'border_name': borderData?['name'],
          'official_name': officialProfile != null
              ? '${officialProfile['first_name'] ?? ''} ${officialProfile['last_name'] ?? ''}'
                  .trim()
              : null,
          'official_profile_image_url': officialProfile?['profile_image_url'],
          'vehicle_registration_number':
              passData?['vehicle_registration_number'],
          'vehicle_vin': passData?['vehicle_vin'],
          'vehicle_make': passData?['vehicle_make'],
          'vehicle_model': passData?['vehicle_model'],
          'vehicle_year': passData?['vehicle_year'],
          'vehicle_color': passData?['vehicle_color'],
          'vehicle_description': passData?['vehicle_description'],
          'owner_name': ownerProfile != null
              ? '${ownerProfile['first_name'] ?? ''} ${ownerProfile['last_name'] ?? ''}'
                  .trim()
              : null,
          'owner_email': ownerProfile?['email'],
          'owner_phone': ownerProfile?['phone'],
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to load vehicle movements: $e');
    }
  }

  /// Helper method to create a unique key for grouping vehicles
  static String _getVehicleKey(Map<String, dynamic> passData) {
    final vin = passData['vehicle_vin']?.toString();
    final regNumber = passData['vehicle_registration_number']?.toString();

    if (vin != null && vin.isNotEmpty) {
      return 'vin:$vin';
    } else if (regNumber != null && regNumber.isNotEmpty) {
      return 'reg:$regNumber';
    } else {
      // Fallback to make/model/year combination
      final make = passData['vehicle_make']?.toString() ?? '';
      final model = passData['vehicle_model']?.toString() ?? '';
      final year = passData['vehicle_year']?.toString() ?? '';
      return 'combo:$make-$model-$year';
    }
  }
}
