import 'package:flutter/foundation.dart';

/// Test the backup code validation function from PassService
/// This simulates the validation logic without database dependency

class TestPassService {
  /// Validates and cleans a backup code input
  /// Returns the cleaned code if valid, null if invalid
  static String? validateAndCleanBackupCode(String backupCode) {
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

  /// Simulate the full validation process
  static Future<bool> simulateValidatePassByBackupCode(
      String backupCode) async {
    try {
      debugPrint('\n🔍 Starting pass validation for: "$backupCode"');

      // Use the validation function to clean and validate the backup code
      final cleanCode = validateAndCleanBackupCode(backupCode);
      if (cleanCode == null) {
        debugPrint('❌ Invalid backup code format - validation failed');
        return false;
      }

      debugPrint('✅ Backup code validation passed');
      debugPrint('🔍 Would search database for pass_hash = "$cleanCode"');

      // Simulate database lookup (in real app, this would query Supabase)
      debugPrint('📊 Simulating database query...');
      await Future.delayed(
          const Duration(milliseconds: 500)); // Simulate network delay

      // For testing, let's say some codes exist in our "database"
      final mockDatabase = ['ABCD1234', 'WXYZ9876', 'TEST0001', 'DEMO5678'];

      if (mockDatabase.contains(cleanCode)) {
        debugPrint('✅ Pass found in database!');
        debugPrint('📋 Would return PurchasedPass object with pass details');
        return true;
      } else {
        debugPrint('❌ No pass found with hash: "$cleanCode"');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error during validation: $e');
      return false;
    }
  }
}

void main() async {
  debugPrint('🧪 Testing PassService Backup Code Validation\n');

  final testCases = [
    'ABCD-1234', // Should find in mock database
    'WXYZ-9876', // Should find in mock database
    'TEST-0001', // Should find in mock database
    'DEMO-5678', // Should find in mock database
    'NOTF-OUND', // Valid format but not in database
    'INVALID@', // Invalid format
    'TOOLONG123', // Too long
    'SHORT', // Too short
    '', // Empty
  ];

  for (int i = 0; i < testCases.length; i++) {
    debugPrint('=' * 50);
    debugPrint('Test ${i + 1}: "${testCases[i]}"');

    final result =
        await TestPassService.simulateValidatePassByBackupCode(testCases[i]);

    if (result) {
      debugPrint('🎉 VALIDATION SUCCESS - Pass would be returned to UI');
    } else {
      debugPrint('💥 VALIDATION FAILED - Error message would be shown to user');
    }

    debugPrint('');
  }

  debugPrint('=' * 50);
  debugPrint('✅ All tests completed!');
}
