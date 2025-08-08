import 'package:flutter/foundation.dart';
import 'package:flutter_supabase_auth/models/authority.dart';
import 'package:flutter_supabase_auth/models/pass_template.dart';
import 'package:flutter_supabase_auth/models/purchased_pass.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PassService {
  static final _supabase = Supabase.instance.client;
  static RealtimeChannel? _passesChannel;

  /// Subscribe to realtime updates for purchased passes with granular updates
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

    _passesChannel = _supabase
        .channel('purchased_passes_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'purchased_passes',
          callback: (payload) async {
            try {
              // Check if this change is for the current user
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;

              // For INSERT and UPDATE, check newRecord
              if (newRecord.isNotEmpty) {
                final recordUserId =
                    newRecord['profile_id'] ?? newRecord['user_id'];
                if (recordUserId != user.id) {
                  return; // Skip if not for current user
                }
              }

              // For DELETE, check oldRecord
              if (payload.eventType == PostgresChangeEvent.delete &&
                  oldRecord.isNotEmpty) {
                final recordUserId =
                    oldRecord['profile_id'] ?? oldRecord['user_id'];
                if (recordUserId != user.id) {
                  return; // Skip if not for current user
                }
              }

              // Handle specific change types
              switch (payload.eventType) {
                case PostgresChangeEvent.insert:
                  if (newRecord.isNotEmpty) {
                    // For new passes, we need to fetch the full pass data with JOINs
                    // since the raw record doesn't include joined data like border_name, authority_name
                    final passId = newRecord['id'];
                    final fullPassData =
                        await _supabase.rpc('get_passes_for_user', params: {
                      'target_profile_id': user.id,
                    });

                    // Find the newly inserted pass
                    final List<dynamic> data = fullPassData as List<dynamic>;
                    final newPassData = data.firstWhere(
                      (pass) => pass['pass_id'] == passId,
                      orElse: () => null,
                    );

                    if (newPassData != null) {
                      final newPass = PurchasedPass.fromJson(
                          newPassData as Map<String, dynamic>);
                      onPassChanged(newPass, 'INSERT');
                    }
                  }
                  break;

                case PostgresChangeEvent.update:
                  if (newRecord.isNotEmpty) {
                    // For updates, fetch the updated pass data
                    final passId = newRecord['id'];
                    final fullPassData =
                        await _supabase.rpc('get_passes_for_user', params: {
                      'target_profile_id': user.id,
                    });

                    final List<dynamic> data = fullPassData as List<dynamic>;
                    final updatedPassData = data.firstWhere(
                      (pass) => pass['pass_id'] == passId,
                      orElse: () => null,
                    );

                    if (updatedPassData != null) {
                      final updatedPass = PurchasedPass.fromJson(
                          updatedPassData as Map<String, dynamic>);
                      onPassChanged(updatedPass, 'UPDATE');
                    }
                  }
                  break;

                case PostgresChangeEvent.delete:
                  if (oldRecord.isNotEmpty) {
                    // For deletes, we only have the old record data
                    // Create a minimal pass object for deletion handling
                    final deletedPass = PurchasedPass(
                      passId: oldRecord['id'] ?? '',
                      vehicleDescription:
                          'Deleted Pass', // Add required parameter
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
                  // Handle PostgresChangeEvent.all or any other cases
                  break;
              }
            } catch (e) {
              onError('Error processing realtime update: $e');
            }
          },
        )
        .subscribe((status, [error]) {
      if (error != null) {
        onError('Subscription error: $error');
      }
    });

    return _passesChannel!;
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
            ),
            borders(name)
          ''').eq('id', passTemplateId).eq('is_active', true).single();

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

      // Create QR data
      final qrData = {
        'passTemplate': passTemplateId,
        'vehicle': vehicleId ?? 'general',
        'issuedAt': DateTime(now.year, now.month, now.day).toIso8601String(),
        'activationDate': DateTime(
                activationDate.year, activationDate.month, activationDate.day)
            .toIso8601String(),
        'expirationDate': DateTime(
                expirationDate.year, expirationDate.month, expirationDate.day)
            .toIso8601String(),
        'hash': passHash,
        'shortCode': shortCode,
      };

      // Determine vehicle data to store
      String? finalVehicleDescription = vehicleDescription;
      String? finalVehicleNumberPlate = vehicleNumberPlate;
      String? finalVehicleVin = vehicleVin;

      // If vehicle data not provided but vehicleId is, fetch from vehicles table
      if (vehicleId != null &&
          (finalVehicleDescription == null &&
              finalVehicleNumberPlate == null &&
              finalVehicleVin == null)) {
        try {
          final vehicleResponse = await _supabase
              .from('vehicles')
              .select('number_plate, vin_number, description')
              .eq('id', vehicleId)
              .single();

          finalVehicleDescription = vehicleResponse['description']?.toString();
          finalVehicleNumberPlate = vehicleResponse['number_plate']?.toString();
          finalVehicleVin = vehicleResponse['vin_number']?.toString();
        } catch (e) {
          debugPrint('Error fetching vehicle details: $e');
          // Continue without vehicle data - pass will be general
        }
      }

      // Extract related data from template response
      final authorityData =
          templateResponse['authorities'] as Map<String, dynamic>?;
      final borderData = templateResponse['borders'] as Map<String, dynamic>?;
      final countryData = authorityData?['countries'] as Map<String, dynamic>?;

      // Insert the purchased pass with individual vehicle fields
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
        'qr_data': qrData,
        'pass_description': templateResponse['description'] ?? 'Border Pass',
        'authority_id': templateResponse['authority_id'],
        'country_id': countryData?['id'] ?? templateResponse['country_id'],
        'border_id': templateResponse['border_id'],

        // Individual vehicle fields (replacing vehicle_desc)
        'vehicle_description': finalVehicleDescription,
        'vehicle_number_plate': finalVehicleNumberPlate,
        'vehicle_vin': finalVehicleVin,

        // Store denormalized data for faster queries
        'authority_name': authorityData?['name'],
        'country_name': countryData?['name'],
        'border_name': borderData?['name'],
      };

      await _supabase.from('purchased_passes').insert(insertData);
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

    final response = await _supabase.rpc('get_passes_for_user', params: {
      'target_profile_id': user.id,
    });

    if (response == null) return [];

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) => PurchasedPass.fromJson(json as Map<String, dynamic>))
        .toList();
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
    final response =
        await _supabase.rpc('get_pass_templates_for_authority', params: {
      'target_authority_id': authorityId,
    });

    if (response == null) return [];

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) => PassTemplate.fromJson(json as Map<String, dynamic>))
        .toList();
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

  /// Validate a pass by QR code data (using RPC function)
  static Future<PurchasedPass?> validatePassByQRCode(String qrData) async {
    try {
      debugPrint('Validating QR code data: ${qrData.length} characters');

      // Use RPC function for QR code validation
      final response = await _supabase.rpc('validate_pass_by_qr_code', params: {
        'qr_data_input': qrData,
      });

      if (response != null && response is List && response.isNotEmpty) {
        final passData = response.first as Map<String, dynamic>;
        final pass = PurchasedPass.fromJson(passData);
        debugPrint('Successfully validated pass via RPC: ${pass.passId}');
        return pass;
      }

      debugPrint('No pass found for QR data via RPC');
      return null;
    } catch (e) {
      debugPrint('RPC validation failed, trying fallback: $e');
      // Fallback to direct parsing and query
      return _fallbackValidatePassByQRCode(qrData);
    }
  }

  /// Fallback QR code validation using direct database query
  static Future<PurchasedPass?> _fallbackValidatePassByQRCode(
      String qrData) async {
    try {
      debugPrint('Using fallback QR validation method');

      // Parse QR code data - handle different formats
      String? passId;

      // Try parsing pipe-separated format first
      if (qrData.contains('|')) {
        final parts = qrData.split('|');
        final passData = <String, String>{};

        for (final part in parts) {
          final keyValue = part.split(':');
          if (keyValue.length == 2) {
            passData[keyValue[0]] = keyValue[1];
          }
        }
        passId = passData['passId'];
        debugPrint('Parsed pipe format, passId: $passId');
      } else {
        // Try treating the entire string as a pass ID
        passId = qrData.trim();
        debugPrint('Treating as direct passId: $passId');
      }

      if (passId == null || passId.isEmpty) {
        debugPrint('No passId found in QR data');
        return null;
      }

      // Get pass from database with joins
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
              border_id,
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
        debugPrint('No pass found with ID: $passId');
        return null;
      }

      final pass = PurchasedPass.fromJson(response);
      debugPrint('Successfully validated pass via fallback: ${pass.passId}');
      return pass;
    } catch (e) {
      debugPrint('Fallback QR validation also failed: $e');
      return null;
    }
  }

  /// Validates and cleans a backup code input
  /// Returns the cleaned code if valid, null if invalid
  static String? _validateAndCleanBackupCode(String backupCode) {
    try {
      debugPrint('Input backup code: "$backupCode"');

      // Step 1: Basic validation - check if input is not empty
      if (backupCode.trim().isEmpty) {
        debugPrint('❌ Error: Empty backup code');
        return null;
      }

      // Step 2: Clean the backup code (remove spaces, hyphens, convert to uppercase)
      final cleanCode = backupCode
          .trim()
          .toUpperCase()
          .replaceAll('-', '')
          .replaceAll(' ', '');
      debugPrint('Cleaned backup code: "$cleanCode"');

      // Step 3: Validate length (should be exactly 8 characters)
      if (cleanCode.length != 8) {
        debugPrint(
            '❌ Error: Invalid length. Expected 8 characters, got ${cleanCode.length}');
        return null;
      }

      // Step 4: Validate characters (should only contain alphanumeric characters)
      final validCharacters = RegExp(r'^[A-Z0-9]+$');
      if (!validCharacters.hasMatch(cleanCode)) {
        debugPrint('❌ Error: Invalid characters. Only A-Z and 0-9 are allowed');
        return null;
      }

      debugPrint('✅ Valid backup code: "$cleanCode"');
      return cleanCode;
    } catch (e) {
      debugPrint('❌ Error validating backup code: $e');
      return null;
    }
  }

  /// Validate a pass by backup code (using RPC function)
  static Future<PurchasedPass?> validatePassByBackupCode(
      String backupCode) async {
    try {
      debugPrint('Validating backup code: $backupCode');

      // First, do local validation for immediate feedback
      final cleanCode = _validateAndCleanBackupCode(backupCode);
      if (cleanCode == null) {
        debugPrint('Invalid backup code format');
        return null;
      }

      debugPrint('Local validation passed, querying database...');

      // Use RPC function for database validation
      final response =
          await _supabase.rpc('validate_pass_by_backup_code', params: {
        'backup_code': backupCode,
      });

      if (response != null && response is List && response.isNotEmpty) {
        final passData = response.first as Map<String, dynamic>;
        final pass = PurchasedPass.fromJson(passData);
        debugPrint('Successfully found pass with backup code: ${pass.passId}');
        return pass;
      }

      debugPrint('No pass found with backup code: $backupCode');
      return null;
    } catch (e) {
      debugPrint('Error validating pass by backup code: $e');
      // If RPC function fails, fallback to direct query
      return _fallbackValidatePassByBackupCode(backupCode);
    }
  }

  /// Fallback validation using direct database query
  static Future<PurchasedPass?> _fallbackValidatePassByBackupCode(
      String backupCode) async {
    try {
      debugPrint('Using fallback validation method');

      final cleanCode = _validateAndCleanBackupCode(backupCode);
      if (cleanCode == null) return null;

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
              border_id,
              is_active
            ),
            authorities(
              id,
              name,
              code,
              country_id,
              countries(name, country_code)
            )
          ''').eq('pass_hash', cleanCode).maybeSingle();

      if (response != null) {
        return PurchasedPass.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Fallback validation also failed: $e');
      return null;
    }
  }

  /// Deduct an entry from a pass
  static Future<bool> deductEntry(String passId) async {
    try {
      // Get current pass
      final currentPass = await _supabase
          .from('purchased_passes')
          .select('entries_remaining')
          .eq('id', passId)
          .single();

      final currentEntries = currentPass['entries_remaining'] as int;

      if (currentEntries <= 0) {
        throw Exception('No entries remaining');
      }

      // Deduct one entry
      await _supabase.from('purchased_passes').update({
        'entries_remaining': currentEntries - 1,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', passId);

      // Log the entry deduction (optional)
      await _supabase.from('pass_usage_logs').insert({
        'pass_id': passId,
        'action': 'entry_deducted',
        'performed_by': _supabase.auth.currentUser?.id,
        'performed_at': DateTime.now().toIso8601String(),
        'details': {'entries_remaining': currentEntries - 1},
      });

      return true;
    } catch (e) {
      debugPrint('Error deducting entry: $e');
      return false;
    }
  }

  /// Get pass by ID for validation
  static Future<PurchasedPass?> getPassById(String passId) async {
    try {
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
              border_id,
              is_active
            ),
            authorities(
              id,
              name,
              code,
              country_id,
              countries(name, country_code)
            )
          ''').eq('id', passId).single();

      return PurchasedPass.fromJson(response);
    } catch (e) {
      debugPrint('Error getting pass by ID: $e');
      return null;
    }
  }
}
