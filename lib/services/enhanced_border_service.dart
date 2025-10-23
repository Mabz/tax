import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// Enhanced border service with check-in/check-out functionality
class EnhancedBorderService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Cache GPS coordinates for 1 hour
  static Position? _cachedPosition;
  static DateTime? _lastPositionUpdate;
  static const Duration _positionCacheDuration = Duration(hours: 1);

  /// Get current GPS position with caching
  static Future<Position> getCurrentPosition() async {
    try {
      // Check if we have a cached position that's still valid
      if (_cachedPosition != null &&
          _lastPositionUpdate != null &&
          DateTime.now().difference(_lastPositionUpdate!) <
              _positionCacheDuration) {
        debugPrint('📍 Using cached GPS position');
        return _cachedPosition!;
      }

      debugPrint('📍 Getting fresh GPS position...');

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position with high accuracy for border control
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Cache the position
      _cachedPosition = position;
      _lastPositionUpdate = DateTime.now();

      debugPrint(
          '📍 GPS position updated: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('❌ Error getting GPS position: $e');
      debugPrint('⚠️ Using fallback coordinates for testing');

      // Return fallback coordinates for testing (Mbabane, Eswatini)
      return Position(
        latitude: -26.3054,
        longitude: 31.1367,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
  }

  /// Process pass movement (check-in or check-out)
  static Future<PassMovementResult> processPassMovement({
    required String passId,
    required String borderId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint(
          '🔄 Processing pass movement for pass: $passId at border: $borderId');

      // Get current GPS position (required for border processing)
      final position = await getCurrentPosition();

      // Call the database function to process the movement
      final response = await _supabase.rpc('process_pass_movement', params: {
        'p_pass_id': passId,
        'p_border_id': borderId,
        'p_latitude': position.latitude,
        'p_longitude': position.longitude,
        'p_metadata': metadata ?? {},
      });

      debugPrint('✅ Pass movement processed successfully');
      return PassMovementResult.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error processing pass movement: $e');
      rethrow;
    }
  }

  /// Check if current official can perform specific movement type at border
  static Future<bool> canProcessMovementType({
    required String borderId,
    required String movementType,
  }) async {
    try {
      debugPrint(
          '🔍 Checking permissions for $movementType at border: $borderId');

      final response =
          await _supabase.rpc('can_official_process_movement', params: {
        'p_border_id': borderId,
        'p_movement_type': movementType,
      });

      debugPrint('✅ Permission check result: $response');
      return response as bool;
    } catch (e) {
      debugPrint('❌ Error checking movement permissions: $e');
      return false;
    }
  }

  /// Determine what action would be performed for a pass
  static Future<PassActionInfo> determinePassAction(String passId) async {
    try {
      debugPrint('🔍 Determining action for pass: $passId');

      final response = await _supabase
          .from('purchased_passes')
          .select('current_status, entries_remaining, expires_at')
          .eq('id', passId)
          .single();

      final currentStatus = response['current_status'] as String? ?? 'unused';
      final entriesRemaining = response['entries_remaining'] as int? ?? 0;
      final expiresAt = response['expires_at'] != null
          ? DateTime.parse(response['expires_at'] as String)
          : DateTime.now().add(const Duration(days: 30)); // Default expiry

      String actionType;
      String actionDescription;
      bool willDeductEntry = false;

      if (currentStatus == 'unused' || currentStatus == 'checked_out') {
        actionType = 'check_in';
        actionDescription = 'Check-In Vehicle';
        willDeductEntry = true;
      } else if (currentStatus == 'checked_in') {
        actionType = 'check_out';
        actionDescription = 'Check-Out Vehicle';
        willDeductEntry = false;
      } else {
        throw Exception('Invalid pass status: $currentStatus');
      }

      // Validate pass can be used
      final now = DateTime.now();
      if (expiresAt.isBefore(now)) {
        throw Exception('Pass has expired');
      }

      if (actionType == 'check_in' && entriesRemaining < 1) {
        throw Exception('No entries remaining on pass');
      }

      debugPrint('✅ Pass action determined: $actionType');
      return PassActionInfo(
        actionType: actionType,
        actionDescription: actionDescription,
        currentStatus: currentStatus,
        willDeductEntry: willDeductEntry,
        entriesRemaining: entriesRemaining,
        expiresAt: expiresAt,
      );
    } catch (e) {
      debugPrint('❌ Error determining pass action: $e');
      rethrow;
    }
  }

  /// Get movement history for a pass
  static Future<List<PassMovement>> getPassMovementHistory(
      String passId) async {
    try {
      debugPrint('🔍 Getting movement history for pass: $passId');

      // Get basic movement history
      final response =
          await _supabase.rpc('get_pass_movement_history', params: {
        'p_pass_id': passId,
      });

      debugPrint('✅ Retrieved ${response.length} movement records');

      // Convert to PassMovement objects and enhance with additional data
      final movements = <PassMovement>[];

      // Get unique profile IDs to fetch enhanced official data
      final profileIds = <String>{};
      for (final item in response as List) {
        final movementData = item as Map<String, dynamic>;
        final profileId = movementData['profile_id'] as String?;
        if (profileId != null) {
          profileIds.add(profileId);
        }
      }

      // Fetch enhanced official data (display names and profile images)
      final Map<String, Map<String, dynamic>> enhancedOfficialData = {};
      if (profileIds.isNotEmpty) {
        try {
          // First, get authority_profiles data (priority for display_name)
          final authorityProfilesResponse = await _supabase
              .from('authority_profiles')
              .select('profile_id, display_name, is_active, notes')
              .inFilter('profile_id', profileIds.toList());

          for (final profile in authorityProfilesResponse) {
            enhancedOfficialData[profile['profile_id']] = {
              'display_name': profile['display_name'],
              'source': 'authority_profiles',
            };
          }

          // Then get regular profiles data for profile images and fallback names
          final profilesResponse = await _supabase
              .from('profiles')
              .select('id, full_name, profile_image_url')
              .inFilter('id', profileIds.toList());

          for (final profile in profilesResponse) {
            final profileId = profile['id'];
            if (enhancedOfficialData.containsKey(profileId)) {
              // Add profile image to existing authority_profiles data
              enhancedOfficialData[profileId]!['profile_image_url'] =
                  profile['profile_image_url'];
            } else {
              // Create new entry for profiles not in authority_profiles
              enhancedOfficialData[profileId] = {
                'full_name': profile['full_name'],
                'profile_image_url': profile['profile_image_url'],
                'source': 'profiles',
              };
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching enhanced official data: $e');
        }
      }

      for (final item in response as List) {
        final movementData = item as Map<String, dynamic>;
        final profileId = movementData['profile_id'] as String?;

        // Debug: Print the movement data to see what we're getting
        debugPrint('🔍 Movement data: ${movementData.toString()}');
        debugPrint(
            '🖼️ Profile image URL from DB: ${movementData['official_profile_image_url']}');

        // Get enhanced official data
        String officialName =
            movementData['official_name'] as String? ?? 'Unknown Official';
        String? officialProfileImageUrl =
            movementData['official_profile_image_url'] as String?;

        if (profileId != null && enhancedOfficialData.containsKey(profileId)) {
          final officialData = enhancedOfficialData[profileId]!;

          // Name resolution priority:
          // 1. display_name from authority_profiles (if available)
          // 2. full_name from regular profiles (fallback)
          if (officialData['source'] == 'authority_profiles' &&
              officialData['display_name'] != null) {
            officialName = officialData['display_name'];
          } else if (officialData['full_name'] != null) {
            officialName = officialData['full_name'];
          }

          // Use profile image from enhanced data if available
          if (officialData['profile_image_url'] != null) {
            officialProfileImageUrl = officialData['profile_image_url'];
          }
        }

        // Get additional data for local authority scans
        String? scanPurpose;
        String? notes;
        String? authorityType;

        if (movementData['border_name'] == 'Local Authority') {
          try {
            // Get additional details from the pass_movements table
            final detailResponse = await _supabase
                .from('pass_movements')
                .select('scan_purpose, notes, authority_type')
                .eq('id', movementData['movement_id'])
                .single();

            scanPurpose = detailResponse['scan_purpose'] as String?;
            notes = detailResponse['notes'] as String?;
            authorityType = detailResponse['authority_type'] as String?;
          } catch (e) {
            debugPrint(
                '⚠️ Could not get additional details for movement ${movementData['movement_id']}: $e');
          }
        }

        movements.add(PassMovement(
          movementId: movementData['movement_id'] as String,
          passId: passId, // Include the pass ID for vehicle/owner details
          borderName:
              movementData['border_name'] as String? ?? 'Unknown Location',
          officialName: officialName,
          officialProfileImageUrl: officialProfileImageUrl,
          movementType: movementData['movement_type'] as String,
          latitude: (movementData['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (movementData['longitude'] as num?)?.toDouble() ?? 0.0,
          processedAt: movementData['processed_at'] != null
              ? DateTime.parse(movementData['processed_at'] as String)
              : DateTime.now(),
          entriesDeducted: movementData['entries_deducted'] as int? ?? 0,
          previousStatus: movementData['previous_status'] as String? ?? '',
          newStatus: movementData['new_status'] as String? ?? '',
          scanPurpose: scanPurpose,
          notes: notes,
          authorityType: authorityType,
          vehicleDescription: null, // Not available in this context
          vehicleRegistration: null,
          vehicleMake: null,
          vehicleModel: null,
        ));
      }

      return movements;
    } catch (e) {
      debugPrint('❌ Error getting pass movement history: $e');
      return [];
    }
  }

  /// Update border official assignment with direction permissions
  static Future<void> updateOfficialBorderAssignment({
    required String profileId,
    required String borderId,
    required bool canCheckIn,
    required bool canCheckOut,
  }) async {
    try {
      debugPrint('🔄 Updating border assignment for official: $profileId');

      await _supabase
          .from('border_official_borders')
          .update({
            'can_check_in': canCheckIn,
            'can_check_out': canCheckOut,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('profile_id', profileId)
          .eq('border_id', borderId)
          .eq('is_active', true);

      debugPrint('✅ Border assignment updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating border assignment: $e');
      rethrow;
    }
  }

  /// Assign official to border with direction permissions
  static Future<void> assignOfficialToBorderWithPermissions({
    required String profileId,
    required String borderId,
    bool canCheckIn = true,
    bool canCheckOut = true,
  }) async {
    try {
      debugPrint('🔄 Assigning official to border with permissions');

      // Use the enhanced function that handles both assignment and permissions
      await _supabase
          .rpc('assign_official_to_border_with_permissions', params: {
        'target_profile_id': profileId,
        'target_border_id': borderId,
        'can_check_in_param': canCheckIn,
        'can_check_out_param': canCheckOut,
      });

      debugPrint('✅ Official assigned with permissions successfully');
    } catch (e) {
      debugPrint('❌ Error assigning official with permissions: $e');
      rethrow;
    }
  }

  /// Get border assignments with direction permissions
  static Future<List<BorderAssignmentWithPermissions>>
      getBorderAssignmentsWithPermissions(
    String countryId,
  ) async {
    try {
      debugPrint(
          '🔍 Getting border assignments with permissions for country: $countryId');

      // Use a simpler approach to avoid relationship ambiguity
      final response = await _supabase
          .rpc('get_border_assignments_with_permissions', params: {
        'country_id_param': countryId,
      });

      debugPrint('✅ Retrieved ${response.length} border assignments');
      return (response as List)
          .map((item) => BorderAssignmentWithPermissions.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting border assignments: $e');
      // Fallback to a manual approach
      return _getBorderAssignmentsFallback(countryId);
    }
  }

  /// Get border assignments with direction permissions by authority
  static Future<List<BorderAssignmentWithPermissions>>
      getBorderAssignmentsWithPermissionsByAuthority(
    String authorityId,
  ) async {
    try {
      debugPrint(
          '🔍 Getting border assignments with permissions for authority: $authorityId');

      final response = await _supabase
          .rpc('get_border_assignments_with_permissions_by_authority', params: {
        'authority_id_param': authorityId,
      });

      debugPrint('✅ Retrieved ${response.length} border assignments');
      return (response as List)
          .map((item) => BorderAssignmentWithPermissions.fromJson(item))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting border assignments by authority: $e');
      rethrow;
    }
  }

  /// Fallback method to get border assignments manually
  static Future<List<BorderAssignmentWithPermissions>>
      _getBorderAssignmentsFallback(
    String countryId,
  ) async {
    try {
      debugPrint('🔄 Using fallback method for border assignments');

      // STEP 1: Get borders for the specific country first
      final bordersResponse = await _supabase
          .from('borders')
          .select('id, name, authority_id, authorities!inner(country_id)')
          .eq('authorities.country_id', countryId);

      if (bordersResponse.isEmpty) {
        debugPrint('⚠️ No borders found for country: $countryId');
        return [];
      }

      // Extract border IDs for this country
      final borderIds = bordersResponse.map((b) => b['id'] as String).toList();
      debugPrint(
          '🔍 Found ${borderIds.length} borders for country: $borderIds');

      // STEP 2: Get assignments ONLY for borders in this country
      final assignmentsResponse = await _supabase
          .from('border_official_borders')
          .select(
              'id, profile_id, border_id, can_check_in, can_check_out, assigned_at, is_active')
          .eq('is_active', true)
          .inFilter('border_id', borderIds); // This is the key fix!

      debugPrint(
          '🔍 Found ${assignmentsResponse.length} assignments for country borders');

      if (assignmentsResponse.isEmpty) {
        debugPrint('⚠️ No assignments found for country borders');
        return [];
      }

      // STEP 3: Get profiles for the assigned officials
      final profileIds =
          assignmentsResponse.map((a) => a['profile_id']).toSet().toList();
      final profilesResponse = await _supabase
          .from('profiles')
          .select('id, full_name, email')
          .inFilter('id', profileIds);

      // Create lookup maps
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profilesResponse) {
        profilesMap[profile['id']] = profile;
      }

      final bordersMap = <String, Map<String, dynamic>>{};
      for (final border in bordersResponse) {
        bordersMap[border['id']] = border;
      }

      // STEP 4: Combine the data (now properly filtered)
      final result = <BorderAssignmentWithPermissions>[];
      for (final assignment in assignmentsResponse) {
        final profile = profilesMap[assignment['profile_id']];
        final border = bordersMap[assignment['border_id']];

        if (profile != null && border != null) {
          result.add(BorderAssignmentWithPermissions(
            id: assignment['id'],
            profileId: assignment['profile_id'],
            borderId: assignment['border_id'],
            officialName: profile['full_name'] ?? 'Unknown',
            officialEmail: profile['email'] ?? 'Unknown',
            officialDisplayName: profile['full_name'] ??
                'Unknown', // Fallback doesn't have display names
            officialProfileImageUrl: profile['profile_image_url'],
            borderName: border['name'] ?? 'Unknown',
            canCheckIn: assignment['can_check_in'] ?? true,
            canCheckOut: assignment['can_check_out'] ?? true,
            assignedAt: DateTime.parse(assignment['assigned_at']),
          ));
        }
      }

      debugPrint(
          '✅ Fallback method retrieved ${result.length} properly filtered assignments');
      return result;
    } catch (e) {
      debugPrint('❌ Error in fallback method: $e');
      return [];
    }
  }

  /// Revoke a border official's access to a border
  static Future<void> revokeOfficialFromBorder(
    String profileId,
    String borderId,
  ) async {
    try {
      debugPrint('🔄 Revoking official from border: $profileId -> $borderId');

      await _supabase.rpc('revoke_official_from_border', params: {
        'target_profile_id': profileId,
        'target_border_id': borderId,
      });

      debugPrint('✅ Official revoked from border successfully');
    } catch (e) {
      debugPrint('❌ Error revoking official from border: $e');
      rethrow;
    }
  }

  /// Batch assign multiple borders with individual permissions
  static Future<void> batchAssignOfficialToBorders({
    required String profileId,
    required List<Map<String, dynamic>> borderAssignments,
  }) async {
    try {
      debugPrint(
          '🔄 Batch assigning official to ${borderAssignments.length} borders');

      for (final assignment in borderAssignments) {
        final borderId = assignment['borderId'] as String;
        final canCheckIn = assignment['canCheckIn'] as bool? ?? true;
        final canCheckOut = assignment['canCheckOut'] as bool? ?? true;

        // Validate permissions
        if (!canCheckIn && !canCheckOut) {
          throw Exception(
              'At least one permission must be granted for border: ${assignment['borderName']}');
        }

        // Check if assignment already exists
        final existingAssignments = await _supabase
            .from('border_official_borders')
            .select('id')
            .eq('profile_id', profileId)
            .eq('border_id', borderId)
            .eq('is_active', true);

        if (existingAssignments.isNotEmpty) {
          // Update existing assignment
          await updateOfficialBorderAssignment(
            profileId: profileId,
            borderId: borderId,
            canCheckIn: canCheckIn,
            canCheckOut: canCheckOut,
          );
          debugPrint('✅ Updated existing assignment for border: $borderId');
        } else {
          // Create new assignment
          await assignOfficialToBorderWithPermissions(
            profileId: profileId,
            borderId: borderId,
            canCheckIn: canCheckIn,
            canCheckOut: canCheckOut,
          );
          debugPrint('✅ Created new assignment for border: $borderId');
        }
      }

      debugPrint('✅ Batch assignment completed successfully');
    } catch (e) {
      debugPrint('❌ Error in batch assignment: $e');
      rethrow;
    }
  }

  /// Get enhanced border assignments with permissions for UI
  static Future<List<Map<String, dynamic>>> getEnhancedBorderAssignments({
    required String profileId,
    required String countryId,
  }) async {
    try {
      debugPrint(
          '🔍 Getting enhanced border assignments for official: $profileId');

      // Get all borders for the country
      final bordersResponse = await _supabase
          .from('borders')
          .select('''
            id,
            name,
            border_type_id,
            border_types(label),
            authorities!inner(country_id)
          ''')
          .eq('authorities.country_id', countryId)
          .eq('is_active', true)
          .order('name');

      // Get current assignments for this official
      final assignmentsResponse = await _supabase
          .from('border_official_borders')
          .select('border_id, can_check_in, can_check_out')
          .eq('profile_id', profileId)
          .eq('is_active', true);

      // Create assignment map for quick lookup
      final assignmentMap = <String, Map<String, dynamic>>{};
      for (final assignment in assignmentsResponse) {
        assignmentMap[assignment['border_id']] = {
          'canCheckIn': assignment['can_check_in'] ?? true,
          'canCheckOut': assignment['can_check_out'] ?? true,
        };
      }

      // Combine border data with assignment status
      final enhancedAssignments = <Map<String, dynamic>>[];
      for (final border in bordersResponse) {
        final borderId = border['id'] as String;
        final assignment = assignmentMap[borderId];

        enhancedAssignments.add({
          'borderId': borderId,
          'borderName': border['name'] as String,
          'borderType': border['border_types']['label'] as String,
          'isAssigned': assignment != null,
          'canCheckIn': assignment?['canCheckIn'] ?? true,
          'canCheckOut': assignment?['canCheckOut'] ?? true,
        });
      }

      debugPrint(
          '✅ Retrieved ${enhancedAssignments.length} enhanced border assignments');
      return enhancedAssignments;
    } catch (e) {
      debugPrint('❌ Error getting enhanced border assignments: $e');
      return [];
    }
  }

  /// Validate border assignment permissions
  static Map<String, String> validateBorderAssignments(
    List<Map<String, dynamic>> assignments,
  ) {
    final errors = <String, String>{};

    for (final assignment in assignments) {
      final borderName = assignment['borderName'] as String;
      final isAssigned = assignment['isAssigned'] as bool;
      final canCheckIn = assignment['canCheckIn'] as bool;
      final canCheckOut = assignment['canCheckOut'] as bool;

      if (isAssigned && !canCheckIn && !canCheckOut) {
        errors[borderName] =
            'At least one permission (check-in or check-out) must be selected';
      }
    }

    return errors;
  }

  /// Clear GPS cache (useful for testing or when location changes significantly)
  static void clearGPSCache() {
    _cachedPosition = null;
    _lastPositionUpdate = null;
    debugPrint('📍 GPS cache cleared');
  }
}

/// Result of pass movement processing
class PassMovementResult {
  final bool success;
  final String movementId;
  final String movementType;
  final String previousStatus;
  final String newStatus;
  final int entriesDeducted;
  final int entriesRemaining;
  final DateTime processedAt;

  PassMovementResult({
    required this.success,
    required this.movementId,
    required this.movementType,
    required this.previousStatus,
    required this.newStatus,
    required this.entriesDeducted,
    required this.entriesRemaining,
    required this.processedAt,
  });

  factory PassMovementResult.fromJson(Map<String, dynamic> json) {
    return PassMovementResult(
      success: json['success'] as bool? ?? false,
      movementId: json['movement_id'] as String? ?? '',
      movementType: json['movement_type'] as String? ?? 'unknown',
      previousStatus: json['previous_status'] as String? ?? '',
      newStatus: json['new_status'] as String? ?? '',
      entriesDeducted: json['entries_deducted'] as int? ?? 0,
      entriesRemaining: json['entries_remaining'] as int? ?? 0,
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : DateTime.now(),
    );
  }

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

/// Information about what action would be performed on a pass
class PassActionInfo {
  final String actionType;
  final String actionDescription;
  final String currentStatus;
  final bool willDeductEntry;
  final int entriesRemaining;
  final DateTime expiresAt;

  PassActionInfo({
    required this.actionType,
    required this.actionDescription,
    required this.currentStatus,
    required this.willDeductEntry,
    required this.entriesRemaining,
    required this.expiresAt,
  });

  bool get isCheckIn => actionType == 'check_in';
  bool get isCheckOut => actionType == 'check_out';
}

/// Pass movement history record
class PassMovement {
  final String movementId;
  final String? passId; // Add pass ID for fetching vehicle/owner details
  final String borderName;
  final String officialName;
  final String? officialProfileImageUrl;
  final String movementType;
  final double latitude;
  final double longitude;
  final DateTime processedAt;
  final int entriesDeducted;
  final String previousStatus;
  final String newStatus;
  final String? scanPurpose;
  final String? notes;
  final String? authorityType;
  final String? vehicleDescription;
  final String? vehicleRegistration;
  final String? vehicleMake;
  final String? vehicleModel;

  PassMovement({
    required this.movementId,
    this.passId,
    required this.borderName,
    required this.officialName,
    this.officialProfileImageUrl,
    required this.movementType,
    required this.latitude,
    required this.longitude,
    required this.processedAt,
    required this.entriesDeducted,
    required this.previousStatus,
    required this.newStatus,
    this.scanPurpose,
    this.notes,
    this.authorityType,
    this.vehicleDescription,
    this.vehicleRegistration,
    this.vehicleMake,
    this.vehicleModel,
  });

  factory PassMovement.fromJson(Map<String, dynamic> json) {
    return PassMovement(
      movementId: json['movement_id'] as String,
      passId: json['pass_id'] as String?,
      borderName: json['border_name'] as String? ?? 'Local Authority',
      officialName: json['official_name'] as String? ?? 'Unknown Official',
      officialProfileImageUrl: json['official_profile_image_url'] as String?,
      movementType: json['movement_type'] as String,
      latitude: _parseNumericToDouble(json['latitude']),
      longitude: _parseNumericToDouble(json['longitude']),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : DateTime.now(),
      entriesDeducted: json['entries_deducted'] as int? ?? 0,
      previousStatus: json['previous_status'] as String? ?? '',
      newStatus: json['new_status'] as String? ?? '',
      scanPurpose: json['scan_purpose'] as String?,
      notes: json['notes'] as String?,
      authorityType: json['authority_type'] as String?,
      vehicleDescription: json['vehicle_description'] as String?,
      vehicleRegistration: json['vehicle_registration'] as String?,
      vehicleMake: json['vehicle_make'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
    );
  }

  /// Helper method to safely parse numeric values to double
  static double _parseNumericToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    if (value is num) return value.toDouble();
    return 0.0;
  }

  factory PassMovement.fromAuditJson(Map<String, dynamic> json) {
    return PassMovement(
      movementId: json['id'] as String,
      passId: json['pass_id'] as String?,
      borderName: json['border_name'] as String? ?? 'Local Authority',
      officialName: json['official_name'] as String? ?? 'Unknown Official',
      officialProfileImageUrl: json['official_profile_image_url'] as String?,
      movementType: json['action_type'] as String,
      latitude: _parseNumericToDouble(json['latitude']),
      longitude: _parseNumericToDouble(json['longitude']),
      processedAt: json['performed_at'] != null
          ? DateTime.parse(json['performed_at'] as String)
          : DateTime.now(),
      entriesDeducted: json['entries_deducted'] as int? ?? 0,
      previousStatus: json['previous_status'] as String? ?? '',
      newStatus: json['new_status'] as String? ?? '',
      scanPurpose: json['scan_purpose'] as String?,
      notes: json['notes'] as String?,
      authorityType: json['authority_type'] as String?,
      vehicleDescription: json['vehicle_description'] as String?,
      vehicleRegistration: json['vehicle_registration'] as String?,
      vehicleMake: json['vehicle_make'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
    );
  }

  String get actionDescription {
    switch (movementType) {
      case 'check_in':
        return 'Checked-In';
      case 'check_out':
        return 'Checked-Out';
      case 'local_authority_scan':
        return scanPurpose != null
            ? _formatScanPurpose(scanPurpose!)
            : 'Authority Scan';
      default:
        return movementType
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  String _formatScanPurpose(String purpose) {
    switch (purpose) {
      case 'routine_check':
        return 'Routine Check';
      case 'roadblock':
        return 'Roadblock';
      case 'investigation':
        return 'Investigation';
      case 'compliance_audit':
        return 'Compliance Audit';
      default:
        return purpose
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  bool get isBorderMovement =>
      movementType == 'check_in' || movementType == 'check_out';
  bool get isLocalAuthorityScan => movementType == 'local_authority_scan';
}

/// Border assignment with direction permissions
class BorderAssignmentWithPermissions {
  final String id;
  final String profileId;
  final String borderId;
  final String officialName;
  final String officialEmail;
  final String officialDisplayName;
  final String? officialProfileImageUrl;
  final String borderName;
  final bool canCheckIn;
  final bool canCheckOut;
  final DateTime assignedAt;

  BorderAssignmentWithPermissions({
    required this.id,
    required this.profileId,
    required this.borderId,
    required this.officialName,
    required this.officialEmail,
    required this.officialDisplayName,
    this.officialProfileImageUrl,
    required this.borderName,
    required this.canCheckIn,
    required this.canCheckOut,
    required this.assignedAt,
  });

  factory BorderAssignmentWithPermissions.fromJson(Map<String, dynamic> json) {
    // Handle both the SQL function format (JSONB) and direct query format
    final profiles = json['profiles'];
    final borders = json['borders'];

    String officialName, officialEmail, officialDisplayName, borderName;
    String? officialProfileImageUrl;

    if (profiles is Map<String, dynamic>) {
      // Direct query format
      officialName = profiles['full_name'] as String? ?? 'Unknown';
      officialEmail = profiles['email'] as String? ?? 'Unknown';
      officialDisplayName = profiles['display_name'] as String? ?? officialName;
      officialProfileImageUrl = profiles['profile_image_url'] as String?;
    } else {
      // Enhanced function format with display names
      officialName = json['official_name'] as String? ?? 'Unknown';
      officialEmail = json['official_email'] as String? ?? 'Unknown';
      officialDisplayName =
          json['official_display_name'] as String? ?? officialName;
      officialProfileImageUrl = json['official_profile_image_url'] as String?;
    }

    if (borders is Map<String, dynamic>) {
      // Direct query format
      borderName = borders['name'] as String? ?? 'Unknown';
    } else {
      // Fallback for other formats
      borderName = json['border_name'] as String? ?? 'Unknown';
    }

    return BorderAssignmentWithPermissions(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      borderId: json['border_id'] as String,
      officialName: officialName,
      officialEmail: officialEmail,
      officialDisplayName: officialDisplayName,
      officialProfileImageUrl: officialProfileImageUrl,
      borderName: borderName,
      canCheckIn: json['can_check_in'] as bool? ?? true,
      canCheckOut: json['can_check_out'] as bool? ?? true,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
    );
  }

  String get permissionsDescription {
    if (canCheckIn && canCheckOut) {
      return 'Check-In & Check-Out';
    } else if (canCheckIn) {
      return 'Check-In Only';
    } else if (canCheckOut) {
      return 'Check-Out Only';
    } else {
      return 'No Permissions';
    }
  }
}
