import 'package:flutter/material.dart';
import 'lib/services/enhanced_border_service.dart';
import 'lib/widgets/audit_activity_details_dialog.dart';

/// Test file to verify vehicle and owner details in audit trail
///
/// This test demonstrates the enhanced audit functionality that now includes:
/// 1. Vehicle Information (registration, make, model, year, color, VIN, etc.)
/// 2. Owner Information (complete owner details with popup)
///
/// Key improvements made:
/// - Added passId field to PassMovement class
/// - Updated audit dialog to fetch pass details using correct pass ID
/// - Enhanced audit activity details dialog to show vehicle and owner sections
/// - Added fallback message when pass data is not available

void main() {
  runApp(const AuditTestApp());
}

class AuditTestApp extends StatelessWidget {
  const AuditTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audit Vehicle/Owner Details Test',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const AuditTestScreen(),
    );
  }
}

class AuditTestScreen extends StatelessWidget {
  const AuditTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Trail - Vehicle & Owner Details'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.assignment,
              size: 64,
              color: Colors.indigo,
            ),
            const SizedBox(height: 16),
            const Text(
              'Audit Trail Enhancement Complete',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'The audit trail now includes enhanced vehicle and owner details with improved UI, valid days calculation, color-coded status, and pass movement history.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 32),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          'Features Added',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _FeatureItem(
                      icon: Icons.directions_car,
                      title: 'Vehicle Information',
                      description:
                          'Registration, make, model, year, color, VIN (no description)',
                    ),
                    const _FeatureItem(
                      icon: Icons.person,
                      title: 'Owner Information',
                      description: 'Complete owner details with popup dialog',
                    ),
                    const _FeatureItem(
                      icon: Icons.timeline,
                      title: 'Pass Movement History',
                      description: 'Button to view all movements for this pass',
                    ),
                    const _FeatureItem(
                      icon: Icons.calendar_today,
                      title: 'Valid Days Calculation',
                      description:
                          'Shows remaining/expired days with total validity',
                    ),
                    const _FeatureItem(
                      icon: Icons.traffic,
                      title: 'Color-Coded Vehicle Status',
                      description:
                          'Visual status indicators with icons and colors',
                    ),
                    const _FeatureItem(
                      icon: Icons.remove_circle_outline,
                      title: 'Entry Deduction Tracking',
                      description:
                          'Shows when entries were deducted in movement history',
                    ),
                    const _FeatureItem(
                      icon: Icons.local_police,
                      title: 'Local Authority Scan Purpose',
                      description:
                          'Proper formatting of scan purposes (e.g., Routine Check)',
                    ),
                    const _FeatureItem(
                      icon: Icons.location_on,
                      title: 'Smart Border Name Display',
                      description:
                          '"Unknown Border" shows as "Local Authority" for local scans',
                    ),
                    const _FeatureItem(
                      icon: Icons.note,
                      title: 'Notes Display',
                      description:
                          'Shows notes when populated in the note column',
                    ),
                    const _FeatureItem(
                      icon: Icons.swap_horiz,
                      title: 'Contextual Status',
                      description:
                          'Shows entries deducted instead of generic "active" status',
                    ),
                    const _FeatureItem(
                      icon: Icons.directions_car,
                      title: 'Vehicle Details',
                      description:
                          'Shows registration, make, and model briefly in audit trail',
                    ),
                    const _FeatureItem(
                      icon: Icons.confirmation_number,
                      title: 'Pass ID Display',
                      description:
                          'Shows Pass ID (first 8 chars) for tracking purposes',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showTestDialog(context),
              icon: const Icon(Icons.visibility),
              label: const Text('Test Audit Dialog'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTestDialog(BuildContext context) {
    // Create a sample PassMovement for testing
    final testMovement = PassMovement(
      movementId: 'test-movement-123',
      passId: 'test-pass-456', // This will enable vehicle/owner details
      borderName: 'Ngwenya Border',
      officialName: 'Bobby',
      movementType: 'check_in',
      latitude: -26.011614,
      longitude: 27.987028,
      processedAt: DateTime.now().subtract(const Duration(hours: 2)),
      entriesDeducted: 1,
      previousStatus: 'active',
      newStatus: 'active',
      scanPurpose: 'Vehicle Check-In',
      authorityType: 'border_authority',
      vehicleDescription: 'Toyota Corolla',
      vehicleRegistration: 'ABC123GP',
      vehicleMake: 'Toyota',
      vehicleModel: 'Corolla',
    );

    AuditActivityDetailsDialog.show(context, testMovement);
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.indigo.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
