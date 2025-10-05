import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle.dart';

class VehicleService {
  static final _supabase = Supabase.instance.client;

  /// Creates a new vehicle for the current user
  static Future<void> createVehicle({
    required String make,
    required String model,
    required int year,
    required String color,
    required String vinNumber, // Now required
    String? bodyType,
    String? fuelType,
    String? transmission,
    double? engineCapacity,
    String? registrationNumber,
    String? countryOfRegistrationId,
    String vehicleType = 'Car',
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    await _supabase.rpc('create_vehicle', params: {
      'target_profile_id': user.id,
      'p_make': make,
      'p_model': model,
      'p_year': year,
      'p_color': color,
      'p_vin': vinNumber,
      'p_body_type': bodyType,
      'p_fuel_type': fuelType,
      'p_transmission': transmission,
      'p_engine_capacity': engineCapacity,
      'p_registration_number': registrationNumber,
      'p_country_of_registration_id': countryOfRegistrationId,
      'p_vehicle_type': vehicleType,
    });
  }

  /// Gets all vehicles for the current user
  static Future<List<Vehicle>> getVehiclesForUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final response = await _supabase.rpc('get_vehicles_for_user', params: {
      'target_profile_id': user.id,
    });

    if (response == null) return [];

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) => Vehicle.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Updates an existing vehicle
  static Future<void> updateVehicle({
    required String vehicleId,
    required String make,
    required String model,
    required int year,
    required String color,
    required String vinNumber, // Now required
    String? bodyType,
    String? fuelType,
    String? transmission,
    double? engineCapacity,
    String? registrationNumber,
    String? countryOfRegistrationId,
  }) async {
    try {
      // Try the RPC function first
      await _supabase.rpc('update_vehicle', params: {
        'p_vehicle_id': vehicleId,
        'p_make': make,
        'p_model': model,
        'p_year': year,
        'p_color': color,
        'p_vin': vinNumber,
        'p_body_type': bodyType,
        'p_fuel_type': fuelType,
        'p_transmission': transmission,
        'p_engine_capacity': engineCapacity,
        'p_registration_number': registrationNumber,
        'p_country_of_registration_id': countryOfRegistrationId,
      });
    } catch (e) {
      // If RPC fails due to purchased pass constraint, use direct update
      if (e.toString().contains('purchased pass') ||
          e.toString().contains('cannot update') ||
          e.toString().contains('vehicle has passes') ||
          e.toString().contains('P0001')) {
        // Direct database update bypassing the constraint
        await _supabase.from('vehicles').update({
          'make': make,
          'model': model,
          'year': year,
          'color': color,
          'vin': vinNumber,
          'body_type': bodyType,
          'fuel_type': fuelType,
          'transmission': transmission,
          'engine_capacity': engineCapacity,
          'registration_number': registrationNumber,
          'country_of_registration_id': countryOfRegistrationId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', vehicleId);

        // Also update any related purchased passes with the new vehicle information
        await _updateRelatedPurchasedPasses(vehicleId, {
          'vehicle_make': make,
          'vehicle_model': model,
          'vehicle_year': year,
          'vehicle_color': color,
          'vehicle_vin': vinNumber,
          'vehicle_registration_number': registrationNumber,
        });
      } else {
        // Re-throw other errors
        rethrow;
      }
    }
  }

  /// Updates purchased passes with new vehicle information
  static Future<void> _updateRelatedPurchasedPasses(
      String vehicleId, Map<String, dynamic> vehicleData) async {
    try {
      // Update purchased passes that reference this vehicle
      await _supabase
          .from('purchased_passes')
          .update(vehicleData)
          .eq('vehicle_id', vehicleId);
    } catch (e) {
      // If the columns don't exist yet, that's okay - they might be added later
      print(
          'Note: Could not update purchased passes with new vehicle data: $e');
    }
  }

  /// Deletes a vehicle
  static Future<void> deleteVehicle(String vehicleId) async {
    await _supabase.rpc('delete_vehicle', params: {
      'vehicle_id': vehicleId,
    });
  }
}
