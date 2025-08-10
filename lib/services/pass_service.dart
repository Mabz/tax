import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchased_pass.dart';
import '../models/authority.dart';
import '../models/pass_template.dart';

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
              // Extract records (payloads can be partial depending on REPLICA IDENTITY)
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;

              // Best-effort quick filter if profile_id is present
              final newProfileId =
                  newRecord['profile_id'] ?? newRecord['user_id'];
              final oldProfileId =
                  oldRecord['profile_id'] ?? oldRecord['user_id'];
              if (newProfileId != null && newProfileId != user.id) {
                return;
              }
              if (payload.eventType == PostgresChangeEvent.delete &&
                  oldProfileId != null &&
                  oldProfileId != user.id) {
                return;
              }

              // Handle specific change types
              switch (payload.eventType) {
                case PostgresChangeEvent.insert:
                  if (newRecord.isNotEmpty || oldRecord.isNotEmpty) {
                    // For new passes, fetch the full pass by ID (includes joins and secure_code)
                    final passId =
                        (newRecord['id'] ?? oldRecord['id'])?.toString();
                    if (passId == null) {
                      break; // Cannot proceed without id
                    }
                    final newPass = await getPassById(passId);
                    if (newPass != null) {
                      onPassChanged(newPass, 'INSERT');
                    } else {
                      // Fallback: scan RPC list if getPassById didn't return
                      final fullPassData =
                          await _supabase.rpc('get_passes_for_user', params: {
                        'target_profile_id': user.id,
                      });
                      final List<dynamic> data =
                          (fullPassData ?? []) as List<dynamic>;
                      Map<String, dynamic>? newPassData;
                      for (final p in data) {
                        final m = p as Map<String, dynamic>;
                        final pid = (m['pass_id'] ?? m['id'])?.toString();
                        if (pid == passId) {
                          newPassData = m;
                          break;
                        }
                      }
                      if (newPassData != null) {
                        onPassChanged(
                            PurchasedPass.fromJson(newPassData), 'INSERT');
                      }
                    }
                  }
                  break;

                case PostgresChangeEvent.update:
                  if (newRecord.isNotEmpty || oldRecord.isNotEmpty) {
                    // For updates, fetch the updated pass by ID (ensures secure_code changes are included)
                    final passId =
                        (newRecord['id'] ?? oldRecord['id'])?.toString();
                    if (passId == null) {
                      break; // Cannot proceed without id
                    }
                    final updatedPass = await getPassById(passId);
                    if (updatedPass != null) {
                      onPassChanged(updatedPass, 'UPDATE');
                    } else {
                      // Fallback: scan RPC list
                      final fullPassData =
                          await _supabase.rpc('get_passes_for_user', params: {
                        'target_profile_id': user.id,
                      });
                      final List<dynamic> data =
                          (fullPassData ?? []) as List<dynamic>;
                      Map<String, dynamic>? updatedPassData;
                      for (final p in data) {
                        final m = p as Map<String, dynamic>;
                        final pid = (m['pass_id'] ?? m['id'])?.toString();
                        if (pid == passId) {
                          updatedPassData = m;
                          break;
                        }
                      }
                      if (updatedPassData != null) {
                        onPassChanged(
                            PurchasedPass.fromJson(updatedPassData), 'UPDATE');
                      }
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

      // Extract related data from template response first (needed for QR data)
      final authorityData =
          templateResponse['authorities'] as Map<String, dynamic>?;
      final borderData = templateResponse['borders'] as Map<String, dynamic>?;
      final countryData = authorityData?['countries'] as Map<String, dynamic>?;

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
        'border_id': templateResponse['border_id'],
        'border_name': borderData?['name'] ?? '',
        'country_id': countryData?['id'] ?? templateResponse['country_id'],
        'country_name': countryData?['name'] ?? '',

        // Pass details
        'pass_description': _buildPassDescription(
          templateResponse,
          authorityData,
          borderData,
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
        'vehicle_number_plate': finalVehicleNumberPlate ?? '',
        'vehicle_vin': finalVehicleVin ?? '',
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
          borderData,
          countryData,
          finalVehicleDescription,
          finalVehicleNumberPlate,
          finalVehicleVin,
          activationDate,
        ),
        'authority_id': templateResponse['authority_id'],
        'country_id': countryData?['id'] ?? templateResponse['country_id'],
        'border_id': templateResponse['border_id'],

        // Individual vehicle fields (NO vehicle_desc)
        'vehicle_description': finalVehicleDescription,
        'vehicle_number_plate': finalVehicleNumberPlate,
        'vehicle_vin': finalVehicleVin,

        // Store denormalized data for faster queries
        'authority_name': authorityData?['name'],
        'country_name': countryData?['name'],
        'border_name': borderData?['name'],
      };

      // Insert the pass and get the generated ID
      final insertResult = await _supabase
          .from('purchased_passes')
          .insert(insertData)
          .select('id')
          .single();

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
        'border_id': templateResponse['border_id'],
        'border_name': borderData?['name'] ?? '',
        'country_id': countryData?['id'] ?? templateResponse['country_id'],
        'country_name': countryData?['name'] ?? '',

        // Pass details
        'pass_description': templateResponse['description'] ?? 'Border Pass',
        'entry_limit': templateResponse['entry_limit'],
        'currency': templateResponse['currency_code'] ?? 'USD',
        'amount': templateResponse['tax_amount'],

        // Vehicle information
        'vehicle_description': finalVehicleDescription ?? '',
        'vehicle_number_plate': finalVehicleNumberPlate ?? '',
        'vehicle_vin': finalVehicleVin ?? '',
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
              border_id,
              is_active,
              borders(
                id,
                name
              )
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

      return data.map((json) {
        final passData = json as Map<String, dynamic>;

        debugPrint('🔍 Raw pass data keys: ${passData.keys}');
        debugPrint('🔍 Pass templates data: ${passData['pass_templates']}');

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
        }

        debugPrint(
            '🔍 Final flattened data - entry_limit: ${passData['entry_limit']}, amount: ${passData['amount']}');
        return PurchasedPass.fromJson(passData);
      }).toList();
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

      debugPrint('No pass found for QR data via RPC, trying fallback');
      // Fallback to direct parsing and query when RPC returns empty
      return _fallbackValidatePassByQRCode(qrData);
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
      final raw = qrData.trim();

      // Parse QR code data - handle different formats
      String? passId;
      String? passHash;

      // 1) Minimal formats: PASS:<uuid> or HASH:<hash>
      if (raw.toUpperCase().startsWith('PASS:')) {
        passId = raw.substring(5).trim();
      } else if (raw.toUpperCase().startsWith('HASH:')) {
        passHash = raw.substring(5).trim().toUpperCase();
      } else if (raw.startsWith('{')) {
        // 2) JSON payload
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final idCandidate = (decoded['passId'] ?? decoded['id'])?.toString();
          final hashCandidate =
              (decoded['hash'] ?? decoded['pass_hash'] ?? decoded['shortCode'])
                  ?.toString();
          if (idCandidate != null && idCandidate.isNotEmpty) {
            passId = idCandidate;
          }
          if (hashCandidate != null && hashCandidate.isNotEmpty) {
            passHash = hashCandidate.toUpperCase().replaceAll('-', '');
          }
        } catch (_) {
          // Ignore JSON errors; fall through to other strategies
        }
      } else if (raw.contains('|')) {
        // 3) Legacy pipe-delimited key:value pairs; split only on first ':'
        final parts = raw.split('|');
        final passData = <String, String>{};
        for (final part in parts) {
          final idx = part.indexOf(':');
          if (idx > 0) {
            final key = part.substring(0, idx);
            final value = part.substring(idx + 1);
            passData[key] = value;
          }
        }

        passId = passData['passId'] ?? passData['id'];
        passHash =
            (passData['hash'] ?? passData['pass_hash'] ?? passData['shortCode'])
                ?.toUpperCase()
                .replaceAll('-', '');
      } else {
        // 4) Raw candidates: UUID or 8-char hash
        final uuidRegex = RegExp(r'^[0-9a-fA-F-]{32,36}$');
        final hashRegex = RegExp(r'^[A-Z0-9]{8}$');
        if (uuidRegex.hasMatch(raw)) {
          passId = raw;
        } else if (hashRegex.hasMatch(raw.toUpperCase())) {
          passHash = raw.toUpperCase();
        }
      }

      // Prefer direct ID lookup; otherwise try pass_hash
      Map<String, dynamic>? response;
      if (passId != null && passId.isNotEmpty) {
        response = await _supabase.from('purchased_passes').select('''
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
      }

      if (response == null && passHash != null && passHash.isNotEmpty) {
        response = await _supabase.from('purchased_passes').select('''
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
            ''').eq('pass_hash', passHash).maybeSingle();
      }

      if (response == null) {
        debugPrint(
            'No pass found via fallback. passId=$passId, passHash=$passHash');
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

  /// Build a clean, comprehensive pass description for auditing purposes
  static String _buildPassDescription(
    Map<String, dynamic> templateResponse,
    Map<String, dynamic>? authorityData,
    Map<String, dynamic>? borderData,
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
    final borderName = borderData?['name']?.toString();
    if (borderName != null && borderName.isNotEmpty) {
      descriptionParts.add('Border: $borderName');
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
