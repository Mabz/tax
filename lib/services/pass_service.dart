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
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Generate pass verification data
    final passId = DateTime.now().millisecondsSinceEpoch.toString();
    final passHash =
        PurchasedPass.generateShortCode(passId).replaceAll('-', '');
    final shortCode = PurchasedPass.generateShortCode(passId);

    // Create initial QR data JSONB (UUID will be added by database function)
    final qrData = {
      'passId': passId,
      'passTemplate': passTemplateId,
      'vehicle': vehicleId,
      'issuedAt': DateTime.now().toIso8601String(),
      'hash': passHash, // Keep for backward compatibility
      'shortCode': shortCode,
    };

    // Call the database function which now returns the UUID and updates QR data
    await _supabase.rpc('issue_pass_from_template', params: {
      'target_profile_id': user.id,
      'target_vehicle_id': vehicleId,
      'pass_template_id': passTemplateId,
      'pass_hash': passHash,
      'short_code': shortCode,
      'qr_data': qrData,
    });

    // The database function now automatically adds the UUID to the QR data
    // This ensures the QR code contains the actual database UUID for secure verification
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
    final countryAuthorities = authorities
        .where((auth) => auth.countryId == countryId)
        .toList();
    
    // Get templates from all authorities in this country
    final List<PassTemplate> allTemplates = [];
    for (final authority in countryAuthorities) {
      final templates = await PassService.getPassTemplatesForAuthority(authority.id);
      allTemplates.addAll(templates);
    }
    
    return allTemplates;
  }
}
