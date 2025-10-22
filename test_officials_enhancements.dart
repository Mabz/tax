import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Officials Enhancements Test',
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      home: TestOfficialsScreen(),
    );
  }
}

class TestOfficialsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enhanced Officials Features'),
        backgroundColor: Colors.purple.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enhanced Officials Features Implemented:',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildFeatureCard(
              'Date Filter Consistency',
              'Officials data now follows the same date filter as Analytics tab',
              Icons.date_range,
              Colors.blue,
            ),
            _buildFeatureCard(
              'Profile Pictures',
              'Officials now show profile pictures from authority_profiles table',
              Icons.account_circle,
              Colors.green,
            ),
            _buildFeatureCard(
              'Bar Charts',
              'Added scan activity and revenue trend charts for each official',
              Icons.bar_chart,
              Colors.orange,
            ),
            _buildFeatureCard(
              'Removed Success Rate',
              'Success rate removed from detailed stats as requested',
              Icons.remove_circle,
              Colors.red,
            ),
            _buildFeatureCard(
              'Enhanced Data',
              'Officials now show position, department, and proper names',
              Icons.person,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
      String title, String description, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
        trailing: Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }
}
