import 'package:flutter/material.dart';
import 'lib/widgets/enhanced_border_officials_heat_map.dart';
import 'lib/services/border_officials_service_simple.dart';
import 'lib/models/border.dart' as border_model;

void main() {
  runApp(const TestEnhancedHeatMapApp());
}

class TestEnhancedHeatMapApp extends StatelessWidget {
  const TestEnhancedHeatMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enhanced Heat Map Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TestEnhancedHeatMapScreen(),
    );
  }
}

class TestEnhancedHeatMapScreen extends StatefulWidget {
  const TestEnhancedHeatMapScreen({super.key});

  @override
  State<TestEnhancedHeatMapScreen> createState() =>
      _TestEnhancedHeatMapScreenState();
}

class _TestEnhancedHeatMapScreenState extends State<TestEnhancedHeatMapScreen> {
  late List<ScanLocationData> _mockScanLocations;
  late border_model.Border _mockBorder;

  @override
  void initState() {
    super.initState();
    _createMockData();
  }

  void _createMockData() {
    // Mock border location (example: US-Mexico border near San Diego)
    _mockBorder = border_model.Border(
      id: 'test-border-1',
      name: 'San Ysidro Border Crossing',
      description: 'Main border crossing between San Diego and Tijuana',
      authorityId: 'test-authority',
      borderTypeId: 'land-crossing',
      isActive: true,
      latitude: 32.5422, // San Ysidro coordinates
      longitude: -117.0307,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Mock scan locations with some outliers
    _mockScanLocations = [
      // Normal locations (within 5km of border)
      ScanLocationData(
        officialId: 'officer-rodriguez-001',
        officialName: 'Officer Rodriguez',
        latitude: 32.5422, // At border
        longitude: -117.0307,
        scanCount: 15,
        lastScanTime: DateTime.now().subtract(const Duration(hours: 2)),
        borderName: 'San Ysidro Border Crossing',
        distanceFromBorderKm: 0.0,
        isOutlier: false,
      ),
      ScanLocationData(
        officialId: 'officer-johnson-002',
        officialName: 'Officer Johnson',
        latitude: 32.5400, // 0.3km from border
        longitude: -117.0320,
        scanCount: 12,
        lastScanTime: DateTime.now().subtract(const Duration(hours: 1)),
        borderName: 'San Ysidro Border Crossing',
        distanceFromBorderKm: 0.3,
        isOutlier: false,
      ),
      ScanLocationData(
        officialId: 'officer-martinez-003',
        officialName: 'Officer Martinez',
        latitude: 32.5450, // 1.2km from border
        longitude: -117.0280,
        scanCount: 8,
        lastScanTime: DateTime.now().subtract(const Duration(minutes: 30)),
        borderName: 'San Ysidro Border Crossing',
        distanceFromBorderKm: 1.2,
        isOutlier: false,
      ),
      ScanLocationData(
        officialId: 'officer-chen-004',
        officialName: 'Officer Chen',
        latitude: 32.5380, // 2.1km from border
        longitude: -117.0350,
        scanCount: 6,
        lastScanTime: DateTime.now().subtract(const Duration(hours: 3)),
        borderName: 'San Ysidro Border Crossing',
        distanceFromBorderKm: 2.1,
        isOutlier: false,
      ),
      ScanLocationData(
        officialId: 'officer-williams-005',
        officialName: 'Officer Williams',
        latitude: 32.5500, // 4.8km from border
        longitude: -117.0200,
        scanCount: 4,
        lastScanTime: DateTime.now().subtract(const Duration(hours: 4)),
        borderName: 'San Ysidro Border Crossing',
        distanceFromBorderKm: 4.8,
        isOutlier: false,
      ),

      // Outlier locations (>5km from border)
      ScanLocationData(
        officialId: 'officer-thompson-006',
        officialName: 'Officer Thompson',
        latitude: 32.5800, // 7.2km from border (potential security concern)
        longitude: -117.0100,
        scanCount: 3,
        lastScanTime: DateTime.now().subtract(const Duration(hours: 6)),
        borderName: 'San Ysidro Border Crossing',
        distanceFromBorderKm: 7.2,
        isOutlier: true,
      ),
      ScanLocationData(
        officialId: 'officer-davis-007',
        officialName: 'Officer Davis',
        latitude: 32.4900, // 8.5km from border (potential security concern)
        longitude: -117.0500,
        scanCount: 2,
        lastScanTime: DateTime.now().subtract(const Duration(hours: 8)),
        borderName: 'San Ysidro Border Crossing',
        distanceFromBorderKm: 8.5,
        isOutlier: true,
      ),
      ScanLocationData(
        officialId: 'officer-garcia-008',
        officialName: 'Officer Garcia',
        latitude: 32.6000, // 12.1km from border (major security concern)
        longitude: -116.9800,
        scanCount: 1,
        lastScanTime: DateTime.now().subtract(const Duration(hours: 12)),
        borderName: 'San Ysidro Border Crossing',
        distanceFromBorderKm: 12.1,
        isOutlier: true,
      ),

      // High activity location
      ScanLocationData(
        officialId: 'officer-anderson-009',
        officialName: 'Officer Anderson',
        latitude: 32.5440, // 0.8km from border, high activity
        longitude: -117.0290,
        scanCount: 25,
        lastScanTime: DateTime.now().subtract(const Duration(minutes: 15)),
        borderName: 'San Ysidro Border Crossing',
        distanceFromBorderKm: 0.8,
        isOutlier: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced Heat Map Test'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Data Overview',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text('Border: ${_mockBorder.name}'),
                    Text('Total Scan Locations: ${_mockScanLocations.length}'),
                    Text(
                        'Normal Locations: ${_mockScanLocations.where((l) => !l.isOutlier).length}'),
                    Text(
                        'Outlier Locations: ${_mockScanLocations.where((l) => l.isOutlier).length}'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'This test shows scan locations around San Ysidro Border Crossing. '
                        'Red markers indicate outlier locations (>5km from border) that may require investigation.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: EnhancedBorderOfficialsHeatMap(
                  scanLocations: _mockScanLocations,
                  selectedBorder: _mockBorder,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
