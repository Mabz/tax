import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/identity_documents.dart';

class ProfileManagementService {
  static final _supabase = Supabase.instance.client;

  /// Get all countries for selection
  static Future<List<Map<String, dynamic>>>
      getAllCountriesForSelection() async {
    try {
      print('🌍 Calling get_all_countries_for_selection function...');
      final response = await _supabase.rpc('get_all_countries_for_selection');
      print('🌍 Raw response: $response');
      print('🌍 Response type: ${response.runtimeType}');

      if (response == null) {
        print('🌍 Response is null!');
        return [];
      }

      final countries = List<Map<String, dynamic>>.from(response);
      print('🌍 Parsed countries count: ${countries.length}');
      print('🌍 First few countries: ${countries.take(3).toList()}');

      return countries;
    } catch (e) {
      print('🌍 Error getting countries: $e');
      throw Exception('Failed to get countries: $e');
    }
  }

  /// Get current user's identity documents
  static Future<IdentityDocuments> getMyIdentityDocuments() async {
    try {
      print('🆔 Calling get_my_identity_documents...');
      final response = await _supabase.rpc('get_my_identity_documents');
      print('🆔 Identity response: $response');
      print('🆔 Response type: ${response.runtimeType}');
      
      if (response != null && response is List && response.isNotEmpty) {
        final data = response[0] as Map<String, dynamic>;
        print('🆔 Processing identity data: $data');
        
        // Create IdentityDocuments from the function response
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
      
      print('🆔 No identity documents found, returning empty');
      return IdentityDocuments();
    } catch (e) {
      print('🆔 Error getting identity documents: $e');
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
      print('🆔 Calling get_identity_documents_for_profile for: $profileId');
      final response =
          await _supabase.rpc('get_identity_documents_for_profile', params: {
        'profile_id': profileId,
      });
      print('🆔 Profile identity response: $response');

      if (response != null && response is List && response.isNotEmpty) {
        final data = response[0] as Map<String, dynamic>;
        print('🆔 Processing profile identity data: $data');
        return data;
      }

      print('🆔 No identity documents found for profile: $profileId');
      return null;
    } catch (e) {
      print('🆔 Error getting identity documents for profile: $e');
      throw Exception('Failed to get identity documents for profile: $e');
    }
  }

  /// Update pass confirmation preference
  static Future<void> updatePassConfirmationPreference(
      bool requireConfirmation) async {
    try {
      await _supabase.rpc('update_pass_confirmation_preference', params: {
        'require_confirmation': requireConfirmation,
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

  /// Test database connection and countries function
  static Future<void> testCountriesFunction() async {
    try {
      print('🧪 Testing database connection...');

      // Test direct table query
      final directQuery = await _supabase
          .from('countries')
          .select('id, name, country_code')
          .limit(5);
      print('🧪 Direct countries query result: $directQuery');

      // Test RPC function
      final rpcResult = await _supabase.rpc('get_all_countries_for_selection');
      print('🧪 RPC function result: $rpcResult');
    } catch (e) {
      print('🧪 Test error: $e');
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
            require_manual_pass_confirmation ,
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
}
