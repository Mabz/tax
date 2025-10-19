import 'package:flutter/material.dart';
import 'lib/screens/authority_validation_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schedule Validation Fix Test',
      theme: ThemeData(
        primarySwatch: Colors.red,
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
        title: const Text('Schedule Validation Fix'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Problem Description Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bug_report,
                            color: Colors.red.shade700, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Issues Fixed',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Original Problems:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                              '❌ Schedule validation not working - border ID was null'),
                          const Text(
                              '❌ Could scan regardless of schedule when border setting was false'),
                          const Text(
                              '❌ No confirmation dialog when border allows out-of-schedule scans'),
                          const Text(
                              '❌ No audit logging for out-of-schedule scans'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Solution Card
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
                          'Solutions Implemented',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                        '✅ Added border selection for officials with multiple borders'),
                    const Text(
                        '✅ Auto-select border for officials with single border assignment'),
                    const Text(
                        '✅ Pass correct border ID to schedule validation service'),
                    const Text('✅ Prevent scanning without border selection'),
                    const Text(
                        '✅ Proper schedule validation with border settings'),
                    const Text(
                        '✅ Show confirmation dialog for out-of-schedule scans'),
                    const Text('✅ Audit logging for out-of-schedule scans'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // How It Works Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue.shade700, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'How Schedule Validation Works Now',
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
                            '1. Border Selection:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Text('   • Single border: Auto-selected'),
                          const Text('   • Multiple borders: User must select'),
                          const SizedBox(height: 8),
                          const Text(
                            '2. Schedule Validation:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Text(
                              '   • Check if current time is within scheduled slots'),
                          const Text(
                              '   • Use selected border\'s allow_out_of_schedule_scans setting'),
                          const SizedBox(height: 8),
                          const Text(
                            '3. Decision Logic:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Text('   • Within schedule: Allow scan'),
                          const Text(
                              '   • Outside + border allows: Show confirmation dialog'),
                          const Text(
                              '   • Outside + border blocks: Block scan with error'),
                          const Text(
                              '   • Confirmed out-of-schedule: Log audit + allow scan'),
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
                      'Test Schedule Validation:',
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
                                const AuthorityValidationScreen(
                              role: AuthorityRole.borderOfficial,
                              currentCountryId: 'test-country',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Test Border Official Scanning'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Testing scenarios:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Text(
                        '1. Multiple borders: Should show border selection'),
                    const Text('2. Single border: Should auto-select'),
                    const Text(
                        '3. Outside schedule + border allows: Show confirmation'),
                    const Text(
                        '4. Outside schedule + border blocks: Show error'),
                    const Text('5. Within schedule: Allow scan normally'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Database Requirements Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.storage,
                            color: Colors.purple.shade700, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Database Requirements',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                        '✅ borders.allow_out_of_schedule_scans column (already added)'),
                    const Text(
                        '✅ border_official_borders table (should exist)'),
                    const Text(
                        '✅ official_schedule_assignments table (should exist)'),
                    const Text('✅ schedule_time_slots table (should exist)'),
                    const Text('✅ audit_logs table (should exist)'),
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
