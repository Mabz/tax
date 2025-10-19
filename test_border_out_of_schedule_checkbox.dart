import 'package:flutter/material.dart';
import 'lib/screens/border_management_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Border Out-of-Schedule Checkbox Test',
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: const TestHomeScreen(),
    );
  }
}

class TestHomeScreen extends StatelessWidget {
  const TestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Border Out-of-Schedule Checkbox Test'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Implementation Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green.shade700, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Implementation Complete',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                        '✅ Added allowOutOfScheduleScans field to Border model'),
                    const Text('✅ Updated BorderService.createBorder() method'),
                    const Text('✅ Updated BorderService.updateBorder() method'),
                    const Text('✅ Added checkbox to border editing dialog'),
                    const Text(
                        '✅ Integrated with existing border management screen'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Feature Description Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule_outlined,
                            color: Colors.orange.shade700, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Allow Out-of-Schedule Scans',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This checkbox allows administrators to configure whether border officials can scan passes outside their scheduled time slots.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.orange.shade700, size: 16),
                              const SizedBox(width: 6),
                              const Text(
                                'How it works:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                              '• When enabled: Officials can scan outside schedule with confirmation'),
                          const Text(
                              '• When disabled: Officials cannot scan outside their scheduled times'),
                          const Text(
                              '• All out-of-schedule scans are logged for audit purposes'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Button Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test the Implementation:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BorderManagementScreen(
                              selectedCountry: {
                                'id': 'test-country-id',
                                'name': 'Test Country',
                              },
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Open Border Management'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'In the Border Management screen:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Text(
                        '1. Notice the out-of-schedule setting in the border list'),
                    const Text('2. Click on any border to edit it'),
                    const Text(
                        '3. "Allow Out-of-Schedule Scans" toggle is now above "Active"'),
                    const Text('4. Toggle it on/off to test the functionality'),
                    const Text('5. Save the border to persist the setting'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Database Migration Reminder
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storage,
                            color: Colors.blue.shade700, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Database Migration Required',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Before testing, run the database migration:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ALTER TABLE borders ADD COLUMN allow_out_of_schedule_scans BOOLEAN DEFAULT false;',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
