import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchased_pass.dart';
import '../models/country.dart';
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
                    // since the raw record doesn't include joined data like border_name
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

  /// Gets active countries for pass template selection
  static Future<List<Country>> getActiveCountries() async {
    final response = await _supabase
        .from('countries')
        .select('*')
        .eq('is_active', true)
        .neq('name', 'Global')
        .order('name');

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) => Country.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Gets pass templates for a specific country
  static Future<List<PassTemplate>> getPassTemplatesForCountry(
      String countryId) async {
    final response =
        await _supabase.rpc('get_pass_templates_for_country', params: {
      'target_country_id': countryId,
    });

    if (response == null) return [];

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) => PassTemplate.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
