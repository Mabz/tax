import 'package:flutter/material.dart';
import 'lib/screens/border_movement_screen.dart';

void main() {
  runApp(const BorderMovementTestApp());
}

class BorderMovementTestApp extends StatelessWidget {
  const BorderMovementTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Border Movement Test',
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      home: const BorderMovementTestScreen(),
    );
  }
}

class BorderMovementTestScreen extends StatelessWidget {
  const BorderMovementTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Border Movement Test'),
        backgroundColor: Colors.purple.shade700,
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
                    Row(
                      children: [
                        Icon(Icons.timeline,
                            color: Colors.purple.shade700, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Border Movement View',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.purple.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'New Movement view for Border Analytics that focuses on vehicle movements from the perspective of vehicles.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Features:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const _FeatureItem(
                      icon: Icons.list,
                      title: 'Movement List',
                      description:
                          'Lists all movements (check-in, check-out) for the selected border',
                    ),
                    const _FeatureItem(
                      icon: Icons.search,
                      title: 'Vehicle Search',
                      description:
                          'Search by vehicle VIN, make, model, or registration number',
                    ),
                    const _FeatureItem(
                      icon: Icons.directions_car,
                      title: 'Vehicle Details',
                      description:
                          'Click on a vehicle to see all movement details',
                    ),
                    const _FeatureItem(
                      icon: Icons.history,
                      title: 'Movement History',
                      description:
                          'Complete pass movement history for each vehicle',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Integration Status',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The Movement view has been added as a new tab in the Border Analytics screen. '
                      'It provides a vehicle-centric view of border movements with search capabilities.',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BorderMovementScreen(
                        borderId: 'test-border-id',
                        borderName: 'Test Border',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.timeline),
                label: const Text('Test Movement Screen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 16, color: Colors.purple.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
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
