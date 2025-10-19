import 'package:flutter/material.dart';
import 'lib/widgets/border_management_menu.dart';
import 'lib/screens/border_officials_screen.dart';
import 'lib/screens/border_analytics_screen.dart';
import 'lib/screens/border_schedule_management_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Border Management Theme Test',
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
        title: const Text('Border Management Theme Test'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Updated Border Management Components:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Border Management Menu
            const BorderManagementMenu(
              selectedAuthorityId: 'test-authority',
              selectedAuthorityName: 'Test Authority',
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
                      'Test Purple Theme Screens:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BorderOfficialsScreen(
                              authorityId: 'test-authority',
                              authorityName: 'Test Authority',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Border Officials (Purple Theme)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BorderAnalyticsScreen(
                              authorityId: 'test-authority',
                              authorityName: 'Test Authority',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.analytics),
                      label: const Text('Border Analytics (Purple Theme)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const BorderScheduleManagementScreen(
                              authorityId: 'test-authority',
                              authorityName: 'Test Authority',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.schedule),
                      label: const Text('Border Schedules (Purple Theme)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
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
