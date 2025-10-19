import 'package:flutter/material.dart';
import '../models/border.dart' as border_model;
import '../services/border_manager_service.dart';
import '../services/border_manager_dashboard_service.dart';
import '../services/border_forecast_service.dart';
import '../services/border_officials_service_simple.dart';
import '../services/authority_service.dart';
import '../utils/date_utils.dart' as date_utils;
import '../widgets/pass_details_dialog.dart';
import '../widgets/border_officials_heat_map.dart';

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

class _BorderAnalyticsScreenState extends State<BorderAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  List<border_model.Border> _availableBorders = [];
  border_model.Border? _selectedBorder;
  DashboardData? _dashboardData;
  String _selectedTimeframe = '7d'; // 1d, 7d, 30d, 90d, custom
  String _authorityCurrency =
      'USD'; // Default to USD, will be updated with authority's currency
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Forecast data
  ForecastData? _forecastData;
  ForecastData? _comparisonForecastData;
  String _forecastDateFilter =
      'today'; // today, tomorrow, next_week, next_month
  bool _showForecastComparison = false;

  // Border Officials data
  BorderOfficialsData? _officialsData;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAuthorityCurrency();
    _loadAvailableBorders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthorityCurrency() async {
    if (widget.authorityId == null) {
      debugPrint(
          '⚠️ No authorityId provided, using default currency: $_authorityCurrency');
      return;
    }

    try {
      debugPrint(
          '🏛️ Loading authority currency for ID: ${widget.authorityId}');
      final authority =
          await AuthorityService.getAuthorityById(widget.authorityId!);

      if (authority != null) {
        debugPrint('🏛️ Authority loaded: ${authority.name}');
        debugPrint(
            '🏛️ Authority defaultCurrencyCode: "${authority.defaultCurrencyCode}"');

        if (authority.defaultCurrencyCode != null &&
            authority.defaultCurrencyCode!.isNotEmpty) {
          setState(() {
            _authorityCurrency = authority.defaultCurrencyCode!;
          });
          debugPrint('✅ Authority currency updated to: $_authorityCurrency');
          debugPrint(
              '✅ Currency symbol will be: ${_getCurrencySymbol(_authorityCurrency)}');
        } else {
          debugPrint(
              '⚠️ Authority defaultCurrencyCode is null or empty, using default: $_authorityCurrency');
        }
      } else {
        debugPrint('❌ Authority not found for ID: ${widget.authorityId}');
      }
    } catch (e) {
      debugPrint('❌ Error loading authority currency: $e');
    }
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

      // Load data for the first border
      if (_selectedBorder != null) {
        // Ensure currency is loaded before loading forecast data
        await _loadAuthorityCurrency();
        await _loadDashboardData();
        await _loadForecastData();

        // Load officials data with error handling
        try {
          debugPrint('🎯 About to load officials data during initial load...');
          await _loadOfficialsData();
        } catch (e) {
          debugPrint('🎯 Error during initial officials data load: $e');
        }
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

  Future<void> _loadForecastData() async {
    if (_selectedBorder == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final forecastData = await BorderForecastService.getForecastData(
        _selectedBorder!.id,
        _forecastDateFilter,
        customStartDate: _customStartDate,
        customEndDate: _customEndDate,
      );

      ForecastData? comparisonData;
      if (_showForecastComparison) {
        comparisonData = await BorderForecastService.getComparisonForecastData(
          _selectedBorder!.id,
          _forecastDateFilter,
          'previous_period',
          customStartDate: _customStartDate,
          customEndDate: _customEndDate,
        );
      }

      setState(() {
        _forecastData = forecastData;
        _comparisonForecastData = comparisonData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOfficialsData() async {
    debugPrint('🎯 === LOADING OFFICIALS DATA ===');
    debugPrint(
        '🎯 Selected border: ${_selectedBorder?.name} (${_selectedBorder?.id})');
    debugPrint('🎯 Selected timeframe: $_selectedTimeframe');
    debugPrint('🎯 Custom dates: $_customStartDate to $_customEndDate');

    if (_selectedBorder == null) {
      debugPrint('🎯 No border selected, skipping officials data load');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      debugPrint('🎯 Calling BorderOfficialsService.getBorderOfficialsData...');
      final officialsData = await BorderOfficialsService.getBorderOfficialsData(
        _selectedBorder!.id,
        _selectedTimeframe,
        customStartDate: _customStartDate,
        customEndDate: _customEndDate,
      );

      debugPrint(
          '🎯 Officials data loaded successfully: ${officialsData.officials.length} officials');
      setState(() {
        _officialsData = officialsData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('🎯 Error loading officials data: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
    debugPrint('🎯 === END LOADING OFFICIALS DATA ===');
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.people), text: 'Officials'),
            Tab(icon: Icon(Icons.trending_up), text: 'Forecast'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _showDateRangePicker,
            tooltip: 'Select Custom Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              switch (_tabController.index) {
                case 0:
                  _loadDashboardData();
                  break;
                case 1:
                  _loadOfficialsData();
                  break;
                case 2:
                  _loadForecastData();
                  break;
              }
            },
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAnalyticsContent(),
                    _buildOfficialsContent(),
                    _buildForecastContent(),
                  ],
                ),
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
            _loadOfficialsData();
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
              '${_getCurrencySymbol(_authorityCurrency)}${_dashboardData!.totalRevenue.toStringAsFixed(0)}',
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

  String _getCurrencySymbol(String currencyCode) {
    debugPrint('💰 Getting currency symbol for: "$currencyCode"');
    final symbol = _getCurrencySymbolInternal(currencyCode);
    debugPrint('💰 Currency symbol result: "$symbol"');
    return symbol;
  }

  String _getCurrencySymbolInternal(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'USD':
        return 'USD ';
      case 'EUR':
        return 'EUR ';
      case 'GBP':
        return 'GBP ';
      case 'JPY':
        return 'JPY ';
      case 'CAD':
        return 'C\$';
      case 'AUD':
        return 'A\$';
      case 'CHF':
        return 'CHF ';
      case 'CNY':
        return '¥';
      case 'INR':
        return '₹';
      case 'KRW':
        return '₩';
      case 'BRL':
        return 'R\$';
      case 'RUB':
        return '₽';

      case 'MXN':
        return 'MX\$';
      case 'SGD':
        return 'S\$';
      case 'HKD':
        return 'HK\$';
      case 'NOK':
        return 'kr';
      case 'SEK':
        return 'kr';
      case 'DKK':
        return 'kr';
      case 'PLN':
        return 'zł';
      case 'CZK':
        return 'Kč';
      case 'HUF':
        return 'Ft';
      case 'TRY':
        return '₺';
      case 'ILS':
        return '₪';
      case 'AED':
        return 'د.إ';
      case 'SAR':
        return 'ر.س';
      case 'EGP':
        return 'ج.م';
      case 'NGN':
        return '₦';
      case 'KES':
        return 'KSh';
      case 'GHS':
        return 'GH₵';
      case 'MAD':
        return 'د.م.';
      case 'TND':
        return 'د.ت';
      case 'DZD':
        return 'د.ج';
      case 'XOF': // West African CFA franc
        return 'CFA';
      case 'XAF': // Central African CFA franc
        return 'FCFA';
      case 'SZL': // Swazi Lilangeni
        return 'SZL ';
      case 'BWP': // Botswana Pula
        return 'BWP ';
      case 'NAD': // Namibian Dollar
        return 'NAD ';
      case 'ZMW': // Zambian Kwacha
        return 'ZMW ';
      case 'TZS': // Tanzanian Shilling
        return 'TZS ';
      case 'LSL': // Lesotho Loti
        return 'LSL ';
      case 'AOA': // Angolan Kwanza
        return 'AOA ';
      case 'MZN': // Mozambican Metical
        return 'MZN ';
      case 'ZAR': // South African Rand
        return 'ZAR ';
      default:
        return '$currencyCode ';
    }
  }

  void _showPassDetails(PassForecast pass) {
    showDialog(
      context: context,
      builder: (context) => PassDetailsDialog(pass: pass),
    );
  }

  void _showAllPasses(String title, List<PassForecast> passes, bool isCheckIn) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:
                      isCheckIn ? Colors.green.shade700 : Colors.red.shade700,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCheckIn ? Icons.login : Icons.logout,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: passes.length,
                  itemBuilder: (context, index) {
                    final pass = passes[index];
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        _showPassDetails(pass);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${pass.passType} - ${pass.vehicleDescription}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${_getCurrencySymbol(_authorityCurrency)}${pass.amount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isCheckIn
                                      ? date_utils.DateUtils.formatFriendlyDate(
                                          pass.activationDate)
                                      : date_utils.DateUtils.formatFriendlyDate(
                                          pass.expirationDate),
                                  style: TextStyle(
                                    color: date_utils.DateUtils.getDateColor(
                                      isCheckIn
                                          ? pass.activationDate
                                          : pass.expirationDate,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  pass.passId.substring(0, 8),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassSection(
    String title,
    List<PassForecast> passes,
    IconData icon,
    MaterialColor color,
    bool isCheckIn,
  ) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with colored background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color.shade700, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: color.shade800,
                                  ),
                        ),
                        Text(
                          '${passes.length} pass${passes.length == 1 ? '' : 'es'}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: color.shade600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // Count badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      passes.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Pass list
            if (passes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.grey.shade400, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No ${isCheckIn ? 'check-ins' : 'check-outs'} scheduled',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...passes.take(5).map((pass) {
                return InkWell(
                  onTap: () => _showPassDetails(pass),
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      pass.passType,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_getCurrencySymbol(_authorityCurrency)}${pass.amount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pass.vehicleDescription,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isCheckIn
                                    ? date_utils.DateUtils.formatListDate(
                                        pass.activationDate)
                                    : date_utils.DateUtils.formatListDate(
                                        pass.expirationDate),
                                style: TextStyle(
                                  color: date_utils.DateUtils.getDateColor(
                                    isCheckIn
                                        ? pass.activationDate
                                        : pass.expirationDate,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Pass ID in corner
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              pass.passId.substring(0, 8),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),

            // Show more button if there are more passes
            if (passes.length > 5)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: TextButton(
                    onPressed: () => _showAllPasses(title, passes, isCheckIn),
                    child: Text(
                      'Show ${passes.length - 5} more',
                      style: TextStyle(color: color.shade700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

  Widget _buildOfficialsContent() {
    debugPrint('🎯 Building Officials tab content...');
    debugPrint('🎯 Available borders: ${_availableBorders.length}');
    debugPrint(
        '🎯 Officials data: ${_officialsData != null ? "loaded" : "null"}');

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
                  : 'You do not have access to any border officials data.',
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
          if (_officialsData != null) ...[
            _buildOfficialsOverview(),
            const SizedBox(height: 24),
            _buildOfficialsPerformance(),
            const SizedBox(height: 24),
            _buildOfficialsHeatMap(),
          ] else
            const Center(child: Text('Loading border officials data...')),
        ],
      ),
    );
  }

  Widget _buildOfficialsOverview() {
    final overview = _officialsData!.overview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people, color: Colors.indigo.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Border Officials Overview',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.indigo.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
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
              'Scans Today',
              overview.totalScansToday.toString(),
              Icons.today,
              Colors.green.shade600,
              'Total passes scanned today',
            ),
            _buildMetricCard(
              'Avg Scans/Hour',
              overview.averageScansPerHour.toStringAsFixed(1),
              Icons.speed,
              Colors.blue.shade600,
              'Average scans per hour',
            ),
            _buildMetricCard(
              'Peak Hour',
              '${overview.peakHour}:00',
              Icons.trending_up,
              Colors.orange.shade600,
              'Most active hour of day',
            ),
            _buildMetricCard(
              'Active Officials',
              '${overview.activeOfficials}/${overview.totalOfficials}',
              Icons.people,
              Colors.indigo.shade600,
              'Currently active officials',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOfficialsPerformance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.leaderboard, color: Colors.indigo.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Top Performing Officials',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.indigo.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _officialsData!.officials.take(5).length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final official = _officialsData!.officials[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: official.isCurrentlyActive
                      ? Colors.green.shade100
                      : Colors.grey.shade200,
                  child: Icon(
                    Icons.person,
                    color: official.isCurrentlyActive
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      official.officialName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    if (!official.isCurrentlyActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Former',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  '${official.averageScansPerHour.toStringAsFixed(1)} scans/hour • ${official.successRate.toStringAsFixed(1)}% success rate',
                ),
                trailing: Text(
                  '${official.totalScans} scans',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade700,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOfficialsHeatMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.map, color: Colors.indigo.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Scan Location Heat Map',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.indigo.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Geographic distribution of scanning activities',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.indigo.shade600,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Container(
            height: 400,
            child: BorderOfficialsHeatMap(
              scanLocations: _officialsData!.scanLocations,
              selectedBorder: _selectedBorder,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForecastContent() {
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
          _buildForecastDateSelector(),
          const SizedBox(height: 24),
          if (_forecastData != null) ...[
            _buildForecastMetrics(),
            const SizedBox(height: 24),
            _buildVehicleTypeForecast(),
            const SizedBox(height: 24),
            _buildUpcomingPasses(),
          ] else
            const Center(child: Text('Select a border to view forecast data')),
        ],
      ),
    );
  }

  Widget _buildForecastDateSelector() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.green.shade100],
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
                      color: Colors.green.shade700, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Forecast Period',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _showForecastComparison
                          ? Icons.compare_arrows
                          : Icons.compare,
                      color: Colors.green.shade700,
                    ),
                    onPressed: () {
                      setState(() {
                        _showForecastComparison = !_showForecastComparison;
                      });
                      if (_showForecastComparison) {
                        _loadForecastData();
                      }
                    },
                    tooltip: _showForecastComparison
                        ? 'Hide Comparison'
                        : 'Show Comparison',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Select the time period for border traffic forecasting',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade600,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildForecastDateChip('today', 'Today'),
                  _buildForecastDateChip('tomorrow', 'Tomorrow'),
                  _buildForecastDateChip('next_week', 'Next Week'),
                  _buildForecastDateChip('next_month', 'Next Month'),
                  _buildForecastDateChip('custom', 'Custom Range'),
                ],
              ),
              const SizedBox(height: 12),
              _buildForecastDateDescription(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForecastDateChip(String value, String label) {
    final isSelected = _forecastDateFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          if (value == 'custom') {
            _showForecastDateRangePicker();
          } else {
            setState(() {
              _forecastDateFilter = value;
            });
            _loadForecastData();
          }
        }
      },
      selectedColor: Colors.green.shade100,
      checkmarkColor: Colors.green.shade700,
      backgroundColor: Colors.green.shade50,
      labelStyle: TextStyle(
        color: isSelected ? Colors.green.shade800 : Colors.green.shade600,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildForecastDateDescription() {
    String description;
    switch (_forecastDateFilter) {
      case 'today':
        description =
            'Forecast for vehicles expected to cross the border today';
        break;
      case 'tomorrow':
        description =
            'Forecast for vehicles expected to cross the border tomorrow';
        break;
      case 'next_week':
        description = 'Weekly forecast for upcoming border traffic patterns';
        break;
      case 'next_month':
        description = 'Monthly forecast showing expected border activity';
        break;
      case 'custom':
        description = 'Custom date range forecast for specific time periods';
        break;
      default:
        description = 'Select a time period to view forecast';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.green.shade600, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastMetrics() {
    debugPrint(
        '📊 Building forecast metrics with currency: $_authorityCurrency');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up, color: Colors.green.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Traffic Forecast',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Expected vehicle movements based on pass activation dates',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.green.shade600,
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
            _buildForecastMetricCard(
              'Expected Check-ins',
              _forecastData!.expectedCheckIns.toString(),
              Icons.login,
              Colors.green.shade600,
              'Vehicles expected to enter',
              _showForecastComparison
                  ? _comparisonForecastData?.expectedCheckIns
                  : null,
            ),
            _buildForecastMetricCard(
              'Expected Check-outs',
              _forecastData!.expectedCheckOuts.toString(),
              Icons.logout,
              Colors.red.shade600,
              'Vehicles expected to exit',
              _showForecastComparison
                  ? _comparisonForecastData?.expectedCheckOuts
                  : null,
            ),
            _buildForecastMetricCard(
              'Expected Revenue',
              '${_getCurrencySymbol(_authorityCurrency)}${_forecastData!.expectedRevenue.toStringAsFixed(0)}',
              Icons.attach_money,
              Colors.blue.shade600,
              'Revenue from upcoming passes',
              _showForecastComparison
                  ? _comparisonForecastData?.expectedRevenue
                  : null,
            ),
            _buildForecastMetricCard(
              'Upcoming Passes',
              _forecastData!.totalUpcomingPasses.toString(),
              Icons.confirmation_number,
              Colors.orange.shade600,
              'Total passes in forecast period',
              _showForecastComparison
                  ? _comparisonForecastData?.totalUpcomingPasses
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForecastMetricCard(String title, String value, IconData icon,
      Color color, String description, dynamic comparisonValue) {
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
              if (_showForecastComparison && comparisonValue != null) ...[
                const SizedBox(height: 8),
                _buildForecastComparisonIndicator(
                    value, comparisonValue.toString()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForecastComparisonIndicator(
      String currentValue, String comparisonValue) {
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

  Widget _buildVehicleTypeForecast() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_car,
                    color: Colors.green.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Vehicle Type Forecast',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Top vehicle type: ${_forecastData!.topVehicleType}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            ..._forecastData!.vehicleTypeBreakdown.entries.map((entry) {
              final forecast = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getVehicleTypeIcon(forecast.vehicleType),
                      color: Colors.green.shade700,
                    ),
                  ),
                  title: Text(
                    forecast.vehicleType,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Expected: ${forecast.expectedCheckIns} in, ${forecast.expectedCheckOuts} out',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_getCurrencySymbol(_authorityCurrency)}${forecast.expectedRevenue.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const Text(
                        'Revenue',
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

  Widget _buildUpcomingPasses() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.confirmation_number,
                    color: Colors.green.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Passes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Passes scheduled for check-in and check-out',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade600,
                  ),
            ),
            const SizedBox(height: 16),
            if (_forecastData!.upcomingPasses.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(width: 12),
                    Text('No upcoming passes for the selected period'),
                  ],
                ),
              )
            else
              ..._forecastData!.upcomingPasses.take(10).map((pass) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Stack(
                    children: [
                      ListTile(
                        onTap: () => _showPassDetails(pass),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: pass.willCheckIn
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            pass.willCheckIn ? Icons.login : Icons.logout,
                            color: pass.willCheckIn
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                        title: Text(
                          '${pass.passType} - ${pass.vehicleDescription}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          pass.willCheckIn
                              ? 'Check-in: ${date_utils.DateUtils.formatListDate(pass.activationDate)}'
                              : 'Check-out: ${date_utils.DateUtils.formatListDate(pass.expirationDate)}',
                        ),
                        trailing: Text(
                          '${_getCurrencySymbol(_authorityCurrency)}${pass.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                      // Pass ID in corner
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pass.passId.substring(0, 8),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
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

  Future<void> _showForecastDateRangePicker() async {
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Colors.green.shade700,
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
        _forecastDateFilter = 'custom';
      });
      _loadForecastData();
    }
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
      _loadOfficialsData();
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
