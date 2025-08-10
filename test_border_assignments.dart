import 'package:flutter/foundation.dart';
import 'lib/services/border_official_service.dart';

/// Test script for border assignment functionality
/// This script demonstrates how to use the enhanced border official management system
class BorderAssignmentTest {
  /// Test assigning a border official to a border
  static Future<void> testAssignOfficialToBorder() async {
    try {
      debugPrint('🧪 Testing border official assignment...');

      // Example: Assign official to border
      await BorderOfficialService.assignOfficialToBorder(
        'example-profile-id',
        'example-border-id',
      );

      debugPrint('✅ Border official assigned successfully');
    } catch (e) {
      debugPrint('❌ Assignment failed: $e');
    }
  }

  /// Test checking if an official can process a border
  static Future<void> testCanProcessBorder() async {
    try {
      debugPrint('🧪 Testing border processing permissions...');

      final canProcess = await BorderOfficialService.canOfficialProcessBorder(
        'example-profile-id',
        'example-border-id',
      );

      debugPrint('✅ Can process border: $canProcess');
    } catch (e) {
      debugPrint('❌ Permission check failed: $e');
    }
  }

  /// Test getting assigned borders for an official
  static Future<void> testGetAssignedBorders() async {
    try {
      debugPrint('🧪 Testing get assigned borders...');

      final borders = await BorderOfficialService.getAssignedBordersForOfficial(
        'example-profile-id',
      );

      debugPrint('✅ Found ${borders.length} assigned borders');
      for (final border in borders) {
        debugPrint('  - ${border.name}');
      }
    } catch (e) {
      debugPrint('❌ Get assigned borders failed: $e');
    }
  }

  /// Test revoking border assignment
  static Future<void> testRevokeAssignment() async {
    try {
      debugPrint('🧪 Testing border assignment revocation...');

      await BorderOfficialService.revokeOfficialFromBorder(
        'example-profile-id',
        'example-border-id',
      );

      debugPrint('✅ Border assignment revoked successfully');
    } catch (e) {
      debugPrint('❌ Revocation failed: $e');
    }
  }

  /// Test getting border officials for a country
  static Future<void> testGetBorderOfficials() async {
    try {
      debugPrint('🧪 Testing get border officials for country...');

      final officials =
          await BorderOfficialService.getBorderOfficialsForCountry(
        'example-country-id',
      );

      debugPrint('✅ Found ${officials.length} border officials');
      for (final official in officials) {
        debugPrint(
            '  - ${official.fullName} (${official.borderCount} borders)');
      }
    } catch (e) {
      debugPrint('❌ Get border officials failed: $e');
    }
  }

  /// Run all tests
  static Future<void> runAllTests() async {
    debugPrint('🚀 Starting border assignment tests...');

    await testAssignOfficialToBorder();
    await testCanProcessBorder();
    await testGetAssignedBorders();
    await testGetBorderOfficials();
    await testRevokeAssignment();

    debugPrint('🏁 Border assignment tests completed');
  }
}

/// Example usage in a Flutter app
/// 
/// To test the border assignment functionality:
/// 
/// ```dart
/// // In your app initialization or test environment
/// await BorderAssignmentTest.runAllTests();
/// ```
/// 
/// Individual test methods can also be called separately:
/// 
/// ```dart
/// await BorderAssignmentTest.testCanProcessBorder();
/// ```