import 'package:flutter/material.dart';
import '../../models/authority.dart';
import '../../services/business_intelligence_service.dart';

/// Revenue Analytics Screen
/// Shows detailed revenue analytics and financial insights
class RevenueAnalyticsScreen extends StatefulWidget {
  final Authority authority;

  const RevenueAnalyticsScreen({
    super.key,
    required this.authority,
  });

  @override
  State<RevenueAnalyticsScreen> createState() => _RevenueAnalyticsScreenState();
}

class _RevenueAnalyticsScreenState extends State<RevenueAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;
  Map<String, dynamic> _revenueData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRevenueData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRevenueData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load real revenue data from BI service
      final data = await BusinessIntelligenceService.getRevenueAnalyticsData(
          widget.authority.id);

      if (mounted) {
        setState(() {
          _revenueData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading revenue data: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenue Analytics'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadRevenueData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.green.shade200,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.attach_money, size: 20)),
            Tab(text: 'Breakdown', icon: Icon(Icons.pie_chart, size: 20)),
            Tab(text: 'Performance', icon: Icon(Icons.trending_up, size: 20)),
          ],
        ),
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
                      Icons.attach_money,
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
                  'Revenue Analytics • ${widget.authority.countryName ?? 'Unknown Country'}',
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
                                  onPressed: _loadRevenueData,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOverviewTab(),
                            _buildBreakdownTab(),
                            _buildPerformanceTab(),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadRevenueData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Key Revenue Metrics
            _buildRevenueMetrics(),
            const SizedBox(height: 24),

            // Revenue Summary Cards
            _buildRevenueSummary(),
            const SizedBox(height: 24),

            // Quick Insights
            _buildQuickInsights(),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownTab() {
    return RefreshIndicator(
      onRefresh: _loadRevenueData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Revenue by Pass Type
            _buildRevenueByPassType(),
            const SizedBox(height: 24),

            // Revenue by Payment Method
            _buildRevenueByPaymentMethod(),
            const SizedBox(height: 24),

            // Collection Efficiency
            _buildCollectionEfficiency(),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return RefreshIndicator(
      onRefresh: _loadRevenueData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Performance Indicators
            _buildPerformanceIndicators(),
            const SizedBox(height: 24),

            // Revenue Trends Placeholder
            _buildRevenueTrends(),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue Overview',
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
          childAspectRatio: 2.2, // Increased from 1.8 to make cards taller
          children: [
            _buildMetricCard(
              'Total Revenue',
              '\$${((_revenueData['totalRevenue'] as double?) ?? 0.0).toStringAsFixed(0)}',
              Icons.attach_money,
              Colors.green,
            ),
            _buildMetricCard(
              'Monthly Revenue',
              '\$${((_revenueData['monthlyRevenue'] as double?) ?? 0.0).toStringAsFixed(0)}',
              Icons.calendar_month,
              Colors.green.shade500,
            ),
            _buildMetricCard(
              'Daily Average',
              '\$${((_revenueData['dailyAverage'] as double?) ?? 0.0).toStringAsFixed(0)}',
              Icons.today,
              Colors.green.shade600,
            ),
            _buildMetricCard(
              'Growth Rate',
              '${(_revenueData['revenueGrowth'] ?? 0.0).toStringAsFixed(1)}%',
              Icons.trending_up,
              Colors.green,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSummaryRow(
                  'Yearly Projection',
                  '\$${(_revenueData['yearlyProjection'] as double).toStringAsFixed(0)}',
                  Icons.trending_up,
                  Colors.green,
                ),
                const Divider(),
                _buildSummaryRow(
                  'Revenue at Risk',
                  '\$${(_revenueData['revenueAtRisk'] as double).toStringAsFixed(0)}',
                  Icons.warning,
                  Colors.red,
                ),
                const Divider(),
                _buildSummaryRow(
                  'Outstanding Payments',
                  '\$${(_revenueData['outstandingPayments'] as double).toStringAsFixed(0)}',
                  Icons.schedule,
                  Colors.green,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Insights',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInsightRow(
                  'Top Revenue Source',
                  _revenueData['topRevenueSource'] as String,
                  Icons.star,
                ),
                _buildInsightRow(
                  'Collection Efficiency',
                  '${_revenueData['collectionEfficiency']}%',
                  Icons.check_circle,
                ),
                _buildInsightRow(
                  'Average Transaction',
                  '\$${((_revenueData['totalRevenue'] as double) / 1250).toStringAsFixed(2)}',
                  Icons.receipt,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueByPassType() {
    final revenueByType =
        _revenueData['revenueByPassType'] as Map<String, dynamic>;
    final totalRevenue = _revenueData['totalRevenue'] as double;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue by Pass Type',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: revenueByType.entries.map((entry) {
                final revenue = entry.value as double;
                final percentage =
                    (revenue / totalRevenue * 100).toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getPassTypeColor(entry.key),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${entry.key.toUpperCase()} Pass',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${revenue.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$percentage%',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueByPaymentMethod() {
    final revenueByPayment =
        _revenueData['revenueByPaymentMethod'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue by Payment Method',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: revenueByPayment.entries.map((entry) {
                final revenue = entry.value as double;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _getPaymentMethodIcon(entry.key),
                        color: _getPaymentMethodColor(entry.key),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getPaymentMethodName(entry.key),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '\$${revenue.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionEfficiency() {
    final efficiency = _revenueData['collectionEfficiency'] as double;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collection Efficiency',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${efficiency.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        'Collection efficiency rate',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: efficiency / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.green.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceIndicators() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Indicators',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildPerformanceCard(
                'Revenue Growth',
                '${_revenueData['revenueGrowth']}%',
                'vs last month',
                Icons.trending_up,
                Colors.green,
                true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPerformanceCard(
                'Collection Rate',
                '${_revenueData['collectionEfficiency']}%',
                'efficiency',
                Icons.check_circle,
                Colors.green.shade500,
                true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueTrends() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue Trends',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 48,
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Revenue Charts Coming Soon',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Revenue trends and forecasting charts will be displayed here',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(10), // Reduced from 12
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 18), // Reduced from 20
                Container(
                  padding: const EdgeInsets.all(2), // Reduced from 3
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    color: color,
                    size: 10, // Reduced from 12
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2), // Reduced from 4
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

  Widget _buildSummaryRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(String title, String value, String subtitle,
      IconData icon, Color color, bool isPositive) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isPositive ? Colors.green : Colors.red,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
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
    );
  }

  Color _getPassTypeColor(String passType) {
    switch (passType.toLowerCase()) {
      case 'daily':
        return Colors.green.shade500;
      case 'weekly':
        return Colors.green;
      case 'monthly':
        return Colors.green;
      case 'annual':
        return Colors.green.shade600;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'credit_card':
        return Icons.credit_card;
      case 'mobile_money':
        return Icons.phone_android;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'cash':
        return Icons.money;
      default:
        return Icons.payment;
    }
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'credit_card':
        return Colors.green.shade500;
      case 'mobile_money':
        return Colors.green;
      case 'bank_transfer':
        return Colors.green.shade600;
      case 'cash':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentMethodName(String method) {
    switch (method.toLowerCase()) {
      case 'credit_card':
        return 'Credit Card';
      case 'mobile_money':
        return 'Mobile Money';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cash':
        return 'Cash';
      default:
        return method;
    }
  }
}
