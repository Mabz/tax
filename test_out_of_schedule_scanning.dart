import 'package:flutter/material.dart';
import 'lib/screens/border_configuration_screen.dart';
import 'lib/widgets/schedule_confirmation_dialog.dart';
import 'lib/services/schedule_validation_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Out-of-Schedule Scanning Test',
      theme: ThemeData(
        primarySwatch: Colors.purple,
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
        title: const Text('Out-of-Schedule Scanning Test'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Out-of-Schedule Scanning Implementation:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Feature Overview Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.purple.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Features Implemented:',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                        '✅ Border configuration for out-of-schedule scans'),
                    const Text('✅ Schedule validation during pass scanning'),
                    const Text(
                        '✅ Confirmation dialog for out-of-schedule scans'),
                    const Text('✅ Audit logging for compliance'),
                    const Text(
                        '✅ Integration with existing pass scanning flow'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Navigation Buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Components:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const BorderConfigurationScreen(
                              authorityId: 'test-authority',
                              authorityName: 'Test Authority',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Border Configuration Screen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        _showTestConfirmationDialog(context);
                      },
                      icon: const Icon(Icons.warning_amber),
                      label: const Text('Test Schedule Confirmation Dialog'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Implementation Flow Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.show_chart, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Scanning Flow:',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('1. QR Code detected → Pass verified'),
                    const Text(
                        '2. Schedule validation (Border Officials only)'),
                    const Text('3. If within schedule → Continue normally'),
                    const Text('4. If outside schedule → Check border setting'),
                    const Text('5. If allowed → Show confirmation dialog'),
                    const Text('6. If confirmed → Log audit + Continue scan'),
                    const Text('7. If blocked → Show error message'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Database Changes Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storage, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Database Changes:',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                        '• Added allow_out_of_schedule_scans column to borders table'),
                    const Text(
                        '• Uses existing audit_logs table for compliance tracking'),
                    const Text(
                        '• Uses existing schedule tables for validation'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTestConfirmationDialog(BuildContext context) {
    // Create a mock validation result for testing
    final mockValidationResult = ScheduleValidationResult.allowed(
      isWithinSchedule: false,
      todaySchedule: [
        {
          'start_time': '08:00',
          'end_time': '16:00',
          'border_name': 'Ngwenya Border',
          'assignment_type': 'primary',
          'template_name': 'Standard Weekday Schedule',
        },
        {
          'start_time': '18:00',
          'end_time': '22:00',
          'border_name': 'Ngwenya Border',
          'assignment_type': 'backup',
          'template_name': 'Evening Coverage',
        },
      ],
      borderId: 'test-border-id',
      borderName: 'Ngwenya Border',
    );

    ScheduleConfirmationDialog.show(
      context: context,
      validationResult: mockValidationResult,
    ).then((confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirmed
                ? '✅ User confirmed out-of-schedule scan'
                : '❌ User cancelled out-of-schedule scan',
          ),
          backgroundColor: confirmed ? Colors.green : Colors.red,
        ),
      );
    });
  }
}
