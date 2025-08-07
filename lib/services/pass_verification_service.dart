import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchased_pass.dart';
import '../enums/pass_verification_method.dart';
import '../enums/authority_type.dart';

class PassVerificationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Verify a pass by QR code or backup code
  static Future<PurchasedPass?> verifyPass({
    required String code,
    required bool isQrCode,
  }) async {
    try {
      debugPrint('🔍 Verifying pass with ${isQrCode ? 'QR' : 'backup'} code');

      final response = await _supabase.rpc('verify_pass', params: {
        'verification_code': code,
        'is_qr_code': isQrCode,
      });

      if (response == null || (response is List && response.isEmpty)) {
        debugPrint('❌ Pass not found or invalid');
        return null;
      }

      Map<String, dynamic> passData;
      if (response is List && response.isNotEmpty) {
        passData = response.first as Map<String, dynamic>;
      } else if (response is Map<String, dynamic>) {
        passData = response;
      } else {
        debugPrint('❌ Unexpected response format');
        return null;
      }

      final pass = PurchasedPass.fromJson(passData);
      debugPrint('✅ Pass verified: ${pass.passId}');
      return pass;
    } catch (e) {
      debugPrint('❌ Error verifying pass: $e');
      return null;
    }
  }

  /// Get pass verification preferences
  static Future<PassVerificationMethod> getPassVerificationMethod(
      String passId) async {
    try {
      debugPrint('🔍 Getting verification method for pass: $passId');

      final response =
          await _supabase.rpc('get_pass_verification_method', params: {
        'target_pass_id': passId,
      });

      final method = response as String?;
      switch (method) {
        case 'pin':
          return PassVerificationMethod.pin;
        case 'secure_code':
          return PassVerificationMethod.secureCode;
        default:
          return PassVerificationMethod.none;
      }
    } catch (e) {
      debugPrint('❌ Error getting verification method: $e');
      return PassVerificationMethod.none;
    }
  }

  /// Generate a dynamic secure code for pass verification
  static Future<String?> generateSecureCode(String passId) async {
    try {
      debugPrint('🔍 Generating secure code for pass: $passId');

      final response = await _supabase.rpc('generate_secure_code', params: {
        'target_pass_id': passId,
      });

      final secureCode = response as String?;
      debugPrint('✅ Secure code generated');
      return secureCode;
    } catch (e) {
      debugPrint('❌ Error generating secure code: $e');
      return null;
    }
  }

  /// Verify PIN for pass deduction
  static Future<bool> verifyPin({
    required String passId,
    required String pin,
  }) async {
    try {
      debugPrint('🔍 Verifying PIN for pass: $passId');

      final response = await _supabase.rpc('verify_pass_pin', params: {
        'target_pass_id': passId,
        'provided_pin': pin,
      });

      final isValid = response as bool;
      debugPrint('✅ PIN verification result: $isValid');
      return isValid;
    } catch (e) {
      debugPrint('❌ Error verifying PIN: $e');
      return false;
    }
  }

  /// Verify secure code for pass deduction
  static Future<bool> verifySecureCode({
    required String passId,
    required String secureCode,
  }) async {
    try {
      debugPrint('🔍 Verifying secure code for pass: $passId');

      final response = await _supabase.rpc('verify_secure_code', params: {
        'target_pass_id': passId,
        'provided_code': secureCode,
      });

      final isValid = response as bool;
      debugPrint('✅ Secure code verification result: $isValid');
      return isValid;
    } catch (e) {
      debugPrint('❌ Error verifying secure code: $e');
      return false;
    }
  }

  /// Deduct entry from pass
  static Future<PurchasedPass?> deductPassEntry({
    required String passId,
    required AuthorityType authorityType,
    String? verificationData,
  }) async {
    try {
      debugPrint('🔍 Deducting entry from pass: $passId');

      final response = await _supabase.rpc('deduct_pass_entry', params: {
        'target_pass_id': passId,
        'authority_type': authorityType.name,
        'verification_data': verificationData,
      });

      if (response == null || (response is List && response.isEmpty)) {
        debugPrint('❌ Failed to deduct entry');
        return null;
      }

      Map<String, dynamic> passData;
      if (response is List && response.isNotEmpty) {
        passData = response.first as Map<String, dynamic>;
      } else if (response is Map<String, dynamic>) {
        passData = response;
      } else {
        debugPrint('❌ Unexpected response format');
        return null;
      }

      final updatedPass = PurchasedPass.fromJson(passData);
      debugPrint(
          '✅ Entry deducted. Remaining: ${updatedPass.entriesRemaining}');
      return updatedPass;
    } catch (e) {
      debugPrint('❌ Error deducting entry: $e');
      return null;
    }
  }

  /// Log pass validation activity
  static Future<void> logValidationActivity({
    required String passId,
    required AuthorityType authorityType,
    required String action,
    bool success = true,
    String? notes,
  }) async {
    try {
      debugPrint('🔍 Logging validation activity for pass: $passId');

      await _supabase.rpc('log_validation_activity', params: {
        'target_pass_id': passId,
        'authority_type': authorityType.name,
        'action_type': action,
        'success': success,
        'notes': notes,
      });

      debugPrint('✅ Validation activity logged');
    } catch (e) {
      debugPrint('❌ Error logging validation activity: $e');
    }
  }
}
