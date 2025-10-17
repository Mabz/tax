import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// Service for handling border selection and GPS validation for border officials
class BorderSelectionService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all borders assigned to the current border official
  static Future<List<AssignedBorder>> getOfficialAssignedBorders() async {
    try {
      debugPrint('🔍 Getting assigned borders for current official');

      final response =
          await _supabase.rpc('get_official_assigned_borders', params: {
        'p_profile_id': _supabase.auth.currentUser?.id,
      });

      debugPrint('✅ Retrieved ${response.length} assigned borders');

      return (response as List)
          .map((item) => AssignedBorder.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting assigned borders: $e');
      return [];
    }
  }

  /// Find the nearest border from official's assigned borders
  static Future<List<AssignedBorder>> findNearestAssignedBorders({
    required double currentLat,
    required double currentLon,
  }) async {
    try {
      debugPrint(
          '🔍 Finding nearest assigned borders from GPS: $currentLat, $currentLon');

      final response =
          await _supabase.rpc('find_nearest_assigned_border', params: {
        'p_profile_id': _supabase.auth.currentUser?.id,
        'p_current_lat': currentLat,
        'p_current_lon': currentLon,
      });

      debugPrint('✅ Found ${response.length} nearby borders');

      return (response as List)
          .map((item) => AssignedBorder.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('❌ Error finding nearest borders: $e');
      return [];
    }
  }

  /// Validate GPS distance to a specific border
  static Future<GpsValidationResult> validateBorderGpsDistance({
    required String passId,
    required String borderId,
    required double currentLat,
    required double currentLon,
    double maxDistanceKm = 30.0,
  }) async {
    try {
      debugPrint('🔍 Validating GPS distance to border: $borderId');
      debugPrint('📍 Current GPS: $currentLat, $currentLon');

      final response =
          await _supabase.rpc('validate_border_gps_distance', params: {
        'p_pass_id': passId,
        'p_border_id': borderId,
        'p_current_lat': currentLat,
        'p_current_lon': currentLon,
        'p_max_distance_km': maxDistanceKm,
      });

      debugPrint('✅ GPS validation completed');
      return GpsValidationResult.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error validating GPS distance: $e');
      return GpsValidationResult.error('Failed to validate GPS distance: $e');
    }
  }

  /// Log official's decision on distance violations
  static Future<bool> logDistanceViolationResponse({
    required String auditId,
    required String decision, // 'proceed' or 'cancel'
    String? notes,
  }) async {
    try {
      debugPrint('📝 Logging distance violation response: $decision');

      final response =
          await _supabase.rpc('log_distance_violation_response', params: {
        'p_audit_id': auditId,
        'p_official_decision': decision,
        'p_notes': notes,
      });

      final success = response['success'] as bool? ?? false;
      debugPrint(success
          ? '✅ Response logged successfully'
          : '❌ Failed to log response');

      return success;
    } catch (e) {
      debugPrint('❌ Error logging violation response: $e');
      return false;
    }
  }

  /// Process pass movement with GPS validation
  static Future<BorderProcessingResult> processPassMovementWithGpsValidation({
    required String passId,
    required String borderId,
    required double currentLat,
    required double currentLon,
    bool gpsValidationOverride = false,
    String? overrideReason,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('🚀 Processing pass movement with GPS validation');
      debugPrint('📍 Pass: $passId, Border: $borderId');
      debugPrint('🌍 GPS: $currentLat, $currentLon');
      debugPrint('⚠️ Override: $gpsValidationOverride');

      final response = await _supabase
          .rpc('process_pass_movement_with_gps_validation', params: {
        'p_pass_id': passId,
        'p_border_id': borderId,
        'p_current_lat': currentLat,
        'p_current_lon': currentLon,
        'p_gps_validation_override': gpsValidationOverride,
        'p_override_reason': overrideReason,
        'p_metadata': metadata ?? {},
      });

      debugPrint('✅ Border processing completed');
      return BorderProcessingResult.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error processing pass movement: $e');
      return BorderProcessingResult.error('Failed to process movement: $e');
    }
  }

  /// Calculate distance between two GPS coordinates
  static double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) /
        1000; // Convert to kilometers
  }
}

/// Represents a border assigned to an official
class AssignedBorder {
  final String borderId;
  final String borderName;
  final double? latitude;
  final double? longitude;
  final bool canCheckIn;
  final bool canCheckOut;
  final double? distanceKm;

  AssignedBorder({
    required this.borderId,
    required this.borderName,
    this.latitude,
    this.longitude,
    required this.canCheckIn,
    required this.canCheckOut,
    this.distanceKm,
  });

  factory AssignedBorder.fromJson(Map<String, dynamic> json) {
    return AssignedBorder(
      borderId: json['border_id'] as String,
      borderName: json['border_name'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      canCheckIn: json['can_check_in'] as bool? ?? true,
      canCheckOut: json['can_check_out'] as bool? ?? true,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  String get distanceDisplay {
    if (distanceKm == null) return 'Distance unknown';
    if (distanceKm! < 1) return '${(distanceKm! * 1000).round()}m away';
    return '${distanceKm!.toStringAsFixed(1)}km away';
  }

  String get permissionsDisplay {
    if (canCheckIn && canCheckOut) return 'Check-in & Check-out';
    if (canCheckIn) return 'Check-in only';
    if (canCheckOut) return 'Check-out only';
    return 'No permissions';
  }
}

/// Result of GPS validation
class GpsValidationResult {
  final bool success;
  final bool withinRange;
  final double? distanceKm;
  final double maxAllowedKm;
  final String borderName;
  final Map<String, double>? borderCoordinates;
  final Map<String, double>? currentCoordinates;
  final String? auditId;
  final String? error;

  GpsValidationResult({
    required this.success,
    required this.withinRange,
    this.distanceKm,
    required this.maxAllowedKm,
    required this.borderName,
    this.borderCoordinates,
    this.currentCoordinates,
    this.auditId,
    this.error,
  });

  factory GpsValidationResult.fromJson(Map<String, dynamic> json) {
    return GpsValidationResult(
      success: json['success'] as bool? ?? false,
      withinRange: json['within_range'] as bool? ?? false,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      maxAllowedKm: (json['max_allowed_km'] as num?)?.toDouble() ?? 30.0,
      borderName: json['border_name'] as String? ?? 'Unknown Border',
      borderCoordinates: json['border_coordinates'] != null
          ? Map<String, double>.from(json['border_coordinates'])
          : null,
      currentCoordinates: json['current_coordinates'] != null
          ? Map<String, double>.from(json['current_coordinates'])
          : null,
      auditId: json['audit_id'] as String?,
    );
  }

  factory GpsValidationResult.error(String errorMessage) {
    return GpsValidationResult(
      success: false,
      withinRange: false,
      maxAllowedKm: 30.0,
      borderName: 'Unknown',
      error: errorMessage,
    );
  }

  String get distanceDisplay {
    if (distanceKm == null) return 'Distance unknown';
    if (distanceKm! < 1) return '${(distanceKm! * 1000).round()}m';
    return '${distanceKm!.toStringAsFixed(1)}km';
  }

  String get violationMessage {
    if (withinRange) return '';
    return 'You are $distanceDisplay away from $borderName (max allowed: ${maxAllowedKm.toStringAsFixed(0)}km)';
  }
}

/// Result of border processing
class BorderProcessingResult {
  final bool success;
  final String? movementId;
  final String? auditId;
  final String? movementType;
  final String? previousStatus;
  final String? newStatus;
  final int entriesDeducted;
  final int entriesRemaining;
  final GpsValidationResult? gpsValidation;
  final String? error;
  final String? errorType;
  final bool requiresOverride;

  BorderProcessingResult({
    required this.success,
    this.movementId,
    this.auditId,
    this.movementType,
    this.previousStatus,
    this.newStatus,
    this.entriesDeducted = 0,
    this.entriesRemaining = 0,
    this.gpsValidation,
    this.error,
    this.errorType,
    this.requiresOverride = false,
  });

  factory BorderProcessingResult.fromJson(Map<String, dynamic> json) {
    return BorderProcessingResult(
      success: json['success'] as bool? ?? false,
      movementId: json['movement_id'] as String?,
      auditId: json['audit_id'] as String?,
      movementType: json['movement_type'] as String?,
      previousStatus: json['previous_status'] as String?,
      newStatus: json['new_status'] as String?,
      entriesDeducted: json['entries_deducted'] as int? ?? 0,
      entriesRemaining: json['entries_remaining'] as int? ?? 0,
      gpsValidation: json['gps_validation'] != null
          ? GpsValidationResult.fromJson(json['gps_validation'])
          : null,
      error: json['error'] as String?,
      errorType: json['error_type'] as String?,
      requiresOverride: json['requires_override'] as bool? ?? false,
    );
  }

  factory BorderProcessingResult.error(String errorMessage) {
    return BorderProcessingResult(
      success: false,
      error: errorMessage,
    );
  }

  bool get isGpsValidationFailure => errorType == 'gps_validation_failed';

  String get actionDescription {
    switch (movementType) {
      case 'check_in':
        return 'Vehicle Checked-In';
      case 'check_out':
        return 'Vehicle Checked-Out';
      default:
        return 'Movement Processed';
    }
  }
}
