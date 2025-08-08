import 'dart:io';

import 'package:flutter/foundation.dart';

/// Interactive backup code validator for testing
class InteractiveBackupValidator {
  /// Validates and cleans a backup code input
  static String? validateAndCleanBackupCode(String backupCode) {
    try {
      debugPrint('🔍 Input backup code: "$backupCode"');

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
      debugPrint('🧹 Cleaned backup code: "$cleanCode"');

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

  /// Simulate database lookup
  static bool simulateDatabaseLookup(String cleanCode) {
    // Mock database with some test codes
    final mockDatabase = [
      'ABCD1234',
      'WXYZ9876',
      'TEST0001',
      'DEMO5678',
      'PASS1234',
      'CODE5678',
      'HASH9999',
      'VALID123'
    ];

    debugPrint('🔍 Searching database for pass_hash = "$cleanCode"...');

    if (mockDatabase.contains(cleanCode)) {
      debugPrint('✅ Pass found in database!');
      debugPrint('📋 Pass details would be returned to the app');
      return true;
    } else {
      debugPrint('❌ No pass found with hash: "$cleanCode"');
      debugPrint('💡 Available test codes: ${mockDatabase.join(', ')}');
      return false;
    }
  }
}

void main() async {
  debugPrint('🎯 Interactive Backup Code Validator');
  debugPrint('=====================================');
  debugPrint('Enter backup codes to test the validation logic');
  debugPrint('Available test codes: ABCD1234, WXYZ9876, TEST0001, DEMO5678');
  debugPrint(
      'You can enter them with or without hyphens: ABCD-1234 or ABCD1234');
  debugPrint('Type "quit" to exit\n');

  while (true) {
    stdout.write('Enter backup code: ');
    final input = stdin.readLineSync();

    if (input == null || input.toLowerCase() == 'quit') {
      debugPrint('👋 Goodbye!');
      break;
    }

    if (input.trim().isEmpty) {
      debugPrint('❌ Please enter a backup code\n');
      continue;
    }

    debugPrint('\n${'=' * 50}');
    debugPrint('Testing: "$input"');
    debugPrint('-' * 50);

    // Step 1: Validate and clean the code
    final cleanCode =
        InteractiveBackupValidator.validateAndCleanBackupCode(input);

    if (cleanCode == null) {
      debugPrint('💥 VALIDATION FAILED - Invalid backup code format');
    } else {
      debugPrint('✅ Format validation passed!');

      // Step 2: Simulate database lookup
      final found =
          InteractiveBackupValidator.simulateDatabaseLookup(cleanCode);

      if (found) {
        debugPrint('🎉 SUCCESS - Pass would be loaded in the app');
      } else {
        debugPrint('💥 FAILED - "Backup code not found" error would be shown');
      }
    }

    debugPrint('=' * 50 + '\n');
  }
}
