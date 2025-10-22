import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TestIconsScreen extends StatelessWidget {
  const TestIconsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Icon Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Testing Material Icons:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Test basic icons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(Icons.home, size: 32, color: Colors.blue),
                    const SizedBox(height: 8),
                    const Text('home'),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.analytics, size: 32, color: Colors.green),
                    const SizedBox(height: 8),
                    const Text('analytics'),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.people, size: 32, color: Colors.orange),
                    const SizedBox(height: 8),
                    const Text('people'),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.trending_up, size: 32, color: Colors.red),
                    const SizedBox(height: 8),
                    const Text('trending_up'),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Test icons used in border analytics
            const Text(
              'Border Analytics Icons:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                _buildIconTest(
                    Icons.confirmation_number, 'confirmation_number'),
                _buildIconTest(Icons.qr_code_scanner, 'qr_code_scanner'),
                _buildIconTest(Icons.check_circle, 'check_circle'),
                _buildIconTest(Icons.directions_car, 'directions_car'),
                _buildIconTest(Icons.attach_money, 'attach_money'),
                _buildIconTest(Icons.schedule, 'schedule'),
                _buildIconTest(Icons.date_range, 'date_range'),
                _buildIconTest(Icons.refresh, 'refresh'),
              ],
            ),

            const SizedBox(height: 30),

            // Test with different sizes
            const Text(
              'Different Sizes:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Icon(Icons.star, size: 16, color: Colors.purple),
                Icon(Icons.star, size: 24, color: Colors.purple),
                Icon(Icons.star, size: 32, color: Colors.purple),
                Icon(Icons.star, size: 48, color: Colors.purple),
                Icon(Icons.star, size: 64, color: Colors.purple),
              ],
            ),

            const SizedBox(height: 30),

            // Test with Material Design Icons Flutter package
            const Text(
              'Extended Material Icons:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Icon(MdiIcons.home, size: 32, color: Colors.teal),
                Icon(MdiIcons.chartLine, size: 32, color: Colors.teal),
                Icon(MdiIcons.account, size: 32, color: Colors.teal),
                Icon(MdiIcons.trendingUp, size: 32, color: Colors.teal),
                Icon(MdiIcons.qrcodeScan, size: 32, color: Colors.teal),
              ],
            ),

            const SizedBox(height: 30),

            // Test with Unicode symbols as fallback
            const Text(
              'Unicode Symbol Fallbacks:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildUnicodeIcon('🏠', 'Home'),
                _buildUnicodeIcon('📊', 'Analytics'),
                _buildUnicodeIcon('👥', 'People'),
                _buildUnicodeIcon('📈', 'Trending'),
                _buildUnicodeIcon('📱', 'Scanner'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconTest(IconData icon, String name) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24, color: Colors.blue.shade700),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildUnicodeIcon(String emoji, String name) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
