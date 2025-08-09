import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/identity_documents.dart';
import '../enums/pass_verification_method.dart';

class ProfileManagementService {
  static final _supabase = Supabase.instance.client;

  /// Get all countries for selection
  static Future<List<Map<String, dynamic>>>
      getAllCountriesForSelection() async {
    try {
      final response = await _supabase.rpc('get_all_countries_for_selection');
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      throw Exception('Failed to get countries: $e');
    }
  }

  /// Get current user's identity documents
  static Future<IdentityDocuments> getMyIdentityDocuments() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final data = await getIdentityDocumentsForProfile(user.id);

      if (data != null) {
        return IdentityDocuments(
          countryOfOriginId: data['country_of_origin_id']?.toString(),
          countryName: data['country_name']?.toString(),
          countryCode: data['country_code']?.toString(),
          nationalIdNumber: data['national_id_number']?.toString(),
          passportNumber: data['passport_number']?.toString(),
          updatedAt: data['updated_at'] != null
              ? DateTime.parse(data['updated_at'].toString())
              : null,
        );
      }

      return IdentityDocuments();
    } catch (e) {
      throw Exception('Failed to get identity documents: $e');
    }
  }

  /// Update current user's full name
  static Future<void> updateFullName(String fullName) async {
    try {
      await _supabase.rpc('update_full_name', params: {
        'new_full_name': fullName,
      });
    } catch (e) {
      throw Exception('Failed to update full name: $e');
    }
  }

  /// Update current user's identity documents
  static Future<void> updateIdentityDocuments({
    required String countryOfOriginId,
    required String nationalIdNumber,
    required String passportNumber,
  }) async {
    try {
      await _supabase.rpc('update_identity_documents', params: {
        'new_country_of_origin_id': countryOfOriginId,
        'new_national_id_number': nationalIdNumber,
        'new_passport_number': passportNumber,
      });
    } catch (e) {
      throw Exception('Failed to update identity documents: $e');
    }
  }

  /// Get identity documents for a specific profile (for border officials)
  static Future<Map<String, dynamic>?> getIdentityDocumentsForProfile(
      String profileId) async {
    try {
      final response =
          await _supabase.rpc('get_identity_documents_for_profile', params: {
        'profile_id': profileId,
      });

      if (response != null && response is List && response.isNotEmpty) {
        return response[0] as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      throw Exception('Failed to get identity documents for profile: $e');
    }
  }

  /// Update pass confirmation preference
  static Future<void> updatePassConfirmationPreference(
      PassVerificationMethod method, String? staticPin) async {
    try {
      // Map to backend-expected identifiers (align with SQL: none, staticPin, dynamicCode)
      final String backendType;
      switch (method) {
        case PassVerificationMethod.none:
          backendType = 'none';
          break;
        case PassVerificationMethod.pin:
          backendType = 'staticPin';
          break;
        case PassVerificationMethod.secureCode:
          backendType = 'dynamicCode';
          break;
      }

      await _supabase.rpc('update_pass_confirmation_preference', params: {
        'pass_confirmation_type': backendType,
        'static_confirmation_code': staticPin,
      });
    } catch (e) {
      throw Exception('Failed to update pass confirmation preference: $e');
    }
  }

  /// Update payment details
  static Future<void> updatePaymentDetails({
    required String cardHolderName,
    required String cardLast4,
    required int cardExpMonth,
    required int cardExpYear,
    required String paymentProviderToken,
    required String paymentProvider,
  }) async {
    try {
      await _supabase.rpc('update_payment_details', params: {
        'new_card_holder_name': cardHolderName,
        'new_card_last4': cardLast4,
        'new_card_exp_month': cardExpMonth,
        'new_card_exp_year': cardExpYear,
        'new_payment_provider_token': paymentProviderToken,
        'new_payment_provider': paymentProvider,
      });
    } catch (e) {
      throw Exception('Failed to update payment details: $e');
    }
  }

  /// Clear all payment details
  static Future<void> clearPaymentDetails() async {
    try {
      await _supabase.rpc('clear_payment_details');
    } catch (e) {
      throw Exception('Failed to clear payment details: $e');
    }
  }

  /// Get current user's profile data including payment details
  static Future<Map<String, dynamic>?> getMyProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase.from('profiles').select('''
            full_name,
            email,
            country_of_origin_id,
            national_id_number,
            passport_number,
            require_manual_pass_confirmation,
            pass_confirmation_type,
            card_holder_name,
            card_last4,
            card_exp_month,
            card_exp_year,
            payment_provider,
            updated_at
          ''').eq('id', user.id).maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Failed to get profile: $e');
    }
  }

  /// Get verification preference for a pass owner
  static Future<PassVerificationMethod> getPassOwnerVerificationPreference(
      String passId) async {
    try {
      debugPrint('🔍 Getting verification preference for pass: $passId');

      // Try RPC function first
      try {
        final response = await _supabase
            .rpc('get_pass_owner_verification_preference', params: {
          'pass_id': passId,
        });

        debugPrint('📋 RPC Response: $response');

        if (response != null && response is List && response.isNotEmpty) {
          final firstResult = response[0] as Map<String, dynamic>;
          if (firstResult['pass_confirmation_type'] != null) {
            final String confirmationType =
                firstResult['pass_confirmation_type'].toString();

            debugPrint('✅ Found confirmation type: $confirmationType');
            return _mapConfirmationTypeToEnum(confirmationType);
          }
        }
      } catch (rpcError) {
        debugPrint(
            '⚠️ RPC function not available, using fallback query: $rpcError');

        // Fallback: Two-step query to avoid UUID/text comparison issues
        // First get the profile_id from the pass
        final passResponse = await _supabase
            .from('purchased_passes')
            .select('profile_id')
            .eq('id', passId)
            .maybeSingle();

        debugPrint('📋 Pass Response: $passResponse');

        if (passResponse != null && passResponse['profile_id'] != null) {
          // Then get the pass_confirmation_type from the profile
          final profileResponse = await _supabase
              .from('profiles')
              .select('pass_confirmation_type')
              .eq('id', passResponse['profile_id'])
              .maybeSingle();

          debugPrint('📋 Profile Response: $profileResponse');

          if (profileResponse != null &&
              profileResponse['pass_confirmation_type'] != null) {
            final String confirmationType =
                profileResponse['pass_confirmation_type'].toString();
            debugPrint(
                '✅ Found confirmation type via fallback: $confirmationType');
            return _mapConfirmationTypeToEnum(confirmationType);
          }
        }
      }

      debugPrint('⚠️ No confirmation type found, defaulting to none');
      return PassVerificationMethod.none;
    } catch (e) {
      debugPrint('❌ Error getting verification preference: $e');
      return PassVerificationMethod.none;
    }
  }

  /// Helper method to map confirmation type string to enum
  static PassVerificationMethod _mapConfirmationTypeToEnum(
      String confirmationType) {
    switch (confirmationType) {
      case 'none':
        debugPrint('➡️ Returning: none');
        return PassVerificationMethod.none;
      case 'staticPin':
        debugPrint('➡️ Returning: pin');
        return PassVerificationMethod.pin;
      case 'dynamicCode':
        debugPrint('➡️ Returning: secureCode');
        return PassVerificationMethod.secureCode;
      default:
        debugPrint(
            '⚠️ Unknown confirmation type: $confirmationType, defaulting to none');
        return PassVerificationMethod.none;
    }
  }

  /// Get the stored PIN for a pass owner (for verification)
  static Future<String?> getPassOwnerStoredPin(String passId) async {
    try {
      debugPrint('🔍 Getting stored PIN for pass: $passId');

      // Two-step query to avoid UUID/text comparison issues
      // First get the profile_id from the pass
      final passResponse = await _supabase
          .from('purchased_passes')
          .select('profile_id')
          .eq('id', passId)
          .maybeSingle();

      debugPrint('📋 Pass Response: $passResponse');

      if (passResponse != null && passResponse['profile_id'] != null) {
        // Then get the static_confirmation_code from the profile
        final profileResponse = await _supabase
            .from('profiles')
            .select('static_confirmation_code')
            .eq('id', passResponse['profile_id'])
            .maybeSingle();

        debugPrint('📋 Profile PIN Response: $profileResponse');

        if (profileResponse != null &&
            profileResponse['static_confirmation_code'] != null) {
          final String storedPin =
              profileResponse['static_confirmation_code'].toString();
          debugPrint('✅ Found stored PIN');
          return storedPin;
        }
      }

      debugPrint('⚠️ No stored PIN found');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting stored PIN: $e');
      return null;
    }
  }
}
