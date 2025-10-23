import 'package:flutter/material.dart';
import 'lib/widgets/enhanced_official_audit_dialog.dart';
import 'lib/services/border_officials_service_simple.dart' as officials;
import 'lib/models/audit_trail_arguments.dart';

void main() {
  runApp(const TestEnhancedAuditDialogApp());
}

class TestEnhancedAuditDialogApp extends StatelessWidget {
  const TestEnhancedAuditDialogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enhanced Audit Dialog with Map Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TestEnhancedAuditDialogScreen(),
    );
  }
}

class TestEnhancedAuditDialogScreen extends StatelessWidget {
  const TestEnhancedAuditDialogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced Audit Dialog with Map Test'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Test Enhanced Official Audit Dialog with Google Maps',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _showEnhancedAuditDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Show Enhanced Audit Dialog with Map'),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will show the enhanced audit dialog with:\n'
              '• Google Maps location display\n'
              '• Border marker and search radius\n'
              '• Location information section\n'
              '• Filtered audit activities',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showEnhancedAuditDialog(BuildContext context) {
    // Create test official data
    final testOfficial = officials.OfficialPerformance(
      officialId: 'test-official-123',
      officialName: 'John Doe',
      profilePictureUrl: null,
      isCurrentlyActive: true,
      totalScans: 45,
      successfulScans: 42,
      failedScans: 3,
      successRate: 93.3,
      averageScansPerHour: 5.2,
      averageProcessingTimeMinutes: 2.1,
      lastScanTime: DateTime.now().subtract(const Duration(hours: 2)),
      lastBorderLocation: 'Ngwenya Border',
      hourlyBreakdown: [],
      scanTrend: [],
    );

    // Create test coordinates for Ngwenya Border
    final testCoordinates = LocationBounds(
      centerLat: -26.011614,
      centerLng: 27.987028,
      radiusKm: 5.0,
    );

    // Show the enhanced dialog with map
    EnhancedOfficialAuditDialog.show(
      context,
      testOfficial,
      borderName: 'Ngwenya Border',
      timeframe: '7d',
      filteredBorderId: 'ngwenya-border-001',
      coordinates: testCoordinates,
      showBorderEntriesOnly: true,
      showOutliersOnly: false,
    );
  }
}
