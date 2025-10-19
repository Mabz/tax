import 'package:flutter/material.dart';
import '../screens/border_analytics_screen.dart';
import '../screens/border_schedule_management_screen.dart';
import '../screens/border_configuration_screen.dart';
import '../services/border_analytics_access_service.dart';

/// Border Management Menu Widget
/// Shows border management options based on user roles
class BorderManagementMenu extends StatefulWidget {
  final String? selectedAuthorityId;
  final String? selectedAuthorityName;

  const BorderManagementMenu({
    super.key,
    this.selectedAuthorityId,
    this.selectedAuthorityName,
  });

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
    debugPrint('🔍 BorderManagementMenu.initState() called');
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    debugPrint('🔍 _checkAccess() started');
    try {
      debugPrint(
          '🔍 Calling BorderAnalyticsAccessService.canAccessBorderAnalytics()');
      final canAccess =
          await BorderAnalyticsAccessService.canAccessBorderAnalytics();
      debugPrint('🔍 canAccessBorderAnalytics result: $canAccess');

      debugPrint(
          '🔍 Calling BorderAnalyticsAccessService.getAccessibleAuthorities()');
      final authorities =
          await BorderAnalyticsAccessService.getAccessibleAuthorities();
      debugPrint(
          '🔍 getAccessibleAuthorities result: ${authorities.length} authorities');

      debugPrint(
          '🔍 Setting state: canAccess=$canAccess, authorities=${authorities.length}');
      setState(() {
        _canAccessAnalytics = canAccess;
        _accessibleAuthorities = authorities;
        _isLoading = false;
      });
      debugPrint('🔍 setState completed successfully');
    } catch (e) {
      debugPrint('❌ Error in _checkAccess(): $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '🔍 BorderManagementMenu.build() called. _isLoading: $_isLoading');

    if (_isLoading) {
      debugPrint('🔍 Showing loading indicator');
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    debugPrint('🔍 About to render main BorderManagementMenu content');

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
            () {
              debugPrint('🔍 About to call _buildBorderManagementOptions()');
              return _buildBorderManagementOptions();
            }(),
          ],
        ),
      ),
    );
  }

  Widget _buildBorderManagementOptions() {
    debugPrint(
        '🔍 Building border management options. _canAccessAnalytics: $_canAccessAnalytics');
    debugPrint(
        '🔍 Accessible authorities count: ${_accessibleAuthorities.length}');

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

        // Show message if no access to any management features
        if (!_canAccessAnalytics) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(Icons.lock_outline, size: 32, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'No Management Access',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You need Border Manager or Country Administrator permissions to access border management features.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
          ),
        ],

        // Border Analytics - moved to top
        if (_canAccessAnalytics) ...[
          // DEBUG: This block should execute if Border Analytics is visible
          () {
            debugPrint(
                '🔍 Inside _canAccessAnalytics block - Border Analytics should be visible');
            return const SizedBox.shrink();
          }(),
          // Use selected authority if available, otherwise fall back to accessible authorities
          if (widget.selectedAuthorityId != null &&
              widget.selectedAuthorityName != null)
            // Use selected authority from home screen
            _buildMenuOption(
              'Border Analytics',
              'Analytics, officials performance, and forecasts for ${widget.selectedAuthorityName}',
              Icons.analytics,
              () => _navigateToBorderAnalytics(
                widget.selectedAuthorityId,
                widget.selectedAuthorityName,
              ),
            )
          else if (_accessibleAuthorities.length == 1)
            // Single authority - direct access
            _buildMenuOption(
              'Border Analytics',
              'Analytics, officials performance, compliance reports, and forecasts',
              Icons.analytics,
              () => _navigateToBorderAnalytics(
                _accessibleAuthorities.first['id'],
                _accessibleAuthorities.first['name'],
              ),
            )
          else if (_accessibleAuthorities.length > 1)
            // Multiple authorities - show selection
            _buildMenuOption(
              'Border Analytics',
              'Select authority to view analytics, officials performance, and forecasts',
              Icons.analytics,
              _showAuthoritySelection,
            )
          else
            // No specific authority access - use current user's assigned borders
            _buildMenuOption(
              'Border Analytics',
              'Analytics, officials performance, and forecasts for your assigned borders',
              Icons.analytics,
              () => _navigateToBorderAnalytics(null, null),
            ),
          const SizedBox(height: 8),

          // Border Officials
          _buildMenuOption(
            'Border Officials',
            'Manage border official assignments and performance',
            Icons.admin_panel_settings,
            () {
              // Navigate to border officials management
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Border Officials management - Coming soon')),
              );
            },
          ),
          const SizedBox(height: 8),

          // Border Schedules
          _buildMenuOption(
            'Border Schedules',
            'Manage border official schedules and time slots',
            Icons.schedule,
            _navigateToBorderSchedules,
          ),
          const SizedBox(height: 8),

          _buildMenuOption(
            'Border Configuration',
            'Configure border settings and out-of-schedule scan policies',
            Icons.settings,
            _navigateToBorderConfiguration,
          ),
          const SizedBox(height: 8),

          _buildMenuOption(
            'Compliance Reports',
            'Generate and view compliance reports',
            Icons.assessment,
            () {
              // Navigate to compliance reports
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Compliance Reports - Coming soon')),
              );
            },
          ),
        ],
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

  void _navigateToBorderSchedules() {
    debugPrint('🔍 _navigateToBorderSchedules called');
    debugPrint('🔍 authorityId: ${widget.selectedAuthorityId}');
    debugPrint('🔍 authorityName: ${widget.selectedAuthorityName}');

    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            debugPrint('🔍 Building BorderScheduleManagementScreen');
            return BorderScheduleManagementScreen(
              authorityId: widget.selectedAuthorityId,
              authorityName: widget.selectedAuthorityName,
            );
          },
        ),
      );
      debugPrint('✅ Navigation to BorderScheduleManagementScreen initiated');
    } catch (e) {
      debugPrint('❌ Error navigating to BorderScheduleManagementScreen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening Border Schedules: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToBorderConfiguration() {
    debugPrint('🔍 _navigateToBorderConfiguration called');
    debugPrint('🔍 authorityId: ${widget.selectedAuthorityId}');
    debugPrint('🔍 authorityName: ${widget.selectedAuthorityName}');

    try {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) {
            debugPrint('🔍 Building BorderConfigurationScreen');
            return BorderConfigurationScreen(
              authorityId: widget.selectedAuthorityId,
              authorityName: widget.selectedAuthorityName,
            );
          },
        ),
      );
      debugPrint('✅ Navigation to BorderConfigurationScreen initiated');
    } catch (e) {
      debugPrint('❌ Error navigating to BorderConfigurationScreen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening Border Configuration: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
