import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pass_movement.dart';

class BorderMovementService {
  static final SupabaseClient supabase = Supabase.instance.client;

  /// Helper method to safely parse vehicle year
  static int? _parseVehicleYear(Map<String, dynamic>? passData) {
    if (passData == null || passData['vehicle_year'] == null) {
      return null;
    }
    return int.tryParse(passData['vehicle_year'].toString());
  }

  /// Get all movements for a specific border with proper vehicle details from purchased_passes
  static Future<List<PassMovement>> getBorderMovements(
    String borderId, {
    int limit = 50,
    int offset = 0,
    String timeframe = '7d',
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    try {
      // Calculate date range based on timeframe
      DateTime? startDate;
      DateTime? endDate = DateTime.now();

      if (timeframe == 'custom' &&
          customStartDate != null &&
          customEndDate != null) {
        startDate = customStartDate;
        endDate = customEndDate;
      } else {
        switch (timeframe) {
          case '1d':
            startDate = DateTime.now().subtract(const Duration(days: 1));
            break;
          case '7d':
            startDate = DateTime.now().subtract(const Duration(days: 7));
            break;
          case '30d':
            startDate = DateTime.now().subtract(const Duration(days: 30));
            break;
          case '90d':
            startDate = DateTime.now().subtract(const Duration(days: 90));
            break;
        }
      }

      // Query pass_movements with purchased_passes relationship
      var query = supabase.from('pass_movements').select('''
            id,
            pass_id,
            movement_type,
            created_at,
            processed_at,
            latitude,
            longitude,
            notes,
            profile_id,
            purchased_passes!inner(
              vehicle_registration_number,
              vehicle_vin,
              vehicle_make,
              vehicle_model,
              vehicle_year,
              vehicle_color,
              vehicle_description,
              profiles(full_name, email, phone)
            )
          ''').eq('border_id', borderId);

      // Add date filtering if specified
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);

      return (response as List).map((item) {
        final passData = item['purchased_passes'] as Map<String, dynamic>?;
        final ownerProfile = passData?['profiles'] as Map<String, dynamic>?;

        return PassMovement.fromJson({
          'movement_id': item['id'],
          'pass_id': item['pass_id'],
          'movement_type': item['movement_type'],
          'timestamp': item['created_at'] ??
              item['processed_at'] ??
              DateTime.now().toIso8601String(),
          'latitude': item['latitude'],
          'longitude': item['longitude'],
          'notes': item['notes'],
          'border_name': 'Border Checkpoint',
          'official_name': 'Border Official',
          'vehicle_registration_number':
              passData?['vehicle_registration_number'],
          'vehicle_vin': passData?['vehicle_vin'],
          'vehicle_make': passData?['vehicle_make'],
          'vehicle_model': passData?['vehicle_model'],
          'vehicle_year': _parseVehicleYear(passData),
          'vehicle_color': passData?['vehicle_color'],
          'vehicle_description': passData?['vehicle_description'],
          'owner_name': ownerProfile?['full_name'],
          'owner_email': ownerProfile?['email'],
          'owner_phone': ownerProfile?['phone'],
        });
      }).toList();
    } catch (e) {
      print('Database error in getBorderMovements: $e');
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
      // Query pass_movements with purchased_passes relationship for vehicle search
      final response = await supabase
          .from('pass_movements')
          .select('''
            pass_id,
            movement_type,
            created_at,
            purchased_passes!inner(
              vehicle_registration_number,
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
            'purchased_passes.vehicle_registration_number.ilike.%$searchQuery%',
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
            lastMovement: DateTime.parse(
                item['created_at'] ?? DateTime.now().toIso8601String()),
            lastMovementType: item['movement_type'],
            passIds: [...existing.passIds, item['pass_id']],
          );
        } else {
          vehicleMap[vehicleKey] = VehicleMovementSummary(
            vehicleRegistrationNumber: passData['vehicle_registration_number'],
            vehicleVin: passData['vehicle_vin'],
            vehicleMake: passData['vehicle_make'],
            vehicleModel: passData['vehicle_model'],
            vehicleYear: _parseVehicleYear(passData),
            vehicleColor: passData['vehicle_color'],
            vehicleDescription: passData['vehicle_description'],
            totalMovements: 1,
            lastMovement: DateTime.parse(
                item['created_at'] ?? DateTime.now().toIso8601String()),
            lastMovementType: item['movement_type'],
            passIds: [item['pass_id']],
          );
        }
      }

      final results = vehicleMap.values.take(limit).toList();
      return results;
    } catch (e) {
      print('Database error in searchVehicles: $e');
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
            created_at,
            processed_at,
            latitude,
            longitude,
            notes,
            profile_id,
            purchased_passes!inner(
              vehicle_registration_number,
              vehicle_vin,
              vehicle_make,
              vehicle_model,
              vehicle_year,
              vehicle_color,
              vehicle_description,
              profiles(full_name, email, phone)
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

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((item) {
        final passData = item['purchased_passes'] as Map<String, dynamic>?;
        final ownerProfile = passData?['profiles'] as Map<String, dynamic>?;

        return PassMovement.fromJson({
          'movement_id': item['id'],
          'pass_id': item['pass_id'],
          'movement_type': item['movement_type'],
          'timestamp': item['created_at'] ??
              item['processed_at'] ??
              DateTime.now().toIso8601String(),
          'latitude': item['latitude'],
          'longitude': item['longitude'],
          'notes': item['notes'],
          'border_name': 'Border Checkpoint',
          'official_name': 'Border Official',
          'vehicle_registration_number':
              passData?['vehicle_registration_number'],
          'vehicle_vin': passData?['vehicle_vin'],
          'vehicle_make': passData?['vehicle_make'],
          'vehicle_model': passData?['vehicle_model'],
          'vehicle_year': _parseVehicleYear(passData),
          'vehicle_color': passData?['vehicle_color'],
          'vehicle_description': passData?['vehicle_description'],
          'owner_name': ownerProfile?['full_name'],
          'owner_email': ownerProfile?['email'],
          'owner_phone': ownerProfile?['phone'],
        });
      }).toList();
    } catch (e) {
      print('Database error in getVehicleMovements: $e');
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
