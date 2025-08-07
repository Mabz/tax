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
                      vehicleDescription: 'Deleted Pass',
                      passDescription: 'Deleted Pass',
                      borderName: '',
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

  /// Issues a new pass from a template
  static Future<void> issuePassFromTemplate({
    String? vehicleId,
    required String passTemplateId,
    required DateTime activationDate,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // First, get the pass template details with a simple query
      final templateResponse = await _supabase
          .from('pass_templates')
          .select('*')
          .eq('id', passTemplateId)
          .eq('is_active', true)
          .single();

      if (templateResponse == null) {
        throw Exception('Pass template not found or inactive');
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

      // Insert the purchased pass directly - matching the actual schema
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
        'qr_data': qrData, // Use qr_data (jsonb) instead of qr_code
        'pass_description': templateResponse['description'] ?? 'Border Pass',
        'authority_id': templateResponse['authority_id'],
        'country_id': templateResponse['country_id'],
        'border_id': templateResponse['border_id'],
        'vehicle_desc': vehicleId != null ? null : 'General Pass - Any Vehicle',
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
      } else if (e.toString().contains('qr_code') &&
          e.toString().contains('schema cache')) {
        throw Exception(
            'Database schema error: QR code column structure mismatch. Using correct schema format.');
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

  /// Validate a pass by QR code data
  static Future<PurchasedPass?> validatePassByQRCode(String qrData) async {
    try {
      // Parse QR code data
      final parts = qrData.split('|');
      final passData = <String, String>{};

      for (final part in parts) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          passData[keyValue[0]] = keyValue[1];
        }
      }

      final passId = passData['passId'];
      if (passId == null) return null;

      // Get pass from database
      final response = await _supabase.from('purchased_passes').select('''
            *,
            pass_templates(
              id,
              name,
              description,
              entry_limit,
              validity_days,
              price,
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
      print('Error validating pass by QR code: $e');
      return null;
    }
  }

  /// Validate a pass by backup code
  static Future<PurchasedPass?> validatePassByBackupCode(
      String backupCode) async {
    try {
      // Search for pass with matching backup code
      final response = await _supabase.from('purchased_passes').select('''
            *,
            pass_templates(
              id,
              name,
              description,
              entry_limit,
              validity_days,
              price,
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
          ''').eq('short_code', backupCode).maybeSingle();

      if (response == null) return null;
      return PurchasedPass.fromJson(response);
    } catch (e) {
      print('Error validating pass by backup code: $e');
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
      print('Error deducting entry: $e');
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
              name,
              description,
              entry_limit,
              validity_days,
              price,
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
      print('Error getting pass by ID: $e');
      return null;
    }
  }
}
