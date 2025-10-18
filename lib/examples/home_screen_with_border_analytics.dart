import 'package:flutter/material.dart';
import '../widgets/border_management_menu.dart';
import '../screens/border_analytics_screen.dart';
import '../services/border_analytics_access_service.dart';

/// Example Home Screen showing how to integrate Border Analytics
/// This demonstrates how to add the Border Analytics to your existing navigation
class HomeScreenWithBorderAnalytics extends StatefulWidget {
  const HomeScreenWithBorderAnalytics({super.key});

  @override
  State<HomeScreenWithBorderAnalytics> createState() =>
      _HomeScreenWithBorderAnalyticsState();
}

class _HomeScreenWithBorderAnalyticsState
    extends State<HomeScreenWithBorderAnalytics> {
  bool _canAccessBorderAnalytics = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBorderAnalyticsAccess();
  }

  Future<void> _checkBorderAnalyticsAccess() async {
    try {
      final canAccess =
          await BorderAnalyticsAccessService.canAccessBorderAnalytics();
      setState(() {
        _canAccessBorderAnalytics = canAccess;
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
        title: const Text('Cross-Border Tax Platform'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeSection(),
            const SizedBox(height: 24),

            // Quick Actions
            _buildQuickActionsSection(),
            const SizedBox(height: 24),

            // Border Management Section (includes Border Analytics)
            if (!_isLoading && _canAccessBorderAnalytics) ...[
              const BorderManagementMenu(),
              const SizedBox(height: 24),
            ],

            // Other sections...
            _buildOtherSections(),
          ],
        ),
      ),
      // Optional: Add Border Analytics as a floating action button for quick access
      floatingActionButton: _canAccessBorderAnalytics
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToQuickBorderAnalytics(),
              icon: const Icon(Icons.analytics),
              label: const Text('Analytics'),
              backgroundColor: Colors.blue.shade700,
            )
          : null,
    );
  }

  Widget _buildWelcomeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome Back!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Manage cross-border operations and monitor compliance.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildQuickActionCard(
              'Purchase Pass',
              Icons.add_shopping_cart,
              Colors.green,
              () {
                // Navigate to pass purchase
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Purchase Pass - Coming soon')),
                );
              },
            ),
            _buildQuickActionCard(
              'My Passes',
              Icons.confirmation_number,
              Colors.blue,
              () {
                // Navigate to user passes
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('My Passes - Coming soon')),
                );
              },
            ),
            if (_canAccessBorderAnalytics)
              _buildQuickActionCard(
                'Border Analytics',
                Icons.analytics,
                Colors.purple,
                () => _navigateToQuickBorderAnalytics(),
              ),
            _buildQuickActionCard(
              'Support',
              Icons.help,
              Colors.orange,
              () {
                // Navigate to support
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Support - Coming soon')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info, color: Colors.blue.shade600),
                  title: const Text('No recent activity'),
                  subtitle:
                      const Text('Your recent transactions will appear here'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToQuickBorderAnalytics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BorderAnalyticsScreen(),
      ),
    );
  }
}

/// Example of how to add Border Analytics to an existing drawer menu
class DrawerWithBorderAnalytics extends StatelessWidget {
  const DrawerWithBorderAnalytics({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Cross-Border Platform',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.of(context).pop(),
          ),
          ListTile(
            leading: const Icon(Icons.confirmation_number),
            title: const Text('My Passes'),
            onTap: () => Navigator.of(context).pop(),
          ),
          const Divider(),
          // Border Management Section
          ListTile(
            leading: const Icon(Icons.border_all),
            title: const Text('Border Management'),
            enabled: false,
          ),
          FutureBuilder<bool>(
            future: BorderAnalyticsAccessService.canAccessBorderAnalytics(),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return ListTile(
                  leading: const Icon(Icons.analytics),
                  title: const Text('Border Analytics'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const BorderAnalyticsScreen(),
                      ),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Staff Management'),
            onTap: () => Navigator.of(context).pop(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => Navigator.of(context).pop(),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
