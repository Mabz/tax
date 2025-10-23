import 'package:flutter/material.dart';
import '../models/border.dart' as border_model;
import '../services/border_manager_service.dart';
import '../services/border_manager_dashboard_service.dart' as dashboard;
import '../services/border_forecast_service.dart';
import '../services/border_officials_service_simple.dart' as officials;
import '../services/authority_service.dart';
import '../utils/date_utils.dart' as date_utils;
import '../widgets/pass_details_dialog.dart';
import '../widgets/enhanced_border_officials_heat_map.dart';
import '../widgets/official_audit_dialog.dart';
import '../screens/border_movement_screen_enhanced.dart';

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
  dashboard.DashboardData? _dashboardData;
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
  officials.BorderOfficialsData? _officialsData;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

      final dashboardData = await dashboard.BorderManagerDashboardService
          .getDashboardDataForBorder(_selectedBorder!.id, _selectedTimeframe);

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
      final officialsData =
          await officials.BorderOfficialsService.getBorderOfficialsData(
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
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.people), text: 'Officials'),
            Tab(icon: Icon(Icons.trending_up), text: 'Forecast'),
            Tab(icon: Icon(Icons.timeline), text: 'Movement'),
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
                case 3:
                  // Movement tab - no refresh needed as it has its own refresh
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
                    _buildMovementContent(),
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
                  _loadOfficialsData(); // Also reload Officials data when border changes
                  _loadForecastData(); // Also reload Forecast data when border changes
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
            // Reload both Analytics and Officials data to keep them in sync
            _loadDashboardData();
            _loadOfficialsData();
            // Also reload forecast data if needed
            if (_tabController.index == 2) {
              _loadForecastData();
            }
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Passes = purchased border passes • Scans = verification events by officials',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount:
              3, // Changed to 3 columns to accommodate 5 cards better
          childAspectRatio: 1.0, // Adjusted aspect ratio for better layout
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildMetricCard(
              'Total Passes',
              _dashboardData!.totalPasses.toString(),
              Icons.confirmation_number,
              Colors.purple.shade600,
              'Total passes purchased for this border',
            ),
            _buildMetricCard(
              'Total Scans',
              _officialsData?.overview.totalScansCustom.toString() ?? '0',
              Icons.qr_code_scanner,
              Colors.indigo.shade600,
              'Total scan/verification events by officials',
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
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () =>
                          _showMetricDescription(title, description, color),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          size: 14,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ],
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
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
            const Spacer(),
            IconButton(
              icon: Icon(Icons.info_outline,
                  color: Colors.purple.shade600, size: 20),
              onPressed: () => _showActivityDescription(),
              tooltip: 'Activity Information',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Latest border transactions and vehicle movements (tap for details)',
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
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final activity = _dashboardData!.recentActivity[index];
              return ListTile(
                onTap: () => _showActivityDetails(activity),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        _getActivityColor(activity.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getActivityIcon(activity.type),
                    color: _getActivityColor(activity.type),
                    size: 20,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        activity.description,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getActivityColor(activity.type)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getActivityTypeLabel(activity.type),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getActivityColor(activity.type),
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      activity.vehicleInfo,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimestamp(activity.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.location_on,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          _selectedBorder?.name ?? 'Border Checkpoint',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                ),
              );
            },
          ),
        ),
        if (_dashboardData!.recentActivity.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton(
                onPressed: () => _showAllRecentActivity(),
                child: Text(
                  'View All Activity (${_dashboardData!.recentActivity.length} total)',
                  style: TextStyle(color: Colors.purple.shade700),
                ),
              ),
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

  void _showActivityDescription() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(Icons.history, color: Colors.purple.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Recent Activity',
              style: TextStyle(
                color: Colors.purple.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Types:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _buildActivityTypeInfo('Purchase', Icons.shopping_cart, Colors.blue,
                'New pass purchased and payment processed'),
            _buildActivityTypeInfo('Check-in', Icons.login, Colors.green,
                'Vehicle entered the country using their pass'),
            _buildActivityTypeInfo('Check-out', Icons.logout, Colors.orange,
                'Vehicle exited the country'),
            _buildActivityTypeInfo('Expired', Icons.warning, Colors.red,
                'Pass has expired and is no longer valid'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap any activity item to view detailed information',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                Text('Got it', style: TextStyle(color: Colors.purple.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTypeInfo(
      String type, IconData icon, Color color, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showActivityDetails(dynamic activity) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getActivityColor(activity.type),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getActivityIcon(activity.type),
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getActivityTypeLabel(activity.type),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            _formatTimestamp(activity.timestamp),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                        'Description', activity.description, Icons.description),
                    const SizedBox(height: 16),
                    _buildDetailRow('Vehicle Information', activity.vehicleInfo,
                        Icons.directions_car),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                        'Border Location',
                        _selectedBorder?.name ?? 'Border Checkpoint',
                        Icons.location_on),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                        'Timestamp',
                        _formatDetailedTimestamp(activity.timestamp),
                        Icons.access_time),
                    const SizedBox(height: 16),
                    _buildDetailRow('Activity Type',
                        _getActivityTypeDescription(activity.type), Icons.info),

                    // Additional mock details for demonstration
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Additional Information',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          if (activity.type == 'purchase') ...[
                            _buildDetailRow(
                                'Pass Type',
                                'Tourist Pass - 30 Days',
                                Icons.confirmation_number,
                                isCompact: true),
                            _buildDetailRow(
                                'Amount Paid',
                                '${_getCurrencySymbol(_authorityCurrency)}150.00',
                                Icons.payment,
                                isCompact: true),
                            _buildDetailRow('Payment Method', 'Credit Card',
                                Icons.credit_card,
                                isCompact: true),
                          ] else if (activity.type == 'checkin') ...[
                            _buildDetailRow(
                                'Entry Point', 'Main Gate A', Icons.input,
                                isCompact: true),
                            _buildDetailRow('Official', 'Border Official #1234',
                                Icons.person,
                                isCompact: true),
                            _buildDetailRow(
                                'Pass Status', 'Valid', Icons.check_circle,
                                isCompact: true),
                          ] else if (activity.type == 'checkout') ...[
                            _buildDetailRow(
                                'Exit Point', 'Main Gate B', Icons.output,
                                isCompact: true),
                            _buildDetailRow('Duration in Country', '15 days',
                                Icons.schedule,
                                isCompact: true),
                            _buildDetailRow(
                                'Pass Status', 'Completed', Icons.done_all,
                                isCompact: true),
                          ] else ...[
                            _buildDetailRow(
                                'Status', 'Requires Attention', Icons.warning,
                                isCompact: true),
                            _buildDetailRow('Next Action',
                                'Contact vehicle owner', Icons.contact_phone,
                                isCompact: true),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon,
      {bool isCompact = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon,
              size: isCompact ? 14 : 16, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isCompact ? 12 : 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: isCompact ? 13 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAllRecentActivity() {
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
                  color: Colors.purple.shade700,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All Recent Activity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
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
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _dashboardData!.recentActivity.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final activity = _dashboardData!.recentActivity[index];
                    return ListTile(
                      onTap: () {
                        Navigator.of(context).pop();
                        _showActivityDetails(activity);
                      },
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getActivityColor(activity.type)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getActivityIcon(activity.type),
                          color: _getActivityColor(activity.type),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        activity.description,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(activity.vehicleInfo),
                          Text(
                            _formatTimestamp(activity.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade400,
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

  void _showOfficialAudit(officials.OfficialPerformance official) {
    OfficialAuditDialog.show(
      context,
      official,
      borderName: _selectedBorder?.name,
      timeframe: _selectedTimeframe,
    );
  }

  String _getActivityTypeLabel(String type) {
    switch (type) {
      case 'purchase':
        return 'Pass Purchase';
      case 'checkin':
        return 'Check-in';
      case 'checkout':
        return 'Check-out';
      case 'expired':
        return 'Pass Expired';
      default:
        return 'Activity';
    }
  }

  String _getActivityTypeDescription(String type) {
    switch (type) {
      case 'purchase':
        return 'A new border pass was purchased and payment was successfully processed';
      case 'checkin':
        return 'Vehicle entered the country using their valid border pass';
      case 'checkout':
        return 'Vehicle exited the country, completing their border pass usage';
      case 'expired':
        return 'Border pass has reached its expiration date and is no longer valid';
      default:
        return 'Border activity event';
    }
  }

  String _formatDetailedTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    final dateStr = '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    if (difference.inDays > 0) {
      return '$dateStr at $timeStr (${difference.inDays}d ago)';
    } else if (difference.inHours > 0) {
      return '$dateStr at $timeStr (${difference.inHours}h ago)';
    } else if (difference.inMinutes > 0) {
      return '$dateStr at $timeStr (${difference.inMinutes}m ago)';
    } else {
      return '$dateStr at $timeStr (Just now)';
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

  void _showMetricDescription(String title, String description, Color color) {
    String detailedDescription =
        _getDetailedMetricDescription(title, description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.info, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How this metric is calculated:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              detailedDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getTimeframeContext(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Got it', style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  String _getDetailedMetricDescription(String title, String description) {
    switch (title) {
      case 'Total Passes':
        return 'Number of border passes purchased for this border during the selected time period. Each pass represents one traveler\'s authorization. This counts pass purchases, not individual scanning events.';

      case 'Total Scans':
        return 'Number of scan/verification events performed by border officials during the selected time period. One pass can generate multiple scans (check-in, check-out, verifications). This counts actual scanning activity.';

      case 'Active Passes':
        return 'Shows passes that are currently valid and can be used for border crossing. A pass is considered active if: (1) It has been activated, (2) Current date is between activation and expiration dates, (3) It hasn\'t been cancelled or revoked.';

      case 'Vehicles in Country':
        return 'Tracks vehicles that have crossed into the country and haven\'t yet exited. This is calculated by counting check-in movements minus check-out movements for the selected period. Vehicles with expired passes but no check-out are included.';

      case 'Total Revenue':
        return 'Sum of all payments received for border passes during the selected period. Calculated from successful payment transactions in ${_getCurrencySymbol(_authorityCurrency)}. Includes all pass types and excludes refunded amounts.';

      default:
        if (title.contains('Scans')) {
          return 'Total number of pass verification scans performed by border officials during the selected time period. Includes successful scans, failed attempts, and manual verifications. Calculated from pass_movements table with scan-related movement types.';
        } else if (title.contains('Avg Scans/Hour')) {
          return 'Average scanning rate calculated by dividing total scans by working hours. Assumes 8-hour working days to provide realistic productivity metrics. Formula: Total Scans ÷ (Days × 8 hours).';
        } else if (title.contains('Peak Hour')) {
          return 'Hour of the day (0-23) with the highest scanning activity. Determined by analyzing scan timestamps and grouping by hour. Helps identify busiest periods for resource planning.';
        } else if (title.contains('Active Officials')) {
          return 'Shows currently active officials versus total officials assigned to this border. Active officials are those who have performed scans within the last 24 hours.';
        }
        return description;
    }
  }

  String _getTimeframeContext() {
    switch (_selectedTimeframe) {
      case '1d':
        return 'Data shown for the last 24 hours';
      case '7d':
        return 'Data shown for the last 7 days';
      case '30d':
        return 'Data shown for the last 30 days';
      case '90d':
        return 'Data shown for the last 90 days';
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          final days = _customEndDate!.difference(_customStartDate!).inDays + 1;
          return 'Data shown for custom period: ${_formatDate(_customStartDate!)} to ${_formatDate(_customEndDate!)} ($days days)';
        }
        return 'Data shown for custom date range';
      default:
        return 'Data shown for selected time period';
    }
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
          // Show border selector and timeframe selector for consistency
          _buildBorderSelector(),
          const SizedBox(height: 16),
          _buildTimeframeSelector(),
          const SizedBox(height: 24),
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

    // Use totalScansCustom consistently since it represents the filtered dataset
    // that matches what individual officials are calculated from
    final scanCount = overview.totalScansCustom;
    String scanLabel;
    String scanDescription;

    switch (_selectedTimeframe) {
      case '1d':
        scanLabel = 'Scans (24h)';
        scanDescription = 'Total scans in last 24 hours';
        break;
      case '7d':
        scanLabel = 'Scans (7 days)';
        scanDescription = 'Total scans in last 7 days';
        break;
      case '30d':
        scanLabel = 'Scans (30 days)';
        scanDescription = 'Total scans in last 30 days';
        break;
      case '90d':
        scanLabel = 'Scans (90 days)';
        scanDescription = 'Total scans in last 90 days';
        break;
      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          final days = _customEndDate!.difference(_customStartDate!).inDays + 1;
          scanLabel = 'Scans ($days days)';
          scanDescription = 'Total scans in selected period';
        } else {
          scanLabel = 'Scans (Custom)';
          scanDescription = 'Total scans in custom period';
        }
        break;
      default:
        scanLabel = 'Scans';
        scanDescription = 'Total scans in selected period';
    }

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
        const SizedBox(height: 8),
        Text(
          'Performance metrics for the selected time period',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.indigo.shade600,
              ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildMetricCard(
              scanLabel,
              scanCount.toString(),
              Icons.qr_code_scanner,
              Colors.green.shade600,
              scanDescription,
            ),
            _buildMetricCard(
              'Avg Scans/Hour',
              overview.averageScansPerHour.toStringAsFixed(1),
              Icons.speed,
              Colors.blue.shade600,
              'Average scans per hour (considering schedules)',
            ),
            _buildMetricCard(
              'Peak Hour',
              '${overview.peakHour}:00',
              Icons.trending_up,
              Colors.orange.shade600,
              'Most active hour of the day',
            ),
            _buildMetricCard(
              'Active Officials',
              '${overview.activeOfficials}/${overview.totalOfficials}',
              Icons.people,
              Colors.indigo.shade600,
              'Currently active vs total officials',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOfficialsPerformance() {
    final overview = _officialsData!.overview;
    final avgScansPerHour = overview.averageScansPerHour;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.leaderboard, color: Colors.indigo.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Border Officials Performance',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.indigo.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Individual performance compared to border averages',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.indigo.shade600,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          child: _officialsData!.officials.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Officials Data Available',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No scan records with official references found for this border and time period.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade500,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _officialsData!.officials.take(10).length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final official = _officialsData!.officials[index];
                    final isAboveAverage =
                        official.averageScansPerHour > avgScansPerHour;
                    final performanceRatio = avgScansPerHour > 0
                        ? (official.averageScansPerHour / avgScansPerHour)
                        : 1.0;

                    return ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: official.isCurrentlyActive
                            ? (isAboveAverage
                                ? Colors.green.shade100
                                : Colors.orange.shade100)
                            : Colors.grey.shade200,
                        backgroundImage: official.profilePictureUrl != null
                            ? NetworkImage(official.profilePictureUrl!)
                            : null,
                        child: official.profilePictureUrl == null
                            ? Icon(
                                Icons.person,
                                color: official.isCurrentlyActive
                                    ? (isAboveAverage
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700)
                                    : Colors.grey.shade600,
                              )
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              official.officialName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
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
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAboveAverage
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAboveAverage
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: 14,
                                  color: isAboveAverage
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${(performanceRatio * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isAboveAverage
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _showOfficialAudit(official),
                            icon: Icon(
                              Icons.assignment,
                              size: 20,
                              color: Colors.indigo.shade600,
                            ),
                            tooltip: 'View Audit Trail',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${official.totalScans} scans • ${official.averageScansPerHour.toStringAsFixed(1)}/hr vs ${avgScansPerHour.toStringAsFixed(1)} avg',
                            style: TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (official.position != null) ...[
                                Icon(Icons.work,
                                    size: 14, color: Colors.blue.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  official.position!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade600),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (official.lastScanTime != null) ...[
                                Icon(Icons.access_time,
                                    size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTimestamp(official.lastScanTime!),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Performance Analytics',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildOfficialStatCard(
                                      'Total Scans',
                                      official.totalScans.toString(),
                                      Icons.qr_code_scanner,
                                      Colors.blue.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildOfficialStatCard(
                                      'Scans/Hour',
                                      official.averageScansPerHour
                                          .toStringAsFixed(1),
                                      Icons.speed,
                                      isAboveAverage
                                          ? Colors.green.shade600
                                          : Colors.orange.shade600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildOfficialStatCard(
                                      'Avg Process Time',
                                      '${official.averageProcessingTimeMinutes.toStringAsFixed(1)}m',
                                      Icons.timer,
                                      Colors.purple.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Scan Activity Trend (Last 7 Days)',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 120,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: _buildOfficialBarChart(
                                  official.scanTrend,
                                  Colors.blue.shade600,
                                  'Scans',
                                ),
                              ),
                              if (official.lastBorderLocation != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          size: 16,
                                          color: Colors.grey.shade600),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Last Location: ${official.lastBorderLocation}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOfficialStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialBarChart(
      List<officials.ChartData> data, Color color, String label) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No $label data',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      );
    }

    final maxValue = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) {
      return Center(
        child: Text(
          'No $label activity',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          flex: 4, // Give more space to the chart area
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: data.map((chartData) {
              final height = (chartData.value / maxValue * 60)
                  .clamp(2.0, 60.0); // Reduced max height
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min, // Prevent overflow
                    children: [
                      if (chartData.value > 0)
                        Flexible(
                          // Make text flexible to prevent overflow
                          child: Text(
                            label == 'Revenue'
                                ? '${chartData.value.toInt()}'
                                : chartData.value.toInt().toString(),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 7, // Slightly smaller font
                                      fontWeight: FontWeight.w500,
                                    ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (chartData.value > 0)
                        const SizedBox(height: 1), // Reduced spacing
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
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
        const SizedBox(height: 2), // Reduced spacing
        Flexible(
          // Make labels flexible
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: data.map((chartData) {
              return Expanded(
                child: Text(
                  chartData.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 7, // Slightly smaller font
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
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

  Widget _buildOfficialsHeatMap() {
    if (_officialsData == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No officials data available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return EnhancedBorderOfficialsHeatMap(
      scanLocations: _officialsData!.scanLocations,
      selectedBorder: _selectedBorder,
      timeframe: _selectedTimeframe,
      customStartDate: _customStartDate,
      customEndDate: _customEndDate,
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
          childAspectRatio: 1.1,
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
      // Reload all data to keep Analytics and Officials tabs in sync
      _loadDashboardData();
      _loadOfficialsData();
      // Also reload forecast data if on that tab
      if (_tabController.index == 2) {
        _loadForecastData();
      }
    }
  }

  /// Custom bar chart widget that doesn't depend on fl_chart
  Widget _buildCustomBarChart(
      List<dashboard.ChartData> data, Color color, String label) {
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

  Widget _buildMovementContent() {
    if (_selectedBorder == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Border Selected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Please select a border to view vehicle movements.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return BorderMovementScreen(
      authorityId: widget.authorityId,
      authorityName: widget.authorityName,
    );
  }
}
