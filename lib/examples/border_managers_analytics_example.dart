import 'package:flutter/material.dart';
import '../screens/border_managers_analytics_screen.dart';
import '../services/border_analytics_access_service.dart';

/// Example showing how to integrate Border Managers Analytics
/// This demonstrates the new advanced analytics with date filtering and comparisons
class BorderManagersAnalyticsExample extends StatefulWidget {
  const BorderManagersAnalyticsExample({super.key});

  @override
  State<BorderManagersAnalyticsExample> createState() =>
      _BorderManagersAnalyticsExampleState();
}

class _BorderManagersAnalyticsExampleState
    extends State<BorderManagersAnalyticsExample> {
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
        title: const Text('Border Managers Analytics Example'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (!_canAccessAnalytics) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Access Denied',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'You do not have permission to access Border Analytics.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 24),
          _buildFeaturesCard(),
          const SizedBox(height: 24),
          _buildAccessOptions(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.indigo.shade700, Colors.indigo.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.dashboard,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Border Managers Analytics',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Advanced analytics with date filtering and comparisons',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Key Features',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              Icons.calendar_today,
              'Date Filtering',
              'Today, Tomorrow, Next Week, Next Month, or Custom Range',
              Colors.blue,
            ),
            _buildFeatureItem(
              Icons.directions_car,
              'Vehicle Flow Analytics',
              'Expected vs Actual Check-ins and Check-outs',
              Colors.green,
            ),
            _buildFeatureItem(
              Icons.category,
              'Vehicle Type Breakdown',
              'Top vehicle types and detailed analytics by type',
              Colors.orange,
            ),
            _buildFeatureItem(
              Icons.confirmation_number,
              'Pass Analysis',
              'Active, expired, and upcoming passes with detailed breakdown',
              Colors.purple,
            ),
            _buildFeatureItem(
              Icons.warning,
              'Missed Scans Detection',
              'Identify vehicles that missed check-in or check-out scans',
              Colors.red,
            ),
            _buildFeatureItem(
              Icons.attach_money,
              'Revenue Analytics',
              'Expected vs actual revenue with date-on-date comparisons',
              Colors.teal,
            ),
            _buildFeatureItem(
              Icons.compare_arrows,
              'Date Comparisons',
              'Compare today vs yesterday, next week vs last week',
              Colors.indigo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
      IconData icon, String title, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

  Widget _buildAccessOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Access Analytics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (_accessibleAuthorities.length == 1)
              // Single authority - direct access
              _buildAccessButton(
                'Open Analytics Dashboard',
                'View analytics for ${_accessibleAuthorities.first['name']}',
                Icons.dashboard,
                () => _navigateToAnalytics(
                  _accessibleAuthorities.first['id'],
                  _accessibleAuthorities.first['name'],
                ),
              )
            else if (_accessibleAuthorities.length > 1)
              // Multiple authorities - show selection
              Column(
                children: [
                  _buildAccessButton(
                    'Select Authority',
                    'Choose which authority to analyze',
                    Icons.list,
                    _showAuthoritySelection,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You have access to ${_accessibleAuthorities.length} authorities',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              )
            else
              // No specific authority access - use current user's assigned borders
              _buildAccessButton(
                'Open My Analytics',
                'View analytics for your assigned borders',
                Icons.dashboard,
                () => _navigateToAnalytics(null, null),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessButton(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.indigo.shade200),
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.indigo.shade50, Colors.indigo.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade800,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.indigo.shade600,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.indigo.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showAuthoritySelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.dashboard,
                    color: Colors.indigo.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Select Authority for Analytics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...(_accessibleAuthorities.map((authority) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      child: Text(
                        authority['code']
                                ?.toString()
                                .substring(0, 2)
                                .toUpperCase() ??
                            'AU',
                        style: TextStyle(
                          color: Colors.indigo.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      authority['name'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${authority['country_name']} • ${BorderAnalyticsAccessService.getRoleDisplayName(authority['user_role'])}',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.dashboard,
                        color: Colors.indigo.shade700,
                        size: 20,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _navigateToAnalytics(authority['id'], authority['name']);
                    },
                  ),
                ))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _navigateToAnalytics(String? authorityId, String? authorityName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BorderManagersAnalyticsScreen(
          authorityId: authorityId,
          authorityName: authorityName,
        ),
      ),
    );
  }
}
