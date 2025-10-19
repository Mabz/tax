import 'package:flutter/material.dart';
import '../screens/border_analytics_screen.dart';
import '../services/border_analytics_access_service.dart';

/// Test the improved forecast functionality with friendly dates and pass details
class TestImprovedForecast extends StatefulWidget {
  const TestImprovedForecast({super.key});

  @override
  State<TestImprovedForecast> createState() => _TestImprovedForecastState();
}

class _TestImprovedForecastState extends State<TestImprovedForecast> {
  bool _canAccessAnalytics = false;
  List<Map<String, dynamic>> _accessibleAuthorities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final canAccess =
          await BorderAnalyticsAccessService.canAccessBorderAnalytics();
      final authorities =
          await BorderAnalyticsAccessService.getAccessibleAuthorities();

      setState(() {
        _canAccessAnalytics = canAccess;
        _accessibleAuthorities = authorities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Improved Forecast'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (!_canAccessAnalytics) {
      return const Center(
        child: Text('Access denied to border analytics'),
      );
    }

    return Padding(
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
                    'Improved Forecast Features',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                      '✅ Friendly date formatting (Today, Tomorrow, etc.)'),
                  const Text('✅ Separate Check-in and Check-out sections'),
                  const Text('✅ Pass IDs displayed in corner'),
                  const Text('✅ Tap passes for detailed information'),
                  const Text('✅ Color-coded dates based on urgency'),
                  const Text('✅ Improved visual design'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test the Forecast Tab',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Click the button below to open Border Analytics and navigate to the Forecast tab to see the improvements.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openBorderAnalytics,
                    icon: const Icon(Icons.analytics),
                    label: const Text('Open Border Analytics'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openBorderAnalytics() {
    if (_accessibleAuthorities.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BorderAnalyticsScreen(
            authorityId: _accessibleAuthorities.first['id'],
            authorityName: _accessibleAuthorities.first['name'],
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const BorderAnalyticsScreen(),
        ),
      );
    }
  }
}
