import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner_web.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchased_pass.dart';
import '../enums/pass_verification_method.dart';
import '../enums/authority_type.dart';

class PassVerificationService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static String? _lastMovementId; // Track the last movement ID for updates

  /// Verify a pass by QR code or backup code
  static Future<PurchasedPass?> verifyPass({
    required String code,
    required bool isQrCode,
    String authorityType = 'local_authority',
    String scanPurpose = 'verification_check',
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    String? passId;

    try {
      // Enhanced logging to debug QR scanning issues
      debugPrint('🔍 ========== QR SCAN DEBUG ==========');
      debugPrint('🔍 Verifying pass with ${isQrCode ? 'QR' : 'backup'} code');
      debugPrint('🔍 Authority: $authorityType, Purpose: $scanPurpose');
      debugPrint(
          '🔍 Location: ${latitude != null && longitude != null ? '$latitude, $longitude' : 'Not provided'}');
      debugPrint('🔍 Code length: ${code.length} characters');
      debugPrint('🔍 Raw code: "$code"');

      // STEP 1: Extract pass ID from QR code FIRST (before verification)
      if (isQrCode) {
        try {
          final jsonData = jsonDecode(code);
          debugPrint('🔍 Parsed as JSON: $jsonData');
          if (jsonData is Map && jsonData.containsKey('id')) {
            passId = jsonData['id'].toString();
            debugPrint('🔍 ✅ Found ID in JSON: $passId');
          } else {
            debugPrint('🔍 ❌ JSON missing ID field');
          }
        } catch (e) {
          debugPrint('🔍 ❌ Not valid JSON: $e');
          debugPrint('🔍 Treating as plain text/UUID');

          // Try to extract UUID directly
          final uuidPattern = RegExp(
              r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
          final match = uuidPattern.firstMatch(code);
          if (match != null) {
            passId = match.group(0);
            debugPrint('🔍 ✅ Extracted UUID: $passId');
          }
        }
      }

      // STEP 2: Log the scan IMMEDIATELY (before verification completes)
      if (passId != null) {
        try {
          debugPrint('📝 Logging scan BEFORE verification...');
          await _logScanActivity(
            passId: passId,
            authorityType: authorityType,
            scanPurpose: scanPurpose,
            latitude: latitude,
            longitude: longitude,
            notes: notes,
            scanStatus: 'scan_attempted', // Mark as scan attempt
          );
          debugPrint('✅ Scan logged immediately with location data');
        } catch (e) {
          debugPrint('⚠️ Failed to log scan activity: $e');
          // Continue with verification even if logging fails
        }
      } else {
        debugPrint('⚠️ Could not extract pass ID for immediate logging');
      }

      // STEP 3: Now proceed with verification
      debugPrint('🔍 Calling verify_pass RPC function...');

      final response = await _supabase.rpc('verify_pass', params: {
        'verification_code': code,
        'is_qr_code': isQrCode,
      });

      debugPrint('🔍 RPC response type: ${response.runtimeType}');
      debugPrint('🔍 RPC response: $response');

      if (response == null || (response is List && response.isEmpty)) {
        debugPrint('❌ Pass not found or invalid');

        // Don't log failed verification - already logged initial scan attempt
        debugPrint('📝 Verification failed - initial scan already logged');

        debugPrint('🔍 ========== QR SCAN DEBUG END ==========');
        return null;
      }

      Map<String, dynamic> passData;
      if (response is List && response.isNotEmpty) {
        passData = response.first as Map<String, dynamic>;
      } else if (response is Map<String, dynamic>) {
        passData = response;
      } else {
        debugPrint('❌ Unexpected response format');
        debugPrint('🔍 ========== QR SCAN DEBUG END ==========');
        return null;
      }

      final pass = PurchasedPass.fromJson(passData);
      debugPrint('✅ Pass verified: ${pass.passId}');

      // Don't log successful verification - already logged initial scan attempt
      // The scan will be updated when user completes validation
      debugPrint('✅ Verification successful - initial scan already logged');

      debugPrint('🔍 ========== QR SCAN DEBUG END ==========');
      return pass;
    } catch (e) {
      debugPrint('❌ Error verifying pass: $e');

      // Don't log error - already logged initial scan attempt
      debugPrint('📝 Verification error - initial scan already logged');

      debugPrint('🔍 ========== QR SCAN DEBUG END ==========');
      return null;
    }
  }

  /// Log scan activity in pass movement history
  static Future<void> _logScanActivity({
    required String passId,
    required String authorityType,
    required String scanPurpose,
    double? latitude,
    double? longitude,
    String? notes,
    String scanStatus = 'scan_completed',
  }) async {
    try {
      final metadata = <String, dynamic>{
        'scan_status': scanStatus,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (notes != null) metadata['notes'] = notes;
      if (latitude != null) metadata['latitude'] = latitude;
      if (longitude != null) metadata['longitude'] = longitude;

      // Try to call the log_local_authority_scan function
      final response = await _supabase.rpc('log_local_authority_scan', params: {
        'p_pass_id': passId,
        'p_authority_type': authorityType,
        'p_scan_purpose': scanPurpose,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_notes': notes,
        'p_metadata': metadata,
      });

      debugPrint(
          '📝 Logged $authorityType scan for pass $passId (Status: $scanStatus)');
      debugPrint('📝 Movement ID: $response');
      if (latitude != null && longitude != null) {
        debugPrint('📍 Location: $latitude, $longitude');
      }

      // Store the movement ID for potential updates
      _lastMovementId = response?.toString();
    } catch (e) {
      debugPrint('❌ Error logging scan activity: $e');

      // If the function doesn't exist, try a fallback approach
      if (e.toString().contains('function') &&
          e.toString().contains('does not exist')) {
        debugPrint(
            '⚠️ log_local_authority_scan function not found - creating fallback record');
        try {
          // Reconstruct metadata for fallback
          final fallbackMetadata = <String, dynamic>{
            'scan_status': scanStatus,
            'timestamp': DateTime.now().toIso8601String(),
          };
          if (notes != null) fallbackMetadata['notes'] = notes;
          if (latitude != null) fallbackMetadata['latitude'] = latitude;
          if (longitude != null) fallbackMetadata['longitude'] = longitude;

          // Fallback: Insert directly into pass_movements table
          await _supabase.from('pass_movements').insert({
            'pass_id': passId,
            'movement_type':
                'verification_scan', // Use a safer movement type for fallback
            'previous_status': 'unknown',
            'new_status': 'unknown',
            'entries_deducted': 0,
            'latitude': latitude,
            'longitude': longitude,
            'notes': notes,
            'metadata': fallbackMetadata,
            'processed_at': DateTime.now().toIso8601String(),
          });
          debugPrint('✅ Fallback scan record created in pass_movements');
        } catch (fallbackError) {
          debugPrint('❌ Fallback logging also failed: $fallbackError');
          // Don't rethrow - we don't want scan logging to break verification
        }
      } else {
        // Don't rethrow - we don't want scan logging to break verification
        debugPrint('⚠️ Continuing verification despite logging error');
      }
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
  static Future<String?> generateSecureCode(
    String passId, {
    String? borderId,
    double? latitude,
    double? longitude,
  }) async {
    try {
      debugPrint('🔍 Generating secure code for pass: $passId');

      final response =
          await _supabase.rpc('generate_secure_code_for_pass', params: {
        'p_pass_id': passId,
        'p_expiry_minutes': 15,
        'p_border_id': borderId,
        'p_latitude': latitude,
        'p_longitude': longitude,
      });

      if (response != null && response['success'] == true) {
        final secureCode = response['secure_code'] as String?;
        debugPrint('✅ Secure code generated and verification scan logged');
        return secureCode;
      } else {
        debugPrint('❌ Failed to generate secure code: ${response?['error']}');
        return null;
      }
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

  /// Update the last movement record with scan purpose and notes
  static Future<void> updateLastMovement({
    required String scanPurpose,
    String? notes,
  }) async {
    if (_lastMovementId == null) {
      debugPrint('⚠️ No movement ID to update');
      return;
    }

    try {
      debugPrint(
          '🔄 Updating movement $_lastMovementId with purpose: $scanPurpose');

      // Use the database function to update the movement record
      final result = await _supabase.rpc('update_movement_record', params: {
        'p_movement_id': _lastMovementId!,
        'p_scan_purpose': scanPurpose,
        'p_notes': notes,
      });

      debugPrint('✅ Movement updated successfully: $result');
      _lastMovementId = null; // Clear for next scan
    } catch (e) {
      debugPrint('❌ Error updating movement: $e');
    }
  }

  /// Get the last movement ID (for testing/debugging)
  static String? getLastMovementId() => _lastMovementId;

  /// Clear the last movement ID (for cleanup)
  static void clearLastMovementId() => _lastMovementId = null;

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
