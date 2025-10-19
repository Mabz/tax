// Test file to isolate Border Schedules menu issue
import 'package:flutter/material.dart';
import 'lib/screens/border_schedule_management_screen.dart';

class TestBorderSchedulesMenu extends StatelessWidget {
  const TestBorderSchedulesMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Border Schedules')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Testing Border Schedules Integration'),
            const SizedBox(height: 20),

            // Test 1: Simple button
            ElevatedButton(
              onPressed: () {
                debugPrint('🧪 Test 1: Simple navigation');
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        const BorderScheduleManagementScreen(),
                  ),
                );
              },
              child: const Text('Test 1: Open Border Schedules (No params)'),
            ),

            const SizedBox(height: 10),

            // Test 2: With parameters
            ElevatedButton(
              onPressed: () {
                debugPrint('🧪 Test 2: Navigation with parameters');
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BorderScheduleManagementScreen(
                      authorityId: 'test-authority-id',
                      authorityName: 'Test Authority',
                    ),
                  ),
                );
              },
              child: const Text('Test 2: Open Border Schedules (With params)'),
            ),

            const SizedBox(height: 10),

            // Test 3: Check if class exists
            ElevatedButton(
              onPressed: () {
                debugPrint('🧪 Test 3: Class type check');
                final screen = BorderScheduleManagementScreen();
                debugPrint(
                    '✅ BorderScheduleManagementScreen created: ${screen.runtimeType}');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Class exists: ${screen.runtimeType}')),
                );
              },
              child: const Text('Test 3: Verify Class Exists'),
            ),
          ],
        ),
      ),
    );
  }
}

// Usage: Add this to your app to test
// Navigator.push(context, MaterialPageRoute(builder: (context) => TestBorderSchedulesMenu()));
