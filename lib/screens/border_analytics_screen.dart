import 'package:flutter/material.dart';
import '../models/border.dart' as border_model;
import '../services/border_manager_service.dart';
import '../services/border_manager_dashboard_service.dart';

class BorderAnalyticsScreen extends StatefulWidget {
  final String? authorityId;
  final String? authorityName;

  const BorderAnalyticsScreen({
    super.key,
    this.authorityId,
    this.authorityName,
  });

  @override
  State<BorderAnalyticsScreen> createState() => _BorderAnalyticsScreenState();
}

class _BorderAnalyticsScreenState extends State<BorderAnalyticsScreen> {
  bool _isLoading = true;
  String? _error;
  List<border_model.Border> _availableBorders = [];
  border_model.Border? _selectedBorder;
  DashboardData? _dashboardData;
  String _selectedTimeframe = '7d'; // 1d, 7d, 30d, 90d, custom
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    _loadAvailableBorders();
  }

  Future<void> _loadAvailableBorders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      List<border_model.Border> borders;

      // If authorityId is provided, get borders for that authority
      // Otherwise, get borders assigned to current user (for border managers)
      if (widget.authorityId != null) {
        borders = await _getBordersForAuthority(widget.authorityId!);
      } else {
        borders =
            await BorderManagerService.getAssignedBordersForCurrentManager();
      }

      setState(() {
        _availableBorders = borders;
        _selectedBorder = borders.isNotEmpty ? borders.first : null;
        _isLoading = false;
      });

      // Load dashboard data for the first border
      if (_selectedBorder != null) {
        await _loadDashboardData();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<border_model.Border>> _getBordersForAuthority(
      String authorityId) async {
    // Get borders for the specified authority
    final response = await BorderManagerService.supabase
        .from('borders')
        .select(
            'id, name, description, authority_id, border_type_id, is_active, latitude, longitude, created_at, updated_at')
        .eq('authority_id', authorityId)
        .eq('is_active', true)
        .order('name');

    return (response as List)
        .map((item) => border_model.Border.fromJson(item))
        .toList();
  }

  Future<void> _loadDashboardData() async {
    if (_selectedBorder == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final dashboardData =
          await BorderManagerDashboardService.getDashboardDataForBorder(
              _selectedBorder!.id, _selectedTimeframe);

      setState(() {
        _dashboardData = dashboardData;
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
        title: Text(widget.authorityName != null
            ? 'Border Analytics - ${widget.authorityName}'
            : 'Border Analytics'),
        backgroundColor: Colors.purple.shade700,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showDateRangePicker,
            tooltip: 'Select Custom Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Analytics Data',
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
            'Failed to load border analytics',
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
            onPressed: _loadAvailableBorders,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    if (_availableBorders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.border_clear, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Borders Available',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              widget.authorityId != null
                  ? 'No borders found for this authority.'
                  : 'You do not have access to any border analytics.',
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
          _buildBorderSelector(),
          const SizedBox(height: 16),
          _buildTimeframeSelector(),
          const SizedBox(height: 24),
          if (_dashboardData != null) ...[
            _buildMetricsCards(),
            const SizedBox(height: 24),
            _buildChartsSection(),
            const SizedBox(height: 24),
            _buildAlertsSection(),
            const SizedBox(height: 24),
            _buildRecentActivitySection(),
          ] else
            const Center(child: Text('Select a border to view analytics data')),
        ],
      ),
    );
  }

  Widget _buildBorderSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Border for Analysis',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<border_model.Border>(
              value: _selectedBorder,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _availableBorders.map((border) {
                return DropdownMenuItem(
                  value: border,
                  child: Text(border.name),
                );
              }).toList(),
              onChanged: (border) {
                setState(() {
                  _selectedBorder = border;
                });
                if (border != null) {
                  _loadDashboardData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.purple.shade50, Colors.purple.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.purple.shade700, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Analysis Time Period',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.purple.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Select the time range for border analytics calculations',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.purple.shade600,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTimeframeChip('1d', 'Last 24 Hours'),
                  _buildTimeframeChip('7d', 'Last 7 Days'),
                  _buildTimeframeChip('30d', 'Last 30 Days'),
                  _buildTimeframeChip('90d', 'Last 3 Months'),
                  _buildTimeframeChip('custom', 'Custom Range'),
                ],
              ),
              const SizedBox(height: 12),
              _buildTimeframeDescription(),
              if (_selectedTimeframe == 'custom' &&
                  _customStartDate != null &&
                  _customEndDate != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: Colors.purple.shade700, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatDate(_customStartDate!)} - ${_formatDate(_customEndDate!)}',
                        style: TextStyle(
                          color: Colors.purple.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_customEndDate!.difference(_customStartDate!).inDays + 1} days',
                        style: TextStyle(
                          color: Colors.purple.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeframeChip(String value, String label) {
    final isSelected = _selectedTimeframe == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          if (value == 'custom') {
            _showDateRangePicker();
          } else {
            setState(() {
              _selectedTimeframe = value;
            });
            _loadDashboardData();
          }
        }
      },
      selectedColor: Colors.purple.shade100,
      checkmarkColor: Colors.purple.shade700,
      backgroundColor: Colors.purple.shade50,
      labelStyle: TextStyle(
        color: isSelected ? Colors.purple.shade800 : Colors.purple.shade600,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildMetricsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.analytics, color: Colors.purple.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Key Performance Metrics',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.purple.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Real-time border performance indicators and statistics',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.purple.shade600,
              ),
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
            _buildMetricCard(
              'Total Passes',
              _dashboardData!.totalPasses.toString(),
              Icons.confirmation_number,
              Colors.purple.shade600,
              'Total passes issued for this border',
            ),
            _buildMetricCard(
              'Active Passes',
              _dashboardData!.activePasses.toString(),
              Icons.check_circle,
              Colors.green.shade600,
              'Currently valid and active passes',
            ),
            _buildMetricCard(
              'Vehicles in Country',
              _dashboardData!.vehiclesInCountry.toString(),
              Icons.directions_car,
              Colors.orange.shade600,
              'Vehicles currently inside the country',
            ),
            _buildMetricCard(
              'Total Revenue',
              '\$${_dashboardData!.totalRevenue.toStringAsFixed(0)}',
              Icons.attach_money,
              Colors.blue.shade600,
              'Revenue generated from pass sales',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon,
      Color color, String description) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, color.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up, color: Colors.purple.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Trends & Analytics',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.purple.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Visual representation of border activity patterns and revenue trends',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.purple.shade600,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildPassesChart()),
            const SizedBox(width: 16),
            Expanded(child: _buildRevenueChart()),
          ],
        ),
      ],
    );
  }

  Widget _buildPassesChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.purple.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart,
                      color: Colors.purple.shade600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pass Volume Trends',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.purple.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Daily pass issuance patterns showing border traffic volume',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.purple.shade600,
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: _buildCustomBarChart(
                  _dashboardData!.passesOverTime,
                  Colors.purple.shade600,
                  'Passes',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.green.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up,
                      color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Revenue Trends',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Daily revenue generation from border pass sales',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green.shade600,
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: _buildCustomBarChart(
                  _dashboardData!.revenueOverTime,
                  Colors.green.shade600,
                  'Revenue (\$)',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.security, color: Colors.purple.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Compliance & Alerts',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.purple.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Real-time monitoring of compliance issues and security alerts',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.purple.shade600,
              ),
        ),
        const SizedBox(height: 16),
        if (_dashboardData!.alerts.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    'No Active Compliance Issues',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          )
        else
          ..._dashboardData!.alerts.take(5).map((alert) => Card(
                color: _getAlertColor(alert.severity).withValues(alpha: 0.1),
                child: ListTile(
                  leading: Icon(
                    _getAlertIcon(alert.type),
                    color: _getAlertColor(alert.severity),
                  ),
                  title: Text(alert.title),
                  subtitle: Text('${alert.vehicleInfo} - ${alert.description}'),
                  trailing: Chip(
                    label: Text(alert.severity.toUpperCase()),
                    backgroundColor:
                        _getAlertColor(alert.severity).withValues(alpha: 0.2),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, color: Colors.purple.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Recent Border Activity',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.purple.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Latest border transactions and vehicle movements',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.purple.shade600,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _dashboardData!.recentActivity.length.clamp(0, 10),
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final activity = _dashboardData!.recentActivity[index];
              return ListTile(
                leading: Icon(
                  _getActivityIcon(activity.type),
                  color: _getActivityColor(activity.type),
                ),
                title: Text(activity.description),
                subtitle: Text(activity.vehicleInfo),
                trailing: Text(
                  _formatTimestamp(activity.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getAlertColor(String severity) {
    switch (severity) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.yellow.shade700;
      default:
        return Colors.grey;
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'overstay':
        return Icons.schedule;
      case 'expired':
        return Icons.warning;
      case 'suspicious':
        return Icons.security;
      default:
        return Icons.info;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'purchase':
        return Icons.shopping_cart;
      case 'checkin':
        return Icons.login;
      case 'checkout':
        return Icons.logout;
      case 'expired':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'purchase':
        return Colors.blue;
      case 'checkin':
        return Colors.green;
      case 'checkout':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildTimeframeDescription() {
    String description;
    switch (_selectedTimeframe) {
      case '1d':
        description =
            'Real-time border activity and current day performance metrics';
        break;
      case '7d':
        description = 'Weekly performance trends and pass volume patterns';
        break;
      case '30d':
        description =
            'Monthly analytics overview with revenue and compliance insights';
        break;
      case '90d':
        description =
            'Quarterly insights showing long-term border performance trends';
        break;
      case 'custom':
        description = 'Custom date range analysis for specific time periods';
        break;
      default:
        description = 'Select a time period to view analytics';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.purple.shade600, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: Colors.purple.shade700,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Colors.purple.shade700,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedTimeframe = 'custom';
      });
      _loadDashboardData();
    }
  }

  /// Custom bar chart widget that doesn't depend on fl_chart
  Widget _buildCustomBarChart(List<ChartData> data, Color color, String label) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      );
    }

    final maxValue = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) {
      return Center(
        child: Text(
          'No $label data',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: data.map((chartData) {
              final height =
                  (chartData.value / maxValue * 150).clamp(5.0, 150.0);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Value label on top of bar
                      if (chartData.value > 0)
                        Text(
                          chartData.value.toInt().toString(),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      const SizedBox(height: 4),
                      // Bar
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // X-axis labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: data.map((chartData) {
            return Expanded(
              child: Text(
                chartData.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                    ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
