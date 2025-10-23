import 'package:flutter/material.dart';
import 'lib/widgets/audit_activity_details_dialog.dart';
import 'lib/services/enhanced_border_service.dart';

void main() {
  runApp(const TestAuditActivityDetailsApp());
}

class TestAuditActivityDetailsApp extends StatelessWidget {
  const TestAuditActivityDetailsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audit Activity Details with Map Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TestAuditActivityDetailsScreen(),
    );
  }
}

class TestAuditActivityDetailsScreen extends StatelessWidget {
  const TestAuditActivityDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Activity Details with Map Test'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Test Audit Activity Details Dialog with Google Maps',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _showCheckInActivity(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Show Check-In Activity'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showCheckOutActivity(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Show Check-Out Activity'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showLocalAuthorityActivity(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Show Local Authority Scan'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Each dialog will show:\n'
              '• Google Maps with location marker\n'
              '• Color-coded markers by activity type\n'
              '• Interactive map controls\n'
              '• Location coordinates display',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckInActivity(BuildContext context) {
    final testMovement = PassMovement(
      movementId: 'test-checkin-001',
      passId: 'pass-12345',
      borderName: 'Ngwenya Border',
      officialName: 'John Doe',
      officialProfileImageUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
      movementType: 'check_in',
      latitude: -26.011614,
      longitude: 27.987028,
      processedAt: DateTime.now().subtract(const Duration(hours: 2)),
      entriesDeducted: 1,
      previousStatus: 'active',
      newStatus: 'checked_in',
      scanPurpose: 'border_entry',
      notes: 'Regular border entry scan',
      authorityType: 'border_official',
    );

    AuditActivityDetailsDialog.show(context, testMovement);
  }

  void _showCheckOutActivity(BuildContext context) {
    final testMovement = PassMovement(
      movementId: 'test-checkout-001',
      passId: 'pass-67890',
      borderName: 'Ngwenya Border',
      officialName: 'Jane Smith',
      officialProfileImageUrl:
          'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150&h=150&fit=crop&crop=face',
      movementType: 'check_out',
      latitude: -26.012000,
      longitude: 27.987500,
      processedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      entriesDeducted: 0,
      previousStatus: 'checked_in',
      newStatus: 'checked_out',
      scanPurpose: 'border_exit',
      notes: 'Exit scan completed successfully',
      authorityType: 'border_official',
    );

    AuditActivityDetailsDialog.show(context, testMovement);
  }

  void _showLocalAuthorityActivity(BuildContext context) {
    final testMovement = PassMovement(
      movementId: 'test-local-001',
      passId: 'pass-11111',
      borderName: 'Unknown Border',
      officialName: 'Mike Johnson',
      officialProfileImageUrl:
          'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
      movementType: 'local_authority_scan',
      latitude: -26.020000,
      longitude: 27.990000,
      processedAt: DateTime.now().subtract(const Duration(hours: 1)),
      entriesDeducted: 0,
      previousStatus: 'active',
      newStatus: 'verified',
      scanPurpose: 'roadblock_inspection',
      notes: 'Routine roadblock verification',
      authorityType: 'local_authority',
    );

    AuditActivityDetailsDialog.show(context, testMovement);
  }
}
