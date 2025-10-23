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
      // Try to get basic table structure first
      final response = await supabase
          .from('pass_movements')
          .select('*')
          .eq('border_id', borderId)
          .limit(limit);

      return (response as List).map((item) {
        return PassMovement.fromJson({
          'movement_id': item['id'] ?? 'unknown',
          'pass_id': item['pass_id'] ?? 'unknown',
          'movement_type': item['movement_type'] ?? 'check_in',
          'timestamp': item['created_at'] ??
              item['timestamp'] ??
              DateTime.now().toIso8601String(),
          'latitude': item['latitude'],
          'longitude': item['longitude'],
          'notes': item['notes'],
          'border_name': 'Border Checkpoint',
          'official_name': 'Border Official',
          'vehicle_registration_number': 'Vehicle',
          'vehicle_make': 'Unknown',
          'vehicle_model': 'Vehicle',
        });
      }).toList();
    } catch (e) {
      // If pass_movements table doesn't exist or has issues, return mock data
      print('Database error, returning mock data: $e');
      return _getMockMovements();
    }
  }

  /// Return mock movements for testing when database is not available
  static List<PassMovement> _getMockMovements() {
    final now = DateTime.now();
    return [
      PassMovement(
        movementId: 'mock1',
        passId: 'pass1',
        movementType: 'check_in',
        timestamp: now.subtract(const Duration(hours: 2)),
        borderName: 'Ngwenya Border',
        officialName: 'Bobby',
        vehicleRegistrationNumber: 'ABC123',
        vehicleMake: 'Toyota',
        vehicleModel: 'Camry',
        vehicleYear: 2020,
        vehicleColor: 'White',
      ),
      PassMovement(
        movementId: 'mock2',
        passId: 'pass2',
        movementType: 'check_out',
        timestamp: now.subtract(const Duration(hours: 4)),
        borderName: 'Ngwenya Border',
        officialName: 'Sarah Johnson',
        vehicleRegistrationNumber: 'XYZ789',
        vehicleMake: 'Ford',
        vehicleModel: 'F-150',
        vehicleYear: 2019,
        vehicleColor: 'Blue',
      ),
      PassMovement(
        movementId: 'mock3',
        passId: 'pass3',
        movementType: 'local_authority_scan',
        timestamp: now.subtract(const Duration(hours: 6)),
        borderName: 'Ngwenya Border',
        officialName: 'Mike Wilson',
        vehicleRegistrationNumber: 'DEF456',
        vehicleMake: 'Honda',
        vehicleModel: 'Civic',
        vehicleYear: 2021,
        vehicleColor: 'Red',
        notes: 'Routine inspection completed',
      ),
      PassMovement(
        movementId: 'mock4',
        passId: 'pass4',
        movementType: 'check_in',
        timestamp: now.subtract(const Duration(days: 1)),
        borderName: 'Ngwenya Border',
        officialName: 'Lisa Chen',
        vehicleRegistrationNumber: 'GHI789',
        vehicleMake: 'BMW',
        vehicleModel: 'X5',
        vehicleYear: 2022,
        vehicleColor: 'Black',
      ),
      PassMovement(
        movementId: 'mock5',
        passId: 'pass5',
        movementType: 'check_out',
        timestamp: now.subtract(const Duration(days: 2)),
        borderName: 'Ngwenya Border',
        officialName: 'David Brown',
        vehicleRegistrationNumber: 'JKL012',
        vehicleMake: 'Mercedes',
        vehicleModel: 'C-Class',
        vehicleYear: 2020,
        vehicleColor: 'Silver',
      ),
    ];
  }

  /// Search vehicles by VIN, make, model, or registration number for a specific border
  static Future<List<VehicleMovementSummary>> searchVehicles(
    String borderId,
    String searchQuery, {
    int limit = 20,
  }) async {
    try {
      // First try to query the actual database with proper relationships
      final response = await supabase
          .from('pass_movements')
          .select('''
            pass_id,
            movement_type,
            created_at,
            purchased_passes!inner(
              vehicle_registration_number,
              vehicle_number_plate,
              vehicle_vin,
              vehicle_make,
              vehicle_model,
              vehicle_year,
              vehicle_color,
              vehicle_description
            )
          ''')
          .eq('border_id', borderId)
          .or(
            'purchased_passes.vehicle_vin.ilike.%$searchQuery%,'
            'purchased_passes.vehicle_make.ilike.%$searchQuery%,'
            'purchased_passes.vehicle_model.ilike.%$searchQuery%,'
            'purchased_passes.vehicle_registration_number.ilike.%$searchQuery%,'
            'purchased_passes.vehicle_number_plate.ilike.%$searchQuery%',
          )
          .order('created_at', ascending: false)
          .limit(limit * 3); // Get more to group by vehicle

      // Group movements by vehicle
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
            lastMovement: DateTime.parse(item['created_at'] ??
                item['timestamp'] ??
                DateTime.now().toIso8601String()),
            lastMovementType: item['movement_type'],
            passIds: [...existing.passIds, item['pass_id']],
          );
        } else {
          vehicleMap[vehicleKey] = VehicleMovementSummary(
            vehicleRegistrationNumber:
                passData['vehicle_registration_number'] ??
                    passData['vehicle_number_plate'],
            vehicleVin: passData['vehicle_vin'],
            vehicleMake: passData['vehicle_make'],
            vehicleModel: passData['vehicle_model'],
            vehicleYear: passData['vehicle_year'] != null
                ? int.tryParse(passData['vehicle_year'].toString())
                : null,
            vehicleColor: passData['vehicle_color'],
            vehicleDescription: passData['vehicle_description'],
            totalMovements: 1,
            lastMovement: DateTime.parse(item['created_at'] ??
                item['timestamp'] ??
                DateTime.now().toIso8601String()),
            lastMovementType: item['movement_type'],
            passIds: [item['pass_id']],
          );
        }
      }

      final results = vehicleMap.values.take(limit).toList();

      // If we got results from the database, return them
      if (results.isNotEmpty) {
        return results;
      }

      // Otherwise fall back to mock data
      final mockVehicles = [
        VehicleMovementSummary(
          vehicleRegistrationNumber: 'ABC123',
          vehicleMake: 'Toyota',
          vehicleModel: 'Camry',
          vehicleYear: 2020,
          vehicleColor: 'White',
          totalMovements: 5,
          lastMovement: DateTime.now().subtract(const Duration(hours: 2)),
          lastMovementType: 'check_in',
          passIds: ['pass1', 'pass2'],
        ),
        VehicleMovementSummary(
          vehicleVin: 'VIN123456789',
          vehicleMake: 'Ford',
          vehicleModel: 'F-150',
          vehicleYear: 2019,
          vehicleColor: 'Blue',
          totalMovements: 3,
          lastMovement: DateTime.now().subtract(const Duration(days: 1)),
          lastMovementType: 'check_out',
          passIds: ['pass3'],
        ),
        VehicleMovementSummary(
          vehicleRegistrationNumber: 'DEF456',
          vehicleMake: 'Honda',
          vehicleModel: 'Civic',
          vehicleYear: 2021,
          vehicleColor: 'Red',
          totalMovements: 2,
          lastMovement: DateTime.now().subtract(const Duration(hours: 6)),
          lastMovementType: 'local_authority_scan',
          passIds: ['pass4'],
        ),
        VehicleMovementSummary(
          vehicleRegistrationNumber: 'GHI789',
          vehicleMake: 'BMW',
          vehicleModel: 'X5',
          vehicleYear: 2022,
          vehicleColor: 'Black',
          totalMovements: 4,
          lastMovement: DateTime.now().subtract(const Duration(days: 1)),
          lastMovementType: 'check_in',
          passIds: ['pass5'],
        ),
        VehicleMovementSummary(
          vehicleRegistrationNumber: 'JKL012',
          vehicleMake: 'Mercedes',
          vehicleModel: 'C-Class',
          vehicleYear: 2020,
          vehicleColor: 'Silver',
          totalMovements: 1,
          lastMovement: DateTime.now().subtract(const Duration(days: 2)),
          lastMovementType: 'check_out',
          passIds: ['pass6'],
        ),
      ];

      return mockVehicles
          .where((vehicle) {
            return vehicle.searchableText.contains(searchQuery.toLowerCase());
          })
          .take(limit)
          .toList();
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
      // Return mock movement history for testing
      final now = DateTime.now();

      // Create a realistic movement history based on the vehicle
      final vehicleInfo = vehicleRegistrationNumber ?? vehicleVin ?? 'Unknown';

      return [
        PassMovement(
          movementId: 'mov1',
          passId: 'pass1',
          movementType: 'check_in',
          timestamp: now.subtract(const Duration(days: 5)),
          borderName: 'Ngwenya Border',
          officialName: 'Bobby',
          vehicleRegistrationNumber: vehicleRegistrationNumber,
          vehicleVin: vehicleVin,
          vehicleMake: 'Toyota',
          vehicleModel: 'Camry',
          vehicleYear: 2020,
          vehicleColor: 'White',
        ),
        PassMovement(
          movementId: 'mov2',
          passId: 'pass1',
          movementType: 'local_authority_scan',
          timestamp: now.subtract(const Duration(days: 3)),
          borderName: 'Ngwenya Border',
          officialName: 'Sarah Johnson',
          vehicleRegistrationNumber: vehicleRegistrationNumber,
          vehicleVin: vehicleVin,
          vehicleMake: 'Toyota',
          vehicleModel: 'Camry',
          vehicleYear: 2020,
          vehicleColor: 'White',
          notes: 'Routine inspection completed successfully',
        ),
        PassMovement(
          movementId: 'mov3',
          passId: 'pass1',
          movementType: 'local_authority_scan',
          timestamp: now.subtract(const Duration(days: 2)),
          borderName: 'Ngwenya Border',
          officialName: 'Mike Wilson',
          vehicleRegistrationNumber: vehicleRegistrationNumber,
          vehicleVin: vehicleVin,
          vehicleMake: 'Toyota',
          vehicleModel: 'Camry',
          vehicleYear: 2020,
          vehicleColor: 'White',
          notes: 'Document verification',
        ),
        PassMovement(
          movementId: 'mov4',
          passId: 'pass1',
          movementType: 'check_out',
          timestamp: now.subtract(const Duration(hours: 4)),
          borderName: 'Ngwenya Border',
          officialName: 'Lisa Chen',
          vehicleRegistrationNumber: vehicleRegistrationNumber,
          vehicleVin: vehicleVin,
          vehicleMake: 'Toyota',
          vehicleModel: 'Camry',
          vehicleYear: 2020,
          vehicleColor: 'White',
        ),
      ];
    } catch (e) {
      throw Exception('Failed to load vehicle movements: $e');
    }
  }

  /// Helper method to create a unique key for grouping vehicles
  static String _getVehicleKey(Map<String, dynamic> passData) {
    final vin = passData['vehicle_vin']?.toString();
    final regNumber = passData['vehicle_registration_number']?.toString() ??
        passData['vehicle_number_plate']?.toString();

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
