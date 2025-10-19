import 'package:flutter/material.dart';
import '../utils/date_utils.dart' as date_utils;

/// Test the Pass ID and improved date formatting
class TestPassIdAndDates extends StatelessWidget {
  const TestPassIdAndDates({super.key});

  @override
  Widget build(BuildContext context) {
    final testDates = [
      DateTime.now(), // Today
      DateTime.now().add(const Duration(days: 1)), // Tomorrow
      DateTime.now().add(const Duration(days: 3)), // This week
      DateTime.now().add(const Duration(days: 10)), // Next week
      DateTime(2024, 11, 25), // Specific date
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Pass ID & Dates'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
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
                      'Implemented Changes:',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                        '✅ Pass ID displayed in corner of each pass card'),
                    const Text(
                        '✅ Date format simplified (removed hours/minutes)'),
                    const Text(
                        '✅ Shows "Today", "Tomorrow", or "25 Nov" format'),
                    const Text('✅ Pass cards are tappable for details'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Date Format Examples:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ...testDates.map((date) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.login,
                        color: Colors.green.shade700,
                      ),
                    ),
                    title: const Text(
                      'General - Test Vehicle',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Check-in: ${date_utils.DateUtils.formatListDate(date)}',
                    ),
                    trailing: const Text(
                      '\$50',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                )),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To See the Changes:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Go to Border Analytics → Forecast tab'),
                    const Text(
                        '2. Select a date filter (Today, Tomorrow, etc.)'),
                    const Text('3. Look for Pass IDs in the top-right corner'),
                    const Text('4. Notice simplified dates (no hours/minutes)'),
                    const Text('5. Tap passes to see detailed information'),
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
