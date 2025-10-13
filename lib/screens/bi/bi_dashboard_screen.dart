import 'package:flutter/material.dart';
import '../../models/authority.dart';
import '../../services/business_intelligence_service.dart';
import 'pass_analytics_screen.dart';
import 'revenue_analytics_screen.dart';

/// Business Intelligence Dashboard Screen
/// Shows key metrics and insights for the selected authority
class BiDashboardScreen extends StatefulWidget {
  final Authority authority;

  const BiDashboardScreen({
    super.key,
    required this.authority,
  });

  @override
  State<BiDashboardScreen> createState() => _BiDashboardScreenState();
}

class _BiDashboardScreenState extends State<BiDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _dashboardData = {};
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load real dashboard data from BI service
      final results = await Future.wait([
        BusinessIntelligenceService.getDashboardData(widget.authority.id),
        BusinessIntelligenceService.getRecentActivity(widget.authority.id,
            limit: 5),
      ]);

      if (mounted) {
        setState(() {
          _dashboardData = results[0] as Map<String, dynamic>;
          _recentActivity = results[1] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading dashboard data: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Intelligence'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Column(
        children: [
          // Authority header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(
                bottom: BorderSide(
                  color: Colors.green.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.analytics,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.authority.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Dashboard Overview • ${widget.authority.countryName ?? 'Unknown Country'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: SafeArea(
              top: false, // Don't add safe area at top since we have the header
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error Loading Data',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Colors.red.shade700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadDashboardData,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadDashboardData,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Key Metrics Cards
                                _buildMetricsSection(),
                                const SizedBox(height: 24),

                                // Quick Actions
                                _buildQuickActionsSection(),
                                const SizedBox(height: 24),

                                // Recent Activity
                                _buildRecentActivitySection(),
                              ],
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Metrics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio:
              2.2, // Increased from 1.8 to make cards taller // Increased from 1.5 to give more height
          children: [
            _buildMetricCard(
              'Total Passes',
              _dashboardData['totalPasses'].toString(),
              Icons.confirmation_number,
              Colors.green.shade600,
            ),
            _buildMetricCard(
              'Active Passes',
              _dashboardData['activePasses'].toString(),
              Icons.check_circle,
              Colors.green.shade700,
            ),
            _buildMetricCard(
              'Total Revenue',
              '\$${(_dashboardData['totalRevenue'] as double).toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.green.shade500,
            ),
            _buildMetricCard(
              'Compliance Rate',
              '${_dashboardData['complianceRate']}%',
              Icons.verified,
              Colors.green.shade800,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(10), // Reduced padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 18), // Reduced icon size
                Container(
                  padding: const EdgeInsets.all(2), // Reduced padding
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    color: color,
                    size: 10, // Reduced icon size
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2), // Reduced spacing
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18, // Reduced from 20
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 10, // Reduced from 11
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
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
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Pass Analytics',
                Icons.analytics,
                Colors.green,
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PassAnalyticsScreen(
                        authority: widget.authority,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                'Revenue Reports',
                Icons.attach_money,
                Colors.green,
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => RevenueAnalyticsScreen(
                        authority: widget.authority,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _recentActivity.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Recent Activity',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Activity will appear here as passes are purchased and processed',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: _recentActivity.asMap().entries.map((entry) {
                      final index = entry.key;
                      final activity = entry.value;
                      return Column(
                        children: [
                          if (index > 0) const Divider(),
                          _buildActivityItem(
                            activity['title'] as String,
                            activity['subtitle'] as String,
                            activity['time'] as String,
                            _getIconData(activity['icon'] as String),
                            _getColorFromName(activity['color'] as String),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
      String title, String subtitle, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'add_circle':
        return Icons.add_circle;
      case 'warning':
        return Icons.warning;
      case 'security':
        return Icons.security;
      case 'location_on':
        return Icons.location_on;
      default:
        return Icons.info;
    }
  }

  Color _getColorFromName(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.green.shade500;
      default:
        return Colors.grey;
    }
  }
}
