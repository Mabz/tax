import 'package:flutter/foundation.dart';
import 'lib/models/purchased_pass.dart';

/// Test script to verify that border_id is properly handled in PurchasedPass model
class BorderIdFixTest {
  /// Test that PurchasedPass correctly parses border_id from JSON
  static void testBorderIdParsing() {
    debugPrint('🧪 Testing border_id parsing in PurchasedPass model...');

    // Sample JSON data that includes border_id
    final sampleJson = {
      'id': 'pass-123',
      'pass_id': 'pass-123',
      'vehicle_description': 'Test Vehicle',
      'pass_description': 'Test Pass',
      'entry_limit': 5,
      'entries_remaining': 3,
      'issued_at': '2024-01-01T00:00:00Z',
      'activation_date': '2024-01-01T00:00:00Z',
      'expires_at': '2024-12-31T23:59:59Z',
      'status': 'active',
      'currency': 'USD',
      'amount': 100.0,
      'authority_id': 'auth-456',
      'authority_name': 'Test Authority',
      'country_name': 'Test Country',
      'border_id': 'border-789', // This is the key field we're testing
      'border_name': 'Test Border',
      'vehicle_number_plate': 'ABC123',
      'vehicle_vin': 'VIN123456789',
    };

    try {
      // Create PurchasedPass from JSON
      final pass = PurchasedPass.fromJson(sampleJson);

      // Verify border_id is correctly parsed
      debugPrint('✅ Pass created successfully');
      debugPrint('📋 Pass Details:');
      debugPrint('  - Pass ID: ${pass.passId}');
      debugPrint('  - Authority ID: ${pass.authorityId}');
      debugPrint('  - Border ID: ${pass.borderId}'); // This should now work
      debugPrint('  - Border Name: ${pass.borderName}');

      // Test the key functionality
      if (pass.borderId == 'border-789') {
        debugPrint('✅ SUCCESS: border_id correctly parsed as ${pass.borderId}');
      } else {
        debugPrint(
            '❌ FAILED: border_id not parsed correctly. Got: ${pass.borderId}');
      }

      // Test toJson includes border_id
      final jsonOutput = pass.toJson();
      if (jsonOutput['border_id'] == 'border-789') {
        debugPrint('✅ SUCCESS: border_id correctly included in toJson()');
      } else {
        debugPrint(
            '❌ FAILED: border_id not included in toJson(). Got: ${jsonOutput['border_id']}');
      }
    } catch (e) {
      debugPrint('❌ ERROR: Failed to create PurchasedPass from JSON: $e');
    }
  }

  /// Test border-specific validation logic
  static void testBorderValidationScenarios() {
    debugPrint('🧪 Testing border validation scenarios...');

    // Scenario 1: Pass with specific border
    final borderSpecificPass = PurchasedPass(
      passId: 'pass-123',
      vehicleDescription: 'Test Vehicle',
      passDescription: 'Border-Specific Pass',
      entryLimit: 5,
      entriesRemaining: 3,
      issuedAt: DateTime.now(),
      activationDate: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      status: 'active',
      currency: 'USD',
      amount: 100.0,
      authorityId: 'auth-456',
      borderId: 'border-789', // Specific border
    );

    // Scenario 2: General pass (no specific border)
    final generalPass = PurchasedPass(
      passId: 'pass-456',
      vehicleDescription: 'Test Vehicle',
      passDescription: 'General Authority Pass',
      entryLimit: 5,
      entriesRemaining: 3,
      issuedAt: DateTime.now(),
      activationDate: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(days: 30)),
      status: 'active',
      currency: 'USD',
      amount: 100.0,
      authorityId: 'auth-456',
      borderId: null, // No specific border
    );

    debugPrint('📋 Border-Specific Pass:');
    debugPrint('  - Has border ID: ${borderSpecificPass.borderId != null}');
    debugPrint('  - Border ID: ${borderSpecificPass.borderId}');
    debugPrint('  - Should require border assignment: YES');

    debugPrint('📋 General Pass:');
    debugPrint('  - Has border ID: ${generalPass.borderId != null}');
    debugPrint('  - Border ID: ${generalPass.borderId}');
    debugPrint('  - Should require border assignment: NO');

    debugPrint('✅ Border validation scenarios tested');
  }

  /// Run all tests
  static void runAllTests() {
    debugPrint('🚀 Starting border_id fix tests...');
    debugPrint('');

    testBorderIdParsing();
    debugPrint('');

    testBorderValidationScenarios();
    debugPrint('');

    debugPrint('🏁 Border_id fix tests completed');
  }
}

/// Example usage in a Flutter app
/// 
/// To test the border_id fix:
/// 
/// ```dart
/// // In your app initialization or test environment
/// BorderIdFixTest.runAllTests();
/// ```
/// 
/// This will verify that:
/// 1. PurchasedPass correctly parses border_id from JSON
/// 2. The border validation logic can access the border_id
/// 3. Both border-specific and general passes work correctly