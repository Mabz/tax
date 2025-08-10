import 'package:flutter/foundation.dart';
import 'lib/services/pass_service.dart';

/// Debug helper for QR code validation issues
/// This script helps diagnose why QR codes are not being recognized
class QRValidationDebugger {
  /// Test QR code validation with detailed logging
  static Future<void> debugQRValidation(String qrData) async {
    debugPrint('🔍 === QR VALIDATION DEBUG SESSION ===');
    debugPrint('📱 QR Data: $qrData');
    debugPrint('📏 QR Data Length: ${qrData.length}');
    debugPrint('🔤 QR Data Type: ${qrData.runtimeType}');

    // Test different QR data formats
    await _testQRFormat(qrData);

    // Test PassService validation
    await _testPassServiceValidation(qrData);

    debugPrint('🏁 === DEBUG SESSION COMPLETE ===');
  }

  /// Test different QR data format interpretations
  static Future<void> _testQRFormat(String qrData) async {
    debugPrint('🧪 Testing QR data format...');

    // Check if it's JSON
    try {
      if (qrData.startsWith('{') && qrData.endsWith('}')) {
        debugPrint('✅ QR data appears to be JSON format');
      } else {
        debugPrint('ℹ️ QR data is not JSON format');
      }
    } catch (e) {
      debugPrint('⚠️ Error checking JSON format: $e');
    }

    // Check if it's pipe-delimited
    if (qrData.contains('|')) {
      debugPrint('✅ QR data contains pipe delimiters');
      final parts = qrData.split('|');
      debugPrint('📊 Found ${parts.length} pipe-delimited parts:');
      for (int i = 0; i < parts.length; i++) {
        debugPrint('  [$i]: ${parts[i]}');
      }
    } else {
      debugPrint('ℹ️ QR data does not contain pipe delimiters');
    }

    // Check if it's a simple ID
    if (qrData.length == 36 && qrData.contains('-')) {
      debugPrint('✅ QR data appears to be a UUID');
    } else if (qrData.length == 8 && RegExp(r'^[A-Z0-9]+$').hasMatch(qrData)) {
      debugPrint('✅ QR data appears to be a backup code');
    } else {
      debugPrint('ℹ️ QR data format is unknown or custom');
    }
  }

  /// Test PassService validation
  static Future<void> _testPassServiceValidation(String qrData) async {
    debugPrint('🧪 Testing PassService validation...');

    try {
      final pass = await PassService.validatePassByQRCode(qrData);

      if (pass != null) {
        debugPrint('✅ PassService validation successful!');
        debugPrint('📋 Pass Details:');
        debugPrint('  - Pass ID: ${pass.passId}');
        debugPrint('  - Description: ${pass.passDescription}');
        debugPrint('  - Status: ${pass.statusDisplay}');
        debugPrint('  - Authority ID: ${pass.authorityId}');
        debugPrint('  - Country: ${pass.countryName}');
        debugPrint('  - Border: ${pass.borderName}');
        debugPrint('  - Is Active: ${pass.isActive}');
        debugPrint('  - Entries Remaining: ${pass.entriesRemaining}');
      } else {
        debugPrint('❌ PassService validation returned null');
        debugPrint('💡 This could mean:');
        debugPrint('  - QR data format is not recognized');
        debugPrint('  - Pass does not exist in database');
        debugPrint('  - Pass is expired or inactive');
        debugPrint('  - Database connection issue');
      }
    } catch (e) {
      debugPrint('❌ PassService validation threw an error: $e');
      debugPrint('💡 This could indicate:');
      debugPrint('  - Network connectivity issue');
      debugPrint('  - Database schema mismatch');
      debugPrint('  - Authentication problem');
    }
  }

  /// Test backup code validation
  static Future<void> debugBackupCodeValidation(String backupCode) async {
    debugPrint('🔍 === BACKUP CODE VALIDATION DEBUG ===');
    debugPrint('🔢 Backup Code: $backupCode');
    debugPrint('📏 Code Length: ${backupCode.length}');

    // Validate format
    if (RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(backupCode)) {
      debugPrint('✅ Backup code format is correct');
    } else {
      debugPrint('❌ Backup code format is incorrect');
      debugPrint('💡 Expected format: XXXX-XXXX (8 characters with hyphen)');
    }

    try {
      final pass = await PassService.validatePassByBackupCode(backupCode);

      if (pass != null) {
        debugPrint('✅ Backup code validation successful!');
        debugPrint('📋 Pass Details:');
        debugPrint('  - Pass ID: ${pass.passId}');
        debugPrint('  - Description: ${pass.passDescription}');
        debugPrint('  - Status: ${pass.statusDisplay}');
      } else {
        debugPrint('❌ Backup code validation returned null');
      }
    } catch (e) {
      debugPrint('❌ Backup code validation error: $e');
    }

    debugPrint('🏁 === BACKUP CODE DEBUG COMPLETE ===');
  }

  /// Generate sample QR data for testing
  static Map<String, String> generateSampleQRData() {
    return {
      'json_format':
          '{"passId":"12345678-1234-1234-1234-123456789012","hash":"ABCD1234"}',
      'pipe_format':
          'passId:12345678-1234-1234-1234-123456789012|hash:ABCD1234',
      'uuid_format': '12345678-1234-1234-1234-123456789012',
      'backup_code': 'ABCD-1234',
    };
  }
}

/// Example usage:
/// 
/// ```dart
/// // Debug a specific QR code
/// await QRValidationDebugger.debugQRValidation(qrCodeData);
/// 
/// // Debug a backup code
/// await QRValidationDebugger.debugBackupCodeValidation('ABCD-1234');
/// 
/// // Test with sample data
/// final samples = QRValidationDebugger.generateSampleQRData();
/// for (final entry in samples.entries) {
///   debugPrint('Testing ${entry.key}:');
///   await QRValidationDebugger.debugQRValidation(entry.value);
/// }
/// ```