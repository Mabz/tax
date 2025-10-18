import 'package:flutter/material.dart';
import '../screens/border_analytics_screen.dart';
import '../services/border_analytics_access_service.dart';

/// Border Management Menu Widget
/// Shows border management options based on user roles
class BorderManagementMenu extends StatefulWidget {
  const BorderManagementMenu({super.key});

  @override
  State<BorderManagementMenu> createState() => _BorderManagementMenuState();
}

class _BorderManagementMenuState extends State<BorderManagementMenu> {
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
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.border_all, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Border Management',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_canAccessAnalytics) ...[
              _buildAnalyticsSection(),
              const SizedBox(height: 16),
            ],
            _buildOtherBorderOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics & Reporting',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        if (_accessibleAuthorities.length == 1)
          // Single authority - direct access
          _buildAnalyticsButton(
            'Border Analytics',
            'View comprehensive border analytics and compliance reports',
            Icons.analytics,
            () => _navigateToBorderAnalytics(
              _accessibleAuthorities.first['id'],
              _accessibleAuthorities.first['name'],
            ),
          )
        else if (_accessibleAuthorities.length > 1)
          // Multiple authorities - show selection
          _buildAnalyticsButton(
            'Border Analytics',
            'Select authority to view border analytics',
            Icons.analytics,
            _showAuthoritySelection,
          )
        else
          // No specific authority access - use current user's assigned borders
          _buildAnalyticsButton(
            'Border Analytics',
            'View analytics for your assigned borders',
            Icons.analytics,
            () => _navigateToBorderAnalytics(null, null),
          ),
      ],
    );
  }

  Widget _buildAnalyticsButton(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: Colors.blue.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherBorderOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Management Tools',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        _buildMenuOption(
          'Border Officials',
          'Manage border official assignments',
          Icons.people,
          () {
            // Navigate to border officials management
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Border Officials management - Coming soon')),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildMenuOption(
          'Border Configuration',
          'Configure border settings and parameters',
          Icons.settings,
          () {
            // Navigate to border configuration
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Border Configuration - Coming soon')),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildMenuOption(
          'Compliance Reports',
          'Generate and view compliance reports',
          Icons.assessment,
          () {
            // Navigate to compliance reports
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Compliance Reports - Coming soon')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuOption(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showAuthoritySelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Authority for Border Analytics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...(_accessibleAuthorities.map((authority) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      authority['code']
                              ?.toString()
                              .substring(0, 2)
                              .toUpperCase() ??
                          'AU',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(authority['name']),
                  subtitle: Text(
                    '${authority['country_name']} • ${BorderAnalyticsAccessService.getRoleDisplayName(authority['user_role'])}',
                  ),
                  trailing: const Icon(Icons.analytics),
                  onTap: () {
                    Navigator.of(context).pop();
                    _navigateToBorderAnalytics(
                        authority['id'], authority['name']);
                  },
                ))),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _navigateToBorderAnalytics(String? authorityId, String? authorityName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BorderAnalyticsScreen(
          authorityId: authorityId,
          authorityName: authorityName,
        ),
      ),
    );
  }
}
