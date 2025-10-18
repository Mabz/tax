import 'package:flutter/material.dart';
import '../screens/border_analytics_screen.dart';
import '../services/border_analytics_access_service.dart';

/// Test widget to verify Border Analytics access and functionality
class TestBorderAnalyticsAccess extends StatefulWidget {
  const TestBorderAnalyticsAccess({super.key});

  @override
  State<TestBorderAnalyticsAccess> createState() =>
      _TestBorderAnalyticsAccessState();
}

class _TestBorderAnalyticsAccessState extends State<TestBorderAnalyticsAccess> {
  bool _canAccess = false;
  List<Map<String, dynamic>> _authorities = [];
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
        _canAccess = canAccess;
        _authorities = authorities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking access: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Border Analytics Access'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAccessStatus(),
                  const SizedBox(height: 24),
                  if (_canAccess) ...[
                    _buildAuthoritiesSection(),
                    const SizedBox(height: 24),
                    _buildTestButtons(),
                  ] else
                    _buildNoAccessMessage(),
                ],
              ),
            ),
    );
  }

  Widget _buildAccessStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Access Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _canAccess ? Icons.check_circle : Icons.cancel,
                  color: _canAccess ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  _canAccess
                      ? 'You have access to Border Analytics'
                      : 'You do not have access to Border Analytics',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: _canAccess ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
            if (_canAccess) ...[
              const SizedBox(height: 8),
              Text(
                'Accessible authorities: ${_authorities.length}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuthoritiesSection() {
    if (_authorities.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Accessible Authorities',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'No specific authorities found. You may have access to your assigned borders.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accessible Authorities',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ..._authorities.map((authority) => ListTile(
                  contentPadding: EdgeInsets.zero,
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
                  title: Text(authority['name'] ?? 'Unknown Authority'),
                  subtitle: Text(
                    '${authority['country_name'] ?? 'Unknown Country'} • ${BorderAnalyticsAccessService.getRoleDisplayName(authority['user_role'] ?? '')}',
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _openBorderAnalytics(
                      authority['id'],
                      authority['name'],
                    ),
                    child: const Text('Open'),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Border Analytics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openBorderAnalytics(null, null),
                    icon: const Icon(Icons.analytics),
                    label: const Text('Open Default View'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _checkAccess,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Access'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAccessMessage() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Access Required',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'To access Border Analytics, you need one of the following roles:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ...([
              'Country Administrator',
              'Country Auditor',
              'Compliance Officer',
              'Border Manager',
              'System Administrator',
            ].map((role) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(role),
                    ],
                  ),
                ))),
            const SizedBox(height: 16),
            Text(
              'Please contact your system administrator to request access.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBorderAnalytics(String? authorityId, String? authorityName) {
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
