import 'package:flutter/material.dart';
import '../services/analytics_dashboard_service.dart';

class ComprehensiveAnalyticsScreen extends StatefulWidget {
  final String authorityId;
  final String authorityName;

  const ComprehensiveAnalyticsScreen({
    super.key,
    required this.authorityId,
    required this.authorityName,
  });

  @override
  State<ComprehensiveAnalyticsScreen> createState() =>
      _ComprehensiveAnalyticsScreenState();
}

class _ComprehensiveAnalyticsScreenState
    extends State<ComprehensiveAnalyticsScreen> {
  Map<String, dynamic>? _analyticsData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final data =
          await AnalyticsDashboardService.getComprehensiveDashboardData(
        widget.authorityId,
      );

      setState(() {
        _analyticsData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics - ${widget.authorityName}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _buildAnalyticsContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Failed to load analytics',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAnalyticsData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    if (_analyticsData == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExecutiveSummary(),
          const SizedBox(height: 24),
          _buildKPICards(),
          const SizedBox(height: 24),
          _buildCriticalAlerts(),
          const SizedBox(height: 24),
          _buildRevenueAnalytics(),
          const SizedBox(height: 24),
          _buildDistributionEfficiency(),
          const SizedBox(height: 24),
          _buildFraudDetection(),
          const SizedBox(height: 24),
          _buildRecommendations(),
        ],
      ),
    );
  }

  Widget _buildExecutiveSummary() {
    final summary =
        _analyticsData!['executive_summary'] as Map<String, dynamic>;
    final status = summary['performance_status'] as String;
    final highlights = summary['key_highlights'] as List<dynamic>;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'excellent':
        statusColor = Colors.green;
        statusIcon = Icons.trending_up;
        break;
      case 'good':
        statusColor = Colors.blue;
        statusIcon = Icons.thumb_up;
        break;
      case 'fair':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      default:
        statusColor = Colors.red;
        statusIcon = Icons.error;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 32),
                const SizedBox(width: 12),
                Text(
                  'Executive Summary',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                'Status: ${status.toUpperCase()}',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...highlights.map((highlight) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(highlight.toString()),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICards() {
    final kpis = _analyticsData!['kpis'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Performance Indicators',
          style: Theme.of(context).textTheme.headlineSmall,
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
            _buildKPICard(
                'Revenue Growth',
                '${kpis['revenue_growth']?.toStringAsFixed(1) ?? '0'}%',
                Icons.trending_up,
                Colors.green),
            _buildKPICard(
                'Compliance Rate',
                '${kpis['compliance_rate']?.toStringAsFixed(1) ?? '0'}%',
                Icons.security,
                Colors.blue),
            _buildKPICard(
                'Collection Efficiency',
                '${kpis['collection_efficiency']?.toStringAsFixed(1) ?? '0'}%',
                Icons.account_balance,
                Colors.purple),
            _buildKPICard(
                'Fraud Risk Score',
                '${kpis['fraud_risk_score'] ?? 0}',
                Icons.warning,
                Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalAlerts() {
    final alerts = _analyticsData!['critical_alerts'] as List<dynamic>;

    if (alerts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              const SizedBox(width: 12),
              Text(
                'No Critical Alerts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Critical Alerts',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        ...alerts.map((alert) => Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: Icon(Icons.warning, color: Colors.red),
                title: Text(alert['title']),
                subtitle: Text('Type: ${alert['type']}'),
                trailing: Chip(
                  label: Text(alert['severity'].toString().toUpperCase()),
                  backgroundColor: Colors.red.shade100,
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildRevenueAnalytics() {
    final revenueData =
        _analyticsData!['revenue_analytics'] as Map<String, dynamic>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Analytics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Total Revenue',
                    '\$${revenueData['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                    Icons.attach_money,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Monthly Revenue',
                    '\$${revenueData['monthlyRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                    Icons.calendar_month,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Daily Average',
                    '\$${revenueData['dailyAverage']?.toStringAsFixed(2) ?? '0.00'}',
                    Icons.today,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Yearly Projection',
                    '\$${revenueData['yearlyProjection']?.toStringAsFixed(2) ?? '0.00'}',
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionEfficiency() {
    final distributionData =
        _analyticsData!['distribution_efficiency'] as Map<String, dynamic>;
    final efficiencyScore =
        distributionData['overall_efficiency_score'] as double? ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribution Tax Collection Efficiency',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Text(
                        '${efficiencyScore.toStringAsFixed(1)}%',
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: _getEfficiencyColor(efficiencyScore),
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        'Overall Efficiency Score',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildMetricItem(
                        'Average Compliance',
                        '${distributionData['average_compliance_rate']?.toStringAsFixed(1) ?? '0'}%',
                        Icons.verified,
                      ),
                      _buildMetricItem(
                        'Total Passes',
                        '${distributionData['total_passes'] ?? 0}',
                        Icons.confirmation_number,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFraudDetection() {
    final fraudData =
        _analyticsData!['fraud_detection'] as Map<String, dynamic>;
    final riskScore = fraudData['risk_score'] as int? ?? 0;
    final totalAlerts = fraudData['total_alerts'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suspicious Activity Patterns',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Risk Score',
                    '$riskScore',
                    Icons.security,
                    color: _getRiskColor(riskScore),
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Total Alerts',
                    '$totalAlerts',
                    Icons.warning,
                    color: totalAlerts > 5 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            if (totalAlerts > 0) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showFraudDetails(fraudData),
                icon: const Icon(Icons.visibility),
                label: const Text('View Fraud Details'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations() {
    final recommendations = _analyticsData!['recommendations'] as List<dynamic>;

    if (recommendations.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No recommendations at this time.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommendations',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        ...recommendations.take(5).map((rec) => Card(
              child: ListTile(
                leading: Icon(
                  _getRecommendationIcon(rec['type']),
                  color: _getPriorityColor(rec['priority']),
                ),
                title: Text(rec['title']),
                subtitle: Text(rec['description']),
                trailing: Chip(
                  label: Text(rec['priority'].toString().toUpperCase()),
                  backgroundColor:
                      _getPriorityColor(rec['priority']).withOpacity(0.1),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon,
      {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.blue, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getEfficiencyColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.orange;
    return Colors.red;
  }

  Color _getRiskColor(int score) {
    if (score >= 70) return Colors.red;
    if (score >= 40) return Colors.orange;
    return Colors.green;
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getRecommendationIcon(String type) {
    switch (type) {
      case 'compliance':
        return Icons.security;
      case 'revenue':
        return Icons.attach_money;
      case 'enforcement':
        return Icons.gavel;
      case 'system':
        return Icons.settings;
      default:
        return Icons.lightbulb;
    }
  }

  void _showFraudDetails(Map<String, dynamic> fraudData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fraud Detection Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Risk Score: ${fraudData['risk_score']}'),
              const SizedBox(height: 8),
              Text('Total Alerts: ${fraudData['total_alerts']}'),
              const SizedBox(height: 16),
              const Text('Alert Breakdown:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...((fraudData['alert_breakdown'] as Map<String, dynamic>)
                  .entries
                  .map(
                    (entry) => Text('${entry.key}: ${entry.value}'),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
