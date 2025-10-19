import 'package:flutter/material.dart';
import '../models/border.dart' as border_model;
import '../services/border_manager_service.dart';
import '../services/border_managers_analytics_service.dart';

class BorderManagersAnalyticsScreen extends StatefulWidget {
  final String? authorityId;
  final String? authorityName;

  const BorderManagersAnalyticsScreen({
    super.key,
    this.authorityId,
    this.authorityName,
  });

  @override
  State<BorderManagersAnalyticsScreen> createState() =>
      _BorderManagersAnalyticsScreenState();
}

class _BorderManagersAnalyticsScreenState
    extends State<BorderManagersAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  List<border_model.Border> _availableBorders = [];
  border_model.Border? _selectedBorder;
  BorderManagersAnalyticsData? _analyticsData;
  BorderManagersAnalyticsData? _comparisonData;

  // Date filter options
  String _selectedDateFilter =
      'today'; // today, tomorrow, next_week, next_month
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Comparison options
  bool _showComparison = false;
  String _comparisonType =
      'previous_period'; // previous_period, same_period_last_year

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAvailableBorders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableBorders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      List<border_model.Border> borders;
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

      if (_selectedBorder != null) {
        await _loadAnalyticsData();
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

  Future<void> _loadAnalyticsData() async {
    if (_selectedBorder == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final analyticsData =
          await BorderManagersAnalyticsService.getAnalyticsData(
        _selectedBorder!.id,
        _selectedDateFilter,
        customStartDate: _customStartDate,
        customEndDate: _customEndDate,
      );

      BorderManagersAnalyticsData? comparisonData;
      if (_showComparison) {
        comparisonData = await BorderManagersAnalyticsService.getComparisonData(
          _selectedBorder!.id,
          _selectedDateFilter,
          _comparisonType,
          customStartDate: _customStartDate,
          customEndDate: _customEndDate,
        );
      }

      setState(() {
        _analyticsData = analyticsData;
        _comparisonData = comparisonData;
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
            ? 'Border Managers Analytics - ${widget.authorityName}'
            : 'Border Managers Analytics'),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.directions_car), text: 'Vehicle Flow'),
            Tab(icon: Icon(Icons.category), text: 'Vehicle Types'),
            Tab(icon: Icon(Icons.confirmation_number), text: 'Pass Analysis'),
            Tab(icon: Icon(Icons.warning), text: 'Missed Scans'),
            Tab(icon: Icon(Icons.attach_money), text: 'Revenue'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showComparison ? Icons.compare_arrows : Icons.compare),
            onPressed: () {
              setState(() {
                _showComparison = !_showComparison;
              });
              if (_showComparison) {
                _loadAnalyticsData();
              }
            },
            tooltip: _showComparison ? 'Hide Comparison' : 'Show Comparison',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalyticsData,
            tooltip: 'Refresh Data',
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
            'Failed to load analytics data',
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

    return Column(
      children: [
        _buildControlsSection(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildVehicleFlowTab(),
              _buildVehicleTypesTab(),
              _buildPassAnalysisTab(),
              _buildMissedScansTab(),
              _buildRevenueTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        border: Border(bottom: BorderSide(color: Colors.indigo.shade200)),
      ),
      child: Column(
        children: [
          // Border Selector
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Border',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.indigo.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<border_model.Border>(
                      value: _selectedBorder,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        fillColor: Colors.white,
                        filled: true,
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
                          _loadAnalyticsData();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Date Filter
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Period',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.indigo.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedDateFilter,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'today', child: Text('Today')),
                        DropdownMenuItem(
                            value: 'tomorrow', child: Text('Tomorrow')),
                        DropdownMenuItem(
                            value: 'next_week', child: Text('Next Week')),
                        DropdownMenuItem(
                            value: 'next_month', child: Text('Next Month')),
                        DropdownMenuItem(
                            value: 'custom', child: Text('Custom Range')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedDateFilter = value;
                          });
                          if (value == 'custom') {
                            _showCustomDatePicker();
                          } else {
                            _loadAnalyticsData();
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (_showComparison) ...[
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compare With',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Colors.indigo.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: _comparisonType,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'previous_period',
                            child: Text('Previous Period'),
                          ),
                          DropdownMenuItem(
                            value: 'same_period_last_year',
                            child: Text('Same Period Last Year'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _comparisonType = value;
                            });
                            _loadAnalyticsData();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (_selectedDateFilter == 'custom' &&
              _customStartDate != null &&
              _customEndDate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      color: Colors.indigo.shade700, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatDate(_customStartDate!)} - ${_formatDate(_customEndDate!)}',
                    style: TextStyle(
                      color: Colors.indigo.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_customEndDate!.difference(_customStartDate!).inDays + 1} days',
                    style: TextStyle(
                      color: Colors.indigo.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_analyticsData == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewMetrics(),
          const SizedBox(height: 24),
          _buildQuickInsights(),
        ],
      ),
    );
  }

  Widget _buildOverviewMetrics() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildMetricCard(
          'Expected Check-ins',
          _analyticsData!.expectedCheckIns.toString(),
          Icons.login,
          Colors.green.shade600,
          _showComparison ? _comparisonData?.expectedCheckIns : null,
        ),
        _buildMetricCard(
          'Expected Check-outs',
          _analyticsData!.expectedCheckOuts.toString(),
          Icons.logout,
          Colors.orange.shade600,
          _showComparison ? _comparisonData?.expectedCheckOuts : null,
        ),
        _buildMetricCard(
          'Expected Revenue',
          '\$${_analyticsData!.expectedRevenue.toStringAsFixed(0)}',
          Icons.attach_money,
          Colors.blue.shade600,
          _showComparison ? _comparisonData?.expectedRevenue : null,
        ),
        _buildMetricCard(
          'Active Passes',
          _analyticsData!.activePasses.toString(),
          Icons.confirmation_number,
          Colors.purple.shade600,
          _showComparison ? _comparisonData?.activePasses : null,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon,
      Color color, dynamic comparisonValue) {
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
              if (_showComparison && comparisonValue != null) ...[
                const SizedBox(height: 8),
                _buildComparisonIndicator(value, comparisonValue.toString()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonIndicator(
      String currentValue, String comparisonValue) {
    // Parse numeric values for comparison
    final current =
        double.tryParse(currentValue.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    final comparison =
        double.tryParse(comparisonValue.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;

    if (comparison == 0) return const SizedBox.shrink();

    final percentChange = ((current - comparison) / comparison * 100);
    final isPositive = percentChange > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            size: 16,
            color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            '${percentChange.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInsights() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Insights',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInsightItem(
              Icons.info,
              'Peak Traffic Expected',
              _analyticsData!.peakTrafficTime,
              Colors.blue,
            ),
            _buildInsightItem(
              Icons.trending_up,
              'Busiest Vehicle Type',
              _analyticsData!.topVehicleType,
              Colors.green,
            ),
            _buildInsightItem(
              Icons.warning,
              'Potential Issues',
              '${_analyticsData!.missedCheckIns + _analyticsData!.missedCheckOuts} missed scans expected',
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(
      IconData icon, String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  value,
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

  Widget _buildVehicleFlowTab() {
    if (_analyticsData == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVehicleFlowMetrics(),
          const SizedBox(height: 24),
          _buildTrafficFlowChart(),
          const SizedBox(height: 24),
          _buildHourlyDistributionChart(),
        ],
      ),
    );
  }

  Widget _buildVehicleFlowMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle Flow Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildFlowMetricCard(
                    'Expected Check-ins',
                    _analyticsData!.expectedCheckIns,
                    Icons.login,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFlowMetricCard(
                    'Actual Check-ins',
                    _analyticsData!.actualCheckIns,
                    Icons.check_circle,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildFlowMetricCard(
                    'Expected Check-outs',
                    _analyticsData!.expectedCheckOuts,
                    Icons.logout,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFlowMetricCard(
                    'Actual Check-outs',
                    _analyticsData!.actualCheckOuts,
                    Icons.check_circle_outline,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowMetricCard(
      String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficFlowChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Traffic Flow Pattern',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              child: Center(
                child: Text(
                  'Traffic flow visualization would go here\n(Line chart showing check-ins vs check-outs over time)',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyDistributionChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Peak Traffic Hours',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Peak time: ${_analyticsData!.peakTrafficTime}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.indigo.shade600,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              child: _buildHourlyDistributionBars(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyDistributionBars() {
    final hourlyData = _analyticsData!.hourlyDistribution;
    if (hourlyData.isEmpty) {
      return const Center(child: Text('No hourly data available'));
    }

    final maxValue = hourlyData.values.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) {
      return const Center(child: Text('No traffic data'));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: hourlyData.entries.map((entry) {
        final height = (entry.value / maxValue * 150).clamp(5.0, 150.0);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (entry.value > 0)
                  Text(
                    entry.value.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                const SizedBox(height: 4),
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade600,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.key.substring(0, 2),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 9,
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVehicleTypesTab() {
    if (_analyticsData == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVehicleTypesOverview(),
          const SizedBox(height: 24),
          _buildVehicleTypesBreakdown(),
        ],
      ),
    );
  }

  Widget _buildVehicleTypesOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle Types Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text(
                  'Top Vehicle Type: ${_analyticsData!.topVehicleType}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Total Vehicle Types: ${_analyticsData!.vehicleTypeBreakdown.length}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleTypesBreakdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ..._analyticsData!.vehicleTypeBreakdown.entries.map((entry) {
              final analytics = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
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
                              _getVehicleTypeIcon(analytics.vehicleType),
                              color: Colors.indigo.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  analytics.vehicleType,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  'Revenue: \$${analytics.revenue.toStringAsFixed(0)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.green.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildVehicleTypeMetric(
                              'Expected In',
                              analytics.expectedCheckIns,
                              Colors.green,
                            ),
                          ),
                          Expanded(
                            child: _buildVehicleTypeMetric(
                              'Expected Out',
                              analytics.expectedCheckOuts,
                              Colors.orange,
                            ),
                          ),
                          Expanded(
                            child: _buildVehicleTypeMetric(
                              'Missed Scans',
                              analytics.missedScans,
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleTypeMetric(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  IconData _getVehicleTypeIcon(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'truck':
        return Icons.local_shipping;
      case 'bus':
        return Icons.directions_bus;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'van':
        return Icons.airport_shuttle;
      default:
        return Icons.directions_car;
    }
  }

  Widget _buildPassAnalysisTab() {
    if (_analyticsData == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPassStatusOverview(),
          const SizedBox(height: 24),
          _buildPassTypeBreakdown(),
        ],
      ),
    );
  }

  Widget _buildPassStatusOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pass Status Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPassStatusCard(
                    'Active Passes',
                    _analyticsData!.activePasses,
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPassStatusCard(
                    'Expired Passes',
                    _analyticsData!.expiredPasses,
                    Icons.warning,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPassStatusCard(
                    'Upcoming Passes',
                    _analyticsData!.upcomingPasses,
                    Icons.schedule,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassStatusCard(
      String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassTypeBreakdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pass Type Analysis',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ..._analyticsData!.passBreakdown.map((passAnalytics) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.confirmation_number,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                  title: Text(
                    passAnalytics.passType,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Count: ${passAnalytics.count} | Value: \$${passAnalytics.totalValue.toStringAsFixed(0)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${passAnalytics.expectedCheckIns}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'Expected',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMissedScansTab() {
    if (_analyticsData == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMissedScansOverview(),
          const SizedBox(height: 24),
          _buildMissedScansBreakdown(),
        ],
      ),
    );
  }

  Widget _buildMissedScansOverview() {
    final totalMissedScans =
        _analyticsData!.missedCheckIns + _analyticsData!.missedCheckOuts;
    final totalExpected =
        _analyticsData!.expectedCheckIns + _analyticsData!.expectedCheckOuts;
    final missedPercentage =
        totalExpected > 0 ? (totalMissedScans / totalExpected * 100) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Missed Scans Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMissedScanCard(
                    'Missed Check-ins',
                    _analyticsData!.missedCheckIns,
                    Icons.login,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMissedScanCard(
                    'Missed Check-outs',
                    _analyticsData!.missedCheckOuts,
                    Icons.logout,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMissedScanCard(
                    'Total Missed',
                    totalMissedScans,
                    Icons.warning,
                    Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: missedPercentage > 10
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: missedPercentage > 10
                      ? Colors.red.shade200
                      : Colors.green.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    missedPercentage > 10 ? Icons.error : Icons.check_circle,
                    color: missedPercentage > 10
                        ? Colors.red.shade600
                        : Colors.green.shade600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Compliance Rate',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          '${(100 - missedPercentage).toStringAsFixed(1)}% of expected scans completed',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissedScanCard(
      String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissedScansBreakdown() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Missed Scans by Vehicle Type',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ..._analyticsData!.vehicleTypeBreakdown.entries
                .where((entry) => entry.value.missedScans > 0)
                .map((entry) {
              final analytics = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getVehicleTypeIcon(analytics.vehicleType),
                      color: Colors.red.shade700,
                    ),
                  ),
                  title: Text(
                    analytics.vehicleType,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Expected: ${analytics.expectedCheckIns + analytics.expectedCheckOuts} scans',
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${analytics.missedScans} missed',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            if (_analyticsData!.vehicleTypeBreakdown.values
                .every((analytics) => analytics.missedScans == 0))
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No missed scans detected for any vehicle type',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueTab() {
    if (_analyticsData == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRevenueOverview(),
          const SizedBox(height: 24),
          _buildRevenueComparison(),
          const SizedBox(height: 24),
          _buildDailyRevenueChart(),
        ],
      ),
    );
  }

  Widget _buildRevenueOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRevenueCard(
                    'Expected Revenue',
                    _analyticsData!.expectedRevenue,
                    Icons.trending_up,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRevenueCard(
                    'Actual Revenue',
                    _analyticsData!.actualRevenue,
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRevenueCard(
                    'Missed Revenue',
                    _analyticsData!.missedRevenue,
                    Icons.money_off,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard(
      String title, double value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            '\$${value.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueComparison() {
    if (!_showComparison || _comparisonData == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Comparison',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildComparisonRow(
              'Expected Revenue',
              _analyticsData!.expectedRevenue,
              _comparisonData!.expectedRevenue,
            ),
            const SizedBox(height: 8),
            _buildComparisonRow(
              'Actual Revenue',
              _analyticsData!.actualRevenue,
              _comparisonData!.actualRevenue,
            ),
            const SizedBox(height: 8),
            _buildComparisonRow(
              'Pass Volume',
              _analyticsData!.activePasses.toDouble(),
              _comparisonData!.activePasses.toDouble(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String label, double current, double comparison) {
    final percentChange =
        comparison > 0 ? ((current - comparison) / comparison * 100) : 0.0;
    final isPositive = percentChange > 0;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Text(
            label.contains('Volume')
                ? current.toInt().toString()
                : '\$${current.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPositive ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color:
                      isPositive ? Colors.green.shade700 : Colors.red.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  '${percentChange.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isPositive
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyRevenueChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Revenue Breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              child: Center(
                child: Text(
                  'Daily revenue chart would go here\n(Bar chart showing expected vs actual revenue by day)',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomDatePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(
              start: DateTime.now(),
              end: DateTime.now().add(const Duration(days: 7)),
            ),
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedDateFilter = 'custom';
      });
      _loadAnalyticsData();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
