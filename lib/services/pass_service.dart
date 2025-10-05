import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchased_pass.dart';
import '../models/authority.dart';
import '../models/pass_template.dart';

class PassService {
  static final _supabase = Supabase.instance.client;
  static RealtimeChannel? _passesChannel;

  /// Subscribe to realtime updates for purchased passes with focus on secure code updates
  static RealtimeChannel subscribeToPassUpdates({
    required Function(PurchasedPass, String) onPassChanged, // pass, eventType
    required Function(String) onError,
  }) {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      onError('User not authenticated');
      throw Exception('User not authenticated');
    }

    // Remove existing subscription if any
    if (_passesChannel != null) {
      _supabase.removeChannel(_passesChannel!);
    }

    debugPrint('🔄 Setting up real-time subscription for secure codes...');

    _passesChannel = _supabase
        .channel('purchased_passes_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'purchased_passes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'profile_id',
            value: user.id,
          ),
          callback: (payload) async {
            try {
              debugPrint('🔄 Real-time update received: ${payload.eventType}');

              // Extract records
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;

              // Handle specific change types
              switch (payload.eventType) {
                case PostgresChangeEvent.insert:
                  await _handleInsertUpdate(
                      newRecord, oldRecord, onPassChanged, 'INSERT');
                  break;

                case PostgresChangeEvent.update:
                  // This is the key one for secure code updates
                  await _handleInsertUpdate(
                      newRecord, oldRecord, onPassChanged, 'UPDATE');
                  break;

                case PostgresChangeEvent.delete:
                  if (oldRecord.isNotEmpty) {
                    final deletedPass = PurchasedPass(
                      passId: oldRecord['id'] ?? '',
                      vehicleDescription: 'Deleted Pass',
                      passDescription: 'Deleted Pass',
                      entryLimit: 0,
                      entriesRemaining: 0,
                      issuedAt: DateTime.now(),
                      activationDate: DateTime.now(),
                      expiresAt: DateTime.now(),
                      status: 'deleted',
                      currency: '',
                      amount: 0,
                      qrCode: null,
                      shortCode: '',
                    );
                    onPassChanged(deletedPass, 'DELETE');
                  }
                  break;

                default:
                  break;
              }
            } catch (e) {
              debugPrint('🔄 Error processing realtime update: $e');
              onError('Error processing realtime update: $e');
            }
          },
        )
        .subscribe((status, [error]) {
      debugPrint('🔄 Subscription status: $status');
      if (error != null) {
        debugPrint('🔄 Subscription error: $error');
        onError('Subscription error: $error');
      } else if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('🔄 Successfully subscribed to real-time updates');
      }
    });

    return _passesChannel!;
  }

  /// Handle insert and update events
  static Future<void> _handleInsertUpdate(
    Map<String, dynamic> newRecord,
    Map<String, dynamic> oldRecord,
    Function(PurchasedPass, String) onPassChanged,
    String eventType,
  ) async {
    final passId = (newRecord['id'] ?? oldRecord['id'])?.toString();
    if (passId == null) {
      debugPrint('🔄 No pass ID found in update');
      return;
    }

    debugPrint('🔄 Processing $eventType for pass: $passId');

    // Check if this is a secure code update
    final oldSecureCode = oldRecord['secure_code']?.toString();
    final newSecureCode = newRecord['secure_code']?.toString();

    if (oldSecureCode != newSecureCode) {
      debugPrint('🔄 Secure code changed: $oldSecureCode -> $newSecureCode');
    }

    // Try to get the full pass data with all joins
    try {
      final updatedPass = await getPassById(passId);
      if (updatedPass != null) {
        debugPrint(
            '🔄 Successfully fetched updated pass with secure code: ${updatedPass.secureCode}');
        onPassChanged(updatedPass, eventType);
        return;
      }
    } catch (e) {
      debugPrint('🔄 Failed to fetch pass by ID: $e');
    }

    // Fallback: create pass from the real-time payload data
    try {
      // Merge old and new records to get complete data
      final completeRecord = <String, dynamic>{};
      completeRecord.addAll(oldRecord);
      completeRecord.addAll(newRecord);

      debugPrint('🔄 Using fallback with merged record');
      debugPrint('🔄 Merged secure_code: ${completeRecord['secure_code']}');

      final pass = PurchasedPass.fromJson(completeRecord);
      onPassChanged(pass, eventType);
    } catch (e) {
      debugPrint('🔄 Failed to create pass from payload: $e');
    }
  }

  /// Unsubscribe from realtime updates
  static void unsubscribeFromPassUpdates() {
    if (_passesChannel != null) {
      _supabase.removeChannel(_passesChannel!);
      _passesChannel = null;
    }
  }

  /// Issues a new pass from a template with individual vehicle fields
  static Future<void> issuePassFromTemplate({
    String? vehicleId,
    required String passTemplateId,
    required DateTime activationDate,
    // New parameters for direct vehicle data capture
    String? vehicleDescription,
    String? vehicleNumberPlate,
    String? vehicleVin,
    // User-selected entry/exit points for templates that allow selection
    String? userSelectedEntryPointId,
    String? userSelectedExitPointId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get the pass template details with related data
      final templateResponse = await _supabase.from('pass_templates').select('''
            *,
            authorities(
              id,
              name,
              code,
              country_id,
              countries(name, country_code)
            )
          ''').eq('id', passTemplateId).eq('is_active', true).single();

      // Handle entry/exit points properly - keep null for "Any Entry/Exit Point"
      String? finalEntryPointId;
      String? finalExitPointId;
      Map<String, dynamic>? entryBorderData;
      Map<String, dynamic>? exitBorderData;

      // Handle entry point selection based on template settings
      if (userSelectedEntryPointId != null) {
        // User provided a specific entry point
        finalEntryPointId = userSelectedEntryPointId;
      } else if (templateResponse['allow_user_selectable_entry_point'] ==
          true) {
        // Template allows user selection but no point provided - keep null
        finalEntryPointId = null;
      } else if (templateResponse['entry_point_id'] != null) {
        // Template has a fixed entry point
        finalEntryPointId = templateResponse['entry_point_id'];
      }
      // If all conditions fail, keep finalEntryPointId as null (Any Entry Point)

      // Handle exit point selection based on template settings
      if (userSelectedExitPointId != null) {
        // User provided a specific exit point
        finalExitPointId = userSelectedExitPointId;
      } else if (templateResponse['allow_user_selectable_exit_point'] == true) {
        // Template allows user selection but no point provided - keep null
        finalExitPointId = null;
      } else if (templateResponse['exit_point_id'] != null) {
        // Template has a fixed exit point
        finalExitPointId = templateResponse['exit_point_id'];
      }
      // If all conditions fail, keep finalExitPointId as null (Any Exit Point)

      // Get border names only if we have specific border IDs
      if (finalEntryPointId != null) {
        try {
          entryBorderData = await _supabase
              .from('borders')
              .select('name')
              .eq('id', finalEntryPointId)
              .single();
          debugPrint('📍 Entry point: ${entryBorderData?['name']}');
        } catch (e) {
          debugPrint('Could not fetch entry border data: $e');
        }
      } else {
        debugPrint('📍 Entry point: Any Entry Point (null)');
      }

      if (finalExitPointId != null) {
        try {
          exitBorderData = await _supabase
              .from('borders')
              .select('name')
              .eq('id', finalExitPointId)
              .single();
          debugPrint('📍 Exit point: ${exitBorderData?['name']}');
        } catch (e) {
          debugPrint('Could not fetch exit border data: $e');
        }
      } else {
        debugPrint('📍 Exit point: Any Exit Point (null)');
      }

      // Generate pass verification data
      final now = DateTime.now();
      final passHash =
          PurchasedPass.generateShortCode(now.millisecondsSinceEpoch.toString())
              .replaceAll('-', '');
      final shortCode = PurchasedPass.generateShortCode(
          now.millisecondsSinceEpoch.toString());

      // Calculate expiration date
      final expirationDate = activationDate
          .add(Duration(days: templateResponse['expiration_days']));

      // Extract related data from template response first (needed for QR data)
      final authorityData =
          templateResponse['authorities'] as Map<String, dynamic>?;
      // borderData is now fetched separately above
      final countryData = authorityData?['countries'] as Map<String, dynamic>?;

      // Determine vehicle data to store
      String? finalVehicleDescription = vehicleDescription;
      String? finalVehicleNumberPlate = vehicleNumberPlate;
      String? finalVehicleVin = vehicleVin;
      String? finalVehicleMake;
      String? finalVehicleModel;
      int? finalVehicleYear;
      String? finalVehicleColor;

      // If vehicle data not provided but vehicleId is, fetch from vehicles table
      if (vehicleId != null &&
          (finalVehicleDescription == null &&
              finalVehicleNumberPlate == null &&
              finalVehicleVin == null)) {
        try {
          // Try to fetch vehicle details with fallback for missing columns
          final vehicleResponse = await _supabase
              .from('vehicles')
              .select(
                  '*') // Select all columns to avoid column not found errors
              .eq('id', vehicleId)
              .single();

          finalVehicleDescription = vehicleResponse['description']?.toString();

          // Prioritize registration_number over number_plate (legacy)
          finalVehicleNumberPlate =
              vehicleResponse['registration_number']?.toString() ??
                  vehicleResponse['number_plate']?.toString();

          // Handle vin with fallback (column is called 'vin', not 'vin_number')
          finalVehicleVin = vehicleResponse['vin']?.toString();

          // Capture all vehicle details
          finalVehicleMake = vehicleResponse['make']?.toString();
          finalVehicleModel = vehicleResponse['model']?.toString();
          finalVehicleYear = vehicleResponse['year'] != null
              ? int.tryParse(vehicleResponse['year'].toString())
              : null;
          finalVehicleColor = vehicleResponse['color']?.toString();

          // Build enhanced vehicle description if we have make/model
          if (finalVehicleMake != null && finalVehicleModel != null) {
            finalVehicleDescription = finalVehicleYear != null
                ? '$finalVehicleMake $finalVehicleModel ($finalVehicleYear)'
                : '$finalVehicleMake $finalVehicleModel';
          }

          debugPrint('🚗 Vehicle details fetched:');
          debugPrint('   Description: $finalVehicleDescription');
          debugPrint('   Registration: $finalVehicleNumberPlate');
          debugPrint('   VIN: $finalVehicleVin');
          debugPrint('   Make: $finalVehicleMake');
          debugPrint('   Model: $finalVehicleModel');
          debugPrint('   Year: $finalVehicleYear');
          debugPrint('   Color: $finalVehicleColor');
        } catch (e) {
          debugPrint('Error fetching vehicle details: $e');
          // Continue without vehicle data - pass will be general
        }
      }

      // Create comprehensive QR data with all required fields
      final qrData = {
        // Core pass identification
        'profile_id': user.id,
        'pass_hash': passHash,
        'short_code': shortCode,

        // Dates
        'issued_at': DateTime(now.year, now.month, now.day).toIso8601String(),
        'activation_date': DateTime(
                activationDate.year, activationDate.month, activationDate.day)
            .toIso8601String(),
        'expires_at': DateTime(
                expirationDate.year, expirationDate.month, expirationDate.day)
            .toIso8601String(),

        // Authority and location data
        'authority_id': templateResponse['authority_id'],
        'authority_name': authorityData?['name'] ?? '',
        'entry_point_id': finalEntryPointId,
        'exit_point_id': finalExitPointId,
        'entry_point_name': entryBorderData?['name'] ?? 'Any Entry Point',
        'exit_point_name': exitBorderData?['name'] ?? 'Any Exit Point',
        'country_id': countryData?['id'] ?? templateResponse['country_id'],
        'country_name': countryData?['name'] ?? '',

        // Pass details
        'pass_description': _buildPassDescription(
          templateResponse,
          authorityData,
          entryBorderData,
          exitBorderData,
          countryData,
          finalVehicleDescription,
          finalVehicleNumberPlate,
          finalVehicleVin,
          activationDate,
        ),
        'entry_limit': templateResponse['entry_limit'],
        'currency': templateResponse['currency_code'] ?? 'USD',
        'amount': templateResponse['tax_amount'],

        // Vehicle information
        'vehicle_description': finalVehicleDescription ?? '',
        'vehicle_registration_number': finalVehicleNumberPlate ?? '',
        'vehicle_vin': finalVehicleVin ?? '',
        'vehicle_make': finalVehicleMake ?? '',
        'vehicle_model': finalVehicleModel ?? '',
        'vehicle_year': finalVehicleYear,
        'vehicle_color': finalVehicleColor ?? '',
      };

      // First insert the pass without QR data to get the actual database ID
      final insertData = {
        'profile_id': user.id,
        'pass_template_id': passTemplateId,
        'vehicle_id': vehicleId, // Can be null for general passes
        'issued_at': now.toIso8601String(),
        'activation_date': DateTime(
                activationDate.year, activationDate.month, activationDate.day)
            .toIso8601String(),
        'expires_at': DateTime(
                expirationDate.year, expirationDate.month, expirationDate.day)
            .toIso8601String(),
        'entry_limit': templateResponse['entry_limit'],
        'entries_remaining': templateResponse['entry_limit'],
        'status': 'active',
        'currency': templateResponse['currency_code'] ?? 'USD',
        'amount': templateResponse['tax_amount'],
        'pass_hash': passHash,
        'short_code': shortCode,
        'pass_description': _buildPassDescription(
          templateResponse,
          authorityData,
          entryBorderData,
          exitBorderData,
          countryData,
          finalVehicleDescription,
          finalVehicleNumberPlate,
          finalVehicleVin,
          activationDate,
        ),
        'authority_id': templateResponse['authority_id'],
        'country_id': countryData?['id'] ?? templateResponse['country_id'],
        'entry_point_id': finalEntryPointId,
        'exit_point_id': finalExitPointId,

        // Individual vehicle fields
        'vehicle_description': finalVehicleDescription,
        'vehicle_registration_number': finalVehicleNumberPlate,
        'vehicle_vin': finalVehicleVin,
        'vehicle_make': finalVehicleMake,
        'vehicle_model': finalVehicleModel,
        'vehicle_year': finalVehicleYear,
        'vehicle_color': finalVehicleColor,

        // Store denormalized data for faster queries (columns will be added by migration)
        'authority_name': authorityData?['name'],
        'country_name': countryData?['name'],
        'entry_point_name': entryBorderData?['name'] ?? 'Any Entry Point',
        'exit_point_name': exitBorderData?['name'] ?? 'Any Exit Point',
      };

      // Insert the pass and get the generated ID
      dynamic insertResult;
      try {
        insertResult = await _supabase
            .from('purchased_passes')
            .insert(insertData)
            .select('id')
            .single();
      } catch (e) {
        // If insert fails due to missing columns, try without denormalized fields
        if (e.toString().contains('column') &&
            e.toString().contains('does not exist')) {
          debugPrint(
              '⚠️ Denormalized columns not found, inserting without them: $e');
          final basicInsertData = Map<String, dynamic>.from(insertData);
          basicInsertData.remove('authority_name');
          basicInsertData.remove('country_name');
          basicInsertData.remove('entry_point_name');
          basicInsertData.remove('exit_point_name');

          insertResult = await _supabase
              .from('purchased_passes')
              .insert(basicInsertData)
              .select('id')
              .single();
        } else {
          rethrow;
        }
      }

      final actualPassId = insertResult['id'].toString();

      // Create comprehensive QR data with all required fields including the actual pass ID
      /*
      final qrData = {
        // Core pass identification
        'id': actualPassId,
        'profile_id': user.id,
        'pass_hash': passHash,
        'short_code': shortCode,

        // Dates
        'issued_at': DateTime(now.year, now.month, now.day).toIso8601String(),
        'activation_date': DateTime(
                activationDate.year, activationDate.month, activationDate.day)
            .toIso8601String(),
        'expires_at': DateTime(
                expirationDate.year, expirationDate.month, expirationDate.day)
            .toIso8601String(),

        // Authority and location data
        'authority_id': templateResponse['authority_id'],
        'authority_name': authorityData?['name'] ?? '',
        'entry_point_id': userSelectedEntryPointId ?? templateResponse['entry_point_id'],
        'exit_point_id': userSelectedExitPointId ?? templateResponse['exit_point_id'],
        'entry_point_name': entryBorderData?['name'] ?? '',
        'exit_point_name': exitBorderData?['name'] ?? '',
        'country_id': countryData?['id'] ?? templateResponse['country_id'],
        'country_name': countryData?['name'] ?? '',

        // Pass details
        'pass_description': templateResponse['description'] ?? 'Border Pass',
        'entry_limit': templateResponse['entry_limit'],
        'currency': templateResponse['currency_code'] ?? 'USD',
        'amount': templateResponse['tax_amount'],

        // Vehicle information
        'vehicle_description': finalVehicleDescription ?? '',
        'vehicle_registration_number': finalVehicleNumberPlate ?? '',
        'vehicle_vin': finalVehicleVin ?? '',
        'vehicle_make': finalVehicleMake ?? '',
        'vehicle_model': finalVehicleModel ?? '',
        'vehicle_year': finalVehicleYear,
        'vehicle_color': finalVehicleColor ?? '',
      };
      */

      // Update the pass with the comprehensive QR data
      await _supabase
          .from('purchased_passes')
          .update({'qr_data': qrData}).eq('id', actualPassId);
    } catch (e) {
      // Provide more specific error messages for common database issues
      if (e.toString().contains('vehicle_record is not assigned') ||
          e.toString().contains('tuple structure')) {
        throw Exception(
            'Database error: Unable to process pass without vehicle assignment. Please select a vehicle or contact support.');
      } else if (e.toString().contains('qr_data is ambiguous') ||
          e.toString().contains('column reference')) {
        throw Exception(
            'Database configuration error: Column reference conflict. Please contact support.');
      } else if (e.toString().contains('could not find')) {
        throw Exception(
            'Database function not available. Using direct database operations.');
      } else if (e.toString().contains('column') &&
          e.toString().contains('does not exist')) {
        throw Exception(
            'Database schema error: Required table or column missing. Please contact support.');
      } else {
        throw Exception('Failed to issue pass: ${e.toString()}');
      }
    }
  }

  /// Gets all passes for the current user
  static Future<List<PurchasedPass>> getPassesForUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Temporarily disable RPC function to avoid hanging issues
    debugPrint('🔍 Skipping RPC function, using direct query for reliability');
    debugPrint('🔍 User ID: ${user.id}');

    // Direct database query with timeout
    try {
      debugPrint('🔍 Starting direct database query for passes');
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
              entry_point_id,
              exit_point_id,
              is_active,
              entry_borders:borders!pass_templates_entry_point_id_fkey(name),
              exit_borders:borders!pass_templates_exit_point_id_fkey(name)
            ),
            authorities(
              id,
              name,
              code,
              country_id,
              countries(name, country_code)
            )
          ''')
          .eq('profile_id', user.id)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 30));

      final List<dynamic> data = response as List<dynamic>;
      debugPrint('🔍 Fallback query returned ${data.length} passes');

      // Debug: Check if any passes have secure codes
      for (var json in data) {
        if (json['secure_code'] != null) {
          debugPrint(
              '📋 Found secure code in fallback data: ${json['secure_code']} expires: ${json['secure_code_expires_at']}');
        }
      }

      // Process passes sequentially to handle async authority fetching
      final List<PurchasedPass> passes = [];

      for (final json in data) {
        final passData = json as Map<String, dynamic>;

        debugPrint('🔍 Processing pass: ${passData['id']}');
        debugPrint('🔍 Authority data: ${passData['authorities']}');
        debugPrint('🔍 Authority ID: ${passData['authority_id']}');

        // Flatten pass_templates data into the main object
        if (passData['pass_templates'] != null) {
          final template = passData['pass_templates'] as Map<String, dynamic>;
          debugPrint('🔍 Template data: $template');

          passData['entry_limit'] = template['entry_limit'];
          passData['amount'] =
              template['tax_amount']; // tax_amount maps to amount
          passData['currency'] =
              template['currency_code']; // currency_code maps to currency

          debugPrint(
              '🔍 After flattening - entry_limit: ${passData['entry_limit']}, amount: ${passData['amount']}, currency: ${passData['currency']}');

          // Flatten border information if available
          if (template['entry_borders'] != null) {
            final entryBorder =
                template['entry_borders'] as Map<String, dynamic>;
            passData['entry_point_name'] = entryBorder['name'];
            debugPrint('🔍 Entry point name: ${passData['entry_point_name']}');
          }

          if (template['exit_borders'] != null) {
            final exitBorder = template['exit_borders'] as Map<String, dynamic>;
            passData['exit_point_name'] = exitBorder['name'];
            debugPrint('🔍 Exit point name: ${passData['exit_point_name']}');
          }

          // Legacy border name support
          if (template['borders'] != null) {
            final border = template['borders'] as Map<String, dynamic>;
            passData['border_name'] = border['name'];
            debugPrint('🔍 Border name: ${passData['border_name']}');
          }
        } else {
          debugPrint('⚠️ No pass_templates data found in response');
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
        } else {
          // Handle missing authority data - try to fetch it separately if authority_id exists
          final authorityId = passData['authority_id']?.toString();
          if (authorityId != null && authorityId.isNotEmpty) {
            debugPrint(
                '⚠️ Authority data missing for pass, attempting to fetch authority: $authorityId');
            try {
              final authorityResponse = await _supabase
                  .from('authorities')
                  .select('id, name, countries(name)')
                  .eq('id', authorityId)
                  .maybeSingle();

              if (authorityResponse != null) {
                passData['authority_name'] = authorityResponse['name'];
                if (authorityResponse['countries'] != null) {
                  final country =
                      authorityResponse['countries'] as Map<String, dynamic>;
                  passData['country_name'] = country['name'];
                }
                debugPrint(
                    '✅ Successfully fetched authority data: ${authorityResponse['name']}');
              } else {
                debugPrint('⚠️ Authority not found in database: $authorityId');
                passData['authority_name'] = 'Unknown Authority';
                passData['country_name'] = 'Unknown Country';
              }
            } catch (e) {
              debugPrint('❌ Failed to fetch authority data: $e');
              passData['authority_name'] = 'Unknown Authority';
              passData['country_name'] = 'Unknown Country';
            }
          } else {
            debugPrint('⚠️ No authority_id found for pass');
            passData['authority_name'] = 'Unknown Authority';
            passData['country_name'] = 'Unknown Country';
          }
        }

        debugPrint(
            '🔍 Final flattened data - entry_limit: ${passData['entry_limit']}, amount: ${passData['amount']}');
        passes.add(PurchasedPass.fromJson(passData));
      }

      return passes;
    } catch (e) {
      debugPrint('❌ Database query failed: $e');
      if (e.toString().contains('timeout') ||
          e.toString().contains('TimeoutException')) {
        throw Exception(
            'Request timed out. Please check your internet connection and try again.');
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        throw Exception(
            'Network error. Please check your internet connection.');
      } else {
        throw Exception('Failed to load passes: ${e.toString()}');
      }
    }
  }

  /// Validates a pass by QR code data
  static Future<PurchasedPass?> validatePassByQRCode(String qrData) async {
    try {
      debugPrint('🔍 Validating pass by QR code: ${qrData.length} characters');

      // Call the verify_pass function with QR code
      final response = await _supabase.rpc('verify_pass', params: {
        'verification_code': qrData,
        'is_qr_code': true,
      });

      if (response == null || (response is List && response.isEmpty)) {
        debugPrint('❌ No pass found for QR code');
        return null;
      }

      Map<String, dynamic> passData;
      if (response is List && response.isNotEmpty) {
        passData = response.first as Map<String, dynamic>;
      } else if (response is Map<String, dynamic>) {
        passData = response;
      } else {
        debugPrint('❌ Unexpected response format from verify_pass');
        return null;
      }

      final pass = PurchasedPass.fromJson(passData);
      debugPrint('✅ Pass validated successfully: ${pass.passId}');
      return pass;
    } catch (e) {
      debugPrint('❌ Error validating pass by QR code: $e');
      return null;
    }
  }

  /// Validates a pass by backup code
  static Future<PurchasedPass?> validatePassByBackupCode(
      String backupCode) async {
    try {
      debugPrint('🔍 Validating pass by backup code: $backupCode');

      // Call the verify_pass function with backup code
      final response = await _supabase.rpc('verify_pass', params: {
        'verification_code': backupCode,
        'is_qr_code': false,
      });

      if (response == null || (response is List && response.isEmpty)) {
        debugPrint('❌ No pass found for backup code: $backupCode');
        return null;
      }

      Map<String, dynamic> passData;
      if (response is List && response.isNotEmpty) {
        passData = response.first as Map<String, dynamic>;
      } else if (response is Map<String, dynamic>) {
        passData = response;
      } else {
        debugPrint('❌ Unexpected response format from verify_pass');
        return null;
      }

      final pass = PurchasedPass.fromJson(passData);
      debugPrint('✅ Pass validated successfully: ${pass.passId}');
      return pass;
    } catch (e) {
      debugPrint('❌ Error validating pass by backup code: $e');
      return null;
    }
  }

  /// Gets a pass by its ID
  static Future<PurchasedPass?> getPassById(String passId) async {
    try {
      debugPrint('🔍 Getting pass by ID: $passId');

      final response = await _supabase.from('purchased_passes').select('''
            *,
            pass_templates(
              id,
              description,
              entry_limit,
              expiration_days,
              tax_amount,
              currency_code,
              authority_id,
              entry_point_id,
              exit_point_id,
              is_active
            ),
            authorities(
              id,
              name,
              code,
              country_id,
              countries(name, country_code)
            )
          ''').eq('id', passId).maybeSingle();

      if (response == null) {
        debugPrint('❌ No pass found with ID: $passId');
        return null;
      }

      // Flatten the data similar to getPassesForUser
      final passData = response as Map<String, dynamic>;

      // Flatten pass_templates data
      if (passData['pass_templates'] != null) {
        final template = passData['pass_templates'] as Map<String, dynamic>;
        passData['entry_limit'] = template['entry_limit'];
        passData['amount'] = template['tax_amount'];
        passData['currency'] = template['currency_code'];
      }

      // Flatten authorities data
      if (passData['authorities'] != null) {
        final authority = passData['authorities'] as Map<String, dynamic>;
        passData['authority_name'] = authority['name'];

        if (authority['countries'] != null) {
          final country = authority['countries'] as Map<String, dynamic>;
          passData['country_name'] = country['name'];
        }
      }

      final pass = PurchasedPass.fromJson(passData);
      debugPrint('✅ Pass retrieved successfully: ${pass.passId}');
      return pass;
    } catch (e) {
      debugPrint('❌ Error getting pass by ID: $e');
      return null;
    }
  }

  /// Gets active authorities for pass template selection
  static Future<List<Authority>> getActiveAuthorities() async {
    final response = await _supabase
        .from('authorities')
        .select('*, countries!inner(*)')
        .eq('is_active', true)
        .eq('countries.is_active', true)
        .eq('countries.is_global', false) // Exclude global countries
        .order('name');

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) => Authority.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Gets pass templates for a specific authority
  static Future<List<PassTemplate>> getPassTemplatesForAuthority(
      String authorityId) async {
    try {
      debugPrint('🔍 Fetching pass templates for authority: $authorityId');

      // Use the RPC function that properly joins with borders and vehicle types
      final response =
          await _supabase.rpc('get_pass_templates_for_authority', params: {
        'target_authority_id': authorityId,
      });

      if (response == null) return [];

      final List<dynamic> data = response as List<dynamic>;
      debugPrint('✅ Fetched ${data.length} pass templates with border names');

      // Fetch authority name for the templates
      String? authorityName;
      try {
        final authorityResponse = await _supabase
            .from('authorities')
            .select('name')
            .eq('id', authorityId)
            .maybeSingle();
        authorityName = authorityResponse?['name'];
      } catch (e) {
        debugPrint('⚠️ Could not fetch authority name: $e');
      }

      // Extract vehicle type IDs from the response
      final vehicleTypeIds = data
          .where((template) => template['vehicle_type_id'] != null)
          .map((template) => template['vehicle_type_id'])
          .toSet()
          .toList();

      Map<String, String> vehicleTypeNames = {};
      if (vehicleTypeIds.isNotEmpty) {
        try {
          // Try different possible column names for vehicle types
          dynamic vehicleTypesResponse;
          try {
            vehicleTypesResponse = await _supabase
                .from('vehicle_types')
                .select('id, name')
                .inFilter('id', vehicleTypeIds);
          } catch (nameError) {
            debugPrint(
                '⚠️ "name" column not found, trying "type_name": $nameError');
            try {
              vehicleTypesResponse = await _supabase
                  .from('vehicle_types')
                  .select('id, type_name')
                  .inFilter('id', vehicleTypeIds);
            } catch (typeNameError) {
              debugPrint(
                  '⚠️ "type_name" column not found, trying "label": $typeNameError');
              vehicleTypesResponse = await _supabase
                  .from('vehicle_types')
                  .select('id, label')
                  .inFilter('id', vehicleTypeIds);
            }
          }

          for (final vt in vehicleTypesResponse) {
            // Try different possible column names
            final typeName =
                vt['name'] ?? vt['type_name'] ?? vt['label'] ?? 'Unknown Type';
            vehicleTypeNames[vt['id']] = typeName;
          }
          debugPrint('✅ Fetched ${vehicleTypeNames.length} vehicle type names');
        } catch (e) {
          debugPrint('⚠️ Could not fetch vehicle types: $e');
        }
      }

      return response.map<PassTemplate>((json) {
        final templateData = Map<String, dynamic>.from(json);

        // Add authority ID and name since RPC function doesn't include them
        templateData['authority_id'] = authorityId;
        if (authorityName != null) {
          templateData['authority_name'] = authorityName;
        }

        // The RPC function already includes border names

        // Add vehicle type name if available
        if (templateData['vehicle_type_id'] != null) {
          final vehicleTypeName =
              vehicleTypeNames[templateData['vehicle_type_id']];
          if (vehicleTypeName != null) {
            templateData['vehicle_type'] = vehicleTypeName;
          }
        }

        // Keep entry/exit point names even for user-selectable templates
        // The UI will handle showing them appropriately based on user selection

        debugPrint(
            '🔍 Template: ${templateData['description']} - Authority: ${templateData['authority_name']}');

        return PassTemplate.fromJson(templateData);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching pass templates for authority: $e');

      // Fallback to RPC function if direct query fails
      try {
        debugPrint('🔄 Falling back to RPC function...');
        final response =
            await _supabase.rpc('get_pass_templates_for_authority', params: {
          'target_authority_id': authorityId,
        });

        if (response == null) return [];

        final List<dynamic> data = response as List<dynamic>;

        // Fetch authority name separately for the fallback
        String? authorityName;
        try {
          final authorityResponse = await _supabase
              .from('authorities')
              .select('name')
              .eq('id', authorityId)
              .maybeSingle();
          authorityName = authorityResponse?['name'];
        } catch (e) {
          debugPrint('⚠️ Could not fetch authority name: $e');
        }

        // Also try to fetch vehicle type names for fallback
        final vehicleTypeIds = data
            .where((template) => template['vehicle_type_id'] != null)
            .map((template) => template['vehicle_type_id'])
            .toSet()
            .toList();

        Map<String, String> vehicleTypeNames = {};
        if (vehicleTypeIds.isNotEmpty) {
          try {
            // Try different possible column names for vehicle types
            dynamic vehicleTypesResponse;
            try {
              vehicleTypesResponse = await _supabase
                  .from('vehicle_types')
                  .select('id, name')
                  .inFilter('id', vehicleTypeIds);
            } catch (nameError) {
              try {
                vehicleTypesResponse = await _supabase
                    .from('vehicle_types')
                    .select('id, type_name')
                    .inFilter('id', vehicleTypeIds);
              } catch (typeNameError) {
                vehicleTypesResponse = await _supabase
                    .from('vehicle_types')
                    .select('id, label')
                    .inFilter('id', vehicleTypeIds);
              }
            }

            for (final vt in vehicleTypesResponse) {
              final typeName = vt['name'] ??
                  vt['type_name'] ??
                  vt['label'] ??
                  'Unknown Type';
              vehicleTypeNames[vt['id']] = typeName;
            }
          } catch (e) {
            debugPrint('⚠️ Could not fetch vehicle types in fallback: $e');
          }
        }

        return data.map((json) {
          final jsonWithAuthority =
              Map<String, dynamic>.from(json as Map<String, dynamic>);
          jsonWithAuthority['authority_id'] = authorityId;
          jsonWithAuthority['authority_name'] =
              authorityName ?? 'Unknown Authority';

          // Add vehicle type name if available
          if (jsonWithAuthority['vehicle_type_id'] != null) {
            final vehicleTypeName =
                vehicleTypeNames[jsonWithAuthority['vehicle_type_id']];
            if (vehicleTypeName != null) {
              jsonWithAuthority['vehicle_type'] = vehicleTypeName;
            }
          }

          return PassTemplate.fromJson(jsonWithAuthority);
        }).toList();
      } catch (rpcError) {
        debugPrint('❌ RPC fallback also failed: $rpcError');
        return [];
      }
    }
  }

  // =====================================================
  // BRIDGE METHODS FOR BACKWARD COMPATIBILITY
  // =====================================================
  // These methods maintain compatibility with existing UI
  // while transitioning to authority-centric model

  /// Gets active countries for pass template selection (BRIDGE METHOD)
  /// This converts authorities back to country format for existing UI
  static Future<List<Map<String, dynamic>>> getActiveCountries() async {
    final authorities = await PassService.getActiveAuthorities();

    // Group authorities by country and return unique countries
    final Map<String, Map<String, dynamic>> countryMap = {};

    for (final authority in authorities) {
      // Skip authorities without proper country data
      if (authority.countryName == null || authority.countryName!.isEmpty) {
        continue;
      }

      countryMap[authority.countryId] = {
        'id': authority.countryId,
        'name': authority.countryName,
        'country_code': authority.countryCode ?? '',
        'is_active': true,
      };
    }

    return countryMap.values.toList();
  }

  /// Gets borders for an authority (for user-selectable entry/exit points)
  static Future<List<Map<String, dynamic>>> getBordersForAuthority(
      String authorityId) async {
    try {
      // Try using the RPC function first
      final response =
          await _supabase.rpc('get_borders_for_authority', params: {
        'target_authority_id': authorityId,
      });

      if (response == null) return [];

      return (response as List)
          .map((item) => {
                'border_id': item['border_id'],
                'border_name': item['border_name'],
                'border_type': item['border_type'] ?? '',
              })
          .toList();
    } catch (e) {
      debugPrint('RPC function failed, trying direct query: $e');

      // Fallback to direct table query if RPC function doesn't exist
      try {
        final response = await _supabase
            .from('borders')
            .select('id, name, border_type_id')
            .eq('authority_id', authorityId)
            .eq('is_active', true)
            .order('name');

        return (response as List)
            .map((item) => {
                  'border_id': item['id'],
                  'border_name': item['name'],
                  'border_type':
                      item['border_type_id']?.toString() ?? 'Unknown',
                })
            .toList();
      } catch (fallbackError) {
        throw Exception('Failed to get borders for authority: $fallbackError');
      }
    }
  }

  /// Gets pass templates for a specific country (BRIDGE METHOD)
  /// This finds all authorities for the country and returns their templates
  static Future<List<PassTemplate>> getPassTemplatesForCountry(
      String countryId) async {
    // Get all authorities for this country
    final authorities = await PassService.getActiveAuthorities();
    final countryAuthorities =
        authorities.where((auth) => auth.countryId == countryId).toList();

    // Get templates from all authorities in this country
    final List<PassTemplate> allTemplates = [];
    for (final authority in countryAuthorities) {
      final templates =
          await PassService.getPassTemplatesForAuthority(authority.id);
      allTemplates.addAll(templates);
    }

    return allTemplates;
  }

  /// Deduct an entry from a pass
  static Future<bool> deductEntry(String passId) async {
    try {
      debugPrint('Starting entry deduction for pass: $passId');

      // Get current pass
      final currentPass = await _supabase
          .from('purchased_passes')
          .select('entries_remaining')
          .eq('id', passId)
          .single();

      final currentEntries = currentPass['entries_remaining'] as int;
      debugPrint('Current entries: $currentEntries');

      if (currentEntries <= 0) {
        debugPrint('No entries remaining');
        throw Exception('No entries remaining');
      }

      // Deduct one entry and clear secure code fields to prevent reuse
      debugPrint('Updating pass with new entry count: ${currentEntries - 1}');
      await _supabase.from('purchased_passes').update({
        'entries_remaining': currentEntries - 1,
        'secure_code': null,
        'secure_code_expires_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', passId);

      debugPrint('Entry deduction successful');

      // Try to log the entry deduction (optional - don't fail if this fails)
      try {
        await _supabase.from('pass_usage_logs').insert({
          'pass_id': passId,
          'action': 'entry_deducted',
          'performed_by': _supabase.auth.currentUser?.id,
          'performed_at': DateTime.now().toIso8601String(),
          'details': {'entries_remaining': currentEntries - 1},
        });
        debugPrint('Usage log created successfully');
      } catch (logError) {
        debugPrint(
            'Warning: Could not create usage log (this is optional): $logError');
        // Don't fail the entire operation if logging fails
      }

      return true;
    } catch (e) {
      debugPrint('Error deducting entry: $e');
      return false;
    }
  }

  /// Build a clean, comprehensive pass description for auditing purposes
  static String _buildPassDescription(
    Map<String, dynamic> templateResponse,
    Map<String, dynamic>? authorityData,
    Map<String, dynamic>? entryBorderData,
    Map<String, dynamic>? exitBorderData,
    Map<String, dynamic>? countryData,
    String? vehicleDescription,
    String? vehicleNumberPlate,
    String? vehicleVin,
    DateTime activationDate,
  ) {
    final List<String> descriptionParts = [];

    // Add authority information
    final authorityName = authorityData?['name']?.toString();
    if (authorityName != null && authorityName.isNotEmpty) {
      descriptionParts.add('Authority: $authorityName');
    }

    // Add country information
    final countryName = countryData?['name']?.toString();
    if (countryName != null && countryName.isNotEmpty) {
      descriptionParts.add('Country: $countryName');
    }

    // Add border information if available
    final entryBorderName = entryBorderData?['name']?.toString();
    final exitBorderName = exitBorderData?['name']?.toString();

    if (entryBorderName != null && entryBorderName.isNotEmpty) {
      descriptionParts.add('Entry: $entryBorderName');
    }

    if (exitBorderName != null && exitBorderName.isNotEmpty) {
      descriptionParts.add('Exit: $exitBorderName');
    }

    // Add activation date
    final activationDateStr =
        '${activationDate.day}/${activationDate.month}/${activationDate.year}';
    descriptionParts.add('Activates: $activationDateStr');

    // Add vehicle information if this is a vehicle-specific pass
    if (vehicleDescription != null && vehicleDescription.isNotEmpty) {
      descriptionParts.add('Vehicle: $vehicleDescription');
    }

    if (vehicleNumberPlate != null && vehicleNumberPlate.isNotEmpty) {
      descriptionParts.add('Plate: $vehicleNumberPlate');
    }

    if (vehicleVin != null && vehicleVin.isNotEmpty) {
      descriptionParts.add('VIN: $vehicleVin');
    }

    // Add entry limit information
    final entryLimit = templateResponse['entry_limit'];
    if (entryLimit != null) {
      final limitText = entryLimit == 1 ? '1 Entry' : '$entryLimit Entries';
      descriptionParts.add(limitText);
    }

    // Add validity period information
    final expirationDays = templateResponse['expiration_days'];
    if (expirationDays != null && expirationDays > 0) {
      final periodText =
          expirationDays == 1 ? '1 Day Valid' : '$expirationDays Days Valid';
      descriptionParts.add(periodText);
    }

    // Add amount information
    final amount = templateResponse['tax_amount'];
    final currency = templateResponse['currency_code'] ?? 'USD';
    if (amount != null) {
      descriptionParts.add('Amount: $currency ${amount.toStringAsFixed(2)}');
    }

    // Join all parts with bullet separators for clean auditing
    return descriptionParts.join(' • ');
  }
}
