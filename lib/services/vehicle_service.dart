import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle.dart';

class VehicleService {
  static final _supabase = Supabase.instance.client;

  /// Creates a new vehicle for the current user
  static Future<void> createVehicle({
    required String numberPlate,
    required String description,
    String? vinNumber,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    await _supabase.rpc('create_vehicle', params: {
      'target_profile_id': user.id,
      'number_plate': numberPlate,
      'description': description,
      'vin_number': vinNumber,
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
    return data.map((json) => Vehicle.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Updates an existing vehicle
  static Future<void> updateVehicle({
    required String vehicleId,
    required String numberPlate,
    required String description,
    String? vinNumber,
  }) async {
    await _supabase.rpc('update_vehicle', params: {
      'vehicle_id': vehicleId,
      'new_number_plate': numberPlate,
      'new_description': description,
      'new_vin_number': vinNumber,
    });
  }

  /// Deletes a vehicle
  static Future<void> deleteVehicle(String vehicleId) async {
    await _supabase.rpc('delete_vehicle', params: {
      'vehicle_id': vehicleId,
    });
  }
}
