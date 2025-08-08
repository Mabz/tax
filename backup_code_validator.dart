import 'package:flutter/foundation.dart';

/// Standalone Backup Code Validator
/// This function validates and cleans backup codes for testing purposes

class BackupCodeValidator {
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

  /// Test function to validate multiple backup codes
  static void testBackupCodes() {
    debugPrint('\n🧪 Testing Backup Code Validator\n');

    final testCases = [
      'ABCD-1234', // Valid with hyphen
      'ABCD1234', // Valid without hyphen
      'abcd-1234', // Valid lowercase (should be converted)
      'ABCD 1234', // Valid with space
      ' ABCD-1234 ', // Valid with extra spaces
      'ABCD-12345', // Invalid - too long
      'ABCD-123', // Invalid - too short
      'ABCD-12@4', // Invalid - special character
      '', // Invalid - empty
      '   ', // Invalid - only spaces
      'ABCD-', // Invalid - incomplete
      'WXYZ9876', // Valid - all caps and numbers
    ];

    for (int i = 0; i < testCases.length; i++) {
      debugPrint('Test ${i + 1}: ${testCases[i]}');
      final result = validateAndCleanBackupCode(testCases[i]);
      debugPrint('Result: ${result ?? "INVALID"}');
      debugPrint('---');
    }
  }
}

// Main function for online testing
void main() {
  BackupCodeValidator.testBackupCodes();

  // Interactive test
  debugPrint('\n🎯 Interactive Test:');
  debugPrint('Enter a backup code to test:');

  // Simulate some user inputs for testing
  final userInputs = ['ABCD-1234', 'xyz9-8765', 'INVALID@CODE'];

  for (final input in userInputs) {
    debugPrint('\nUser input: "$input"');
    final result = BackupCodeValidator.validateAndCleanBackupCode(input);
    if (result != null) {
      debugPrint('✅ Success! Clean code for database lookup: "$result"');
    } else {
      debugPrint('❌ Invalid backup code');
    }
  }
}
