import 'package:flutter/material.dart';
import '../services/border_officials_service_simple.dart';
import '../services/border_manager_service.dart';
import '../models/border.dart' as border_model;
import '../utils/date_utils.dart' as date_utils;
import '../widgets/border_officials_heat_map.dart';

class BorderOfficialsScreen extends StatefulWidget {
  final String? authorityId;
  final String? authorityName;

  const BorderOfficialsScreen({
    super.key,
    this.authorityId,
    this.authorityName,
  });

  @override
  State<BorderOfficialsScreen> createState() => _BorderOfficialsScreenState();
}

class _BorderOfficialsScreenState extends State<BorderOfficialsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  List<border_model.Border> _availableBorders = [];
  border_model.Border? _selectedBorder;
  BorderOfficialsData? _officialsData;
  String _selectedTimeframe = 'today';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        await _loadOfficialsData();
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

  Future<void> _loadOfficialsData() async {
    if (_selectedBorder == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final officialsData = await BorderOfficialsService.getBorderOfficialsData(
        _selectedBorder!.id,
        _selectedTimeframe,
        customStartDate: _customStartDate,
        customEndDate: _customEndDate,
      );

      setState(() {
        _officialsData = officialsData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _selectedTimeframe = 'custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      await _loadOfficialsData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.authorityName != null
            ? 'Border Officials - ${widget.authorityName}'
            : 'Border Officials Performance'),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.people), text: 'Officials'),
            Tab(icon: Icon(Icons.map), text: 'Heat Map'),
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
            onPressed: _loadOfficialsData,
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
                    _buildOverviewTab(),
                    _buildOfficialsTab(),
                    _buildHeatMapTab(),
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
            'Failed to load border officials data',
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

  Widget _buildOverviewTab() {
    if (_availableBorders.isEmpty) {
      return _buildNoBordersWidget();
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
          if (_officialsData != null) ...[
            _buildOverviewMetrics(),
            const SizedBox(height: 24),
            _buildHourlyActivityChart(),
          ] else
            const Center(child: Text('Select a border to view officials data')),
        ],
      ),
    );
  }

  Widget _buildOfficialsTab() {
    if (_officialsData == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOfficialsHeader(),
          const SizedBox(height: 16),
          ..._officialsData!.officials
              .map((official) => _buildOfficialCard(official)),
        ],
      ),
    );
  }

  Widget _buildHeatMapTab() {
    if (_officialsData == null) {
      return const Center(child: Text('No location data available'));
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan Location Heat Map',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Red markers indicate potential outliers (scans >5km from border)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red.shade600,
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          child: BorderOfficialsHeatMap(
            scanLocations: _officialsData!.scanLocations,
            selectedBorder: _selectedBorder,
          ),
        ),
      ],
    );
  }

  Widget _buildNoBordersWidget() {
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
                : 'You do not have access to any border data.',
            textAlign: TextAlign.center,
          ),
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
                  _loadOfficialsData();
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
            colors: [Colors.indigo.shade50, Colors.indigo.shade100],
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
                  Icon(Icons.schedule, color: Colors.indigo.shade700, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Analysis Time Period',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.indigo.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTimeframeChip('today', 'Today'),
                  _buildTimeframeChip('yesterday', 'Yesterday'),
                  _buildTimeframeChip('this_week', 'This Week'),
                  _buildTimeframeChip('this_month', 'This Month'),
                  _buildTimeframeChip('custom', 'Custom Range'),
                ],
              ),
              if (_selectedTimeframe == 'custom' &&
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
                        '${date_utils.DateUtils.formatFriendlyDateOnly(_customStartDate!)} - ${date_utils.DateUtils.formatFriendlyDateOnly(_customEndDate!)}',
                        style: TextStyle(
                          color: Colors.indigo.shade800,
                          fontWeight: FontWeight.w600,
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
            _loadOfficialsData();
          }
        }
      },
      selectedColor: Colors.indigo.shade100,
      checkmarkColor: Colors.indigo.shade700,
      backgroundColor: Colors.indigo.shade50,
      labelStyle: TextStyle(
        color: isSelected ? Colors.indigo.shade800 : Colors.indigo.shade600,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildOverviewMetrics() {
    final overview = _officialsData!.overview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.analytics, color: Colors.indigo.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Performance Overview',
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
              'Scans Yesterday',
              overview.totalScansYesterday.toString(),
              Icons.history,
              Colors.blue.shade600,
              'Total passes scanned yesterday',
            ),
            _buildMetricCard(
              'This Week',
              overview.totalScansThisWeek.toString(),
              Icons.date_range,
              Colors.orange.shade600,
              'Total scans this week',
            ),
            _buildMetricCard(
              'This Month',
              overview.totalScansThisMonth.toString(),
              Icons.calendar_month,
              Colors.purple.shade600,
              'Total scans this month',
            ),
            _buildMetricCard(
              'Avg Scans/Hour',
              overview.averageScansPerHour.toStringAsFixed(1),
              Icons.speed,
              Colors.teal.shade600,
              'Average scans per hour',
            ),
            _buildMetricCard(
              'Peak Hour',
              '${overview.peakHour}:00',
              Icons.trending_up,
              Colors.red.shade600,
              'Most active hour of day',
            ),
            _buildMetricCard(
              'Active Officials',
              '${overview.activeOfficials}/${overview.totalOfficials}',
              Icons.people,
              Colors.indigo.shade600,
              'Currently active officials',
            ),
            _buildMetricCard(
              'Avg Processing',
              '${overview.averageProcessingTimeMinutes.toStringAsFixed(1)}min',
              Icons.timer,
              Colors.amber.shade600,
              'Average processing time',
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

  Widget _buildHourlyActivityChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.indigo.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Hourly Activity Pattern',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.indigo.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildHourlyChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyChart() {
    final hourlyData = _officialsData!.hourlyActivity;
    final maxScans =
        hourlyData.map((h) => h.scanCount).reduce((a, b) => a > b ? a : b);

    if (maxScans == 0) {
      return const Center(child: Text('No activity data available'));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: hourlyData.map((hour) {
        final height = (hour.scanCount / maxScans) * 160;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade400,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(2)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${hour.hour}',
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOfficialsHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.people, color: Colors.indigo.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Individual Official Performance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.indigo.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            Text(
              '${_officialsData!.officials.length} Officials',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.indigo.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialCard(OfficialPerformance official) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            official.officialName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: official.isCurrentlyActive
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              official.isCurrentlyActive ? 'Active' : 'Former',
                              style: TextStyle(
                                fontSize: 12,
                                color: official.isCurrentlyActive
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (official.officialEmail != null)
                        Text(
                          official.officialEmail!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${official.totalScans} scans',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade700,
                          ),
                    ),
                    Text(
                      '${official.successRate.toStringAsFixed(1)}% success',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: official.successRate >= 90
                                ? Colors.green.shade600
                                : official.successRate >= 70
                                    ? Colors.orange.shade600
                                    : Colors.red.shade600,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOfficialMetric(
                    'Scans/Hour',
                    official.averageScansPerHour.toStringAsFixed(1),
                    Icons.speed,
                    Colors.blue.shade600,
                  ),
                ),
                Expanded(
                  child: _buildOfficialMetric(
                    'Avg Processing',
                    '${official.averageProcessingTimeMinutes.toStringAsFixed(1)}min',
                    Icons.timer,
                    Colors.orange.shade600,
                  ),
                ),
                Expanded(
                  child: _buildOfficialMetric(
                    'Last Scan',
                    official.lastScanTime != null
                        ? date_utils.DateUtils.getRelativeTime(
                            official.lastScanTime!)
                        : 'Never',
                    Icons.access_time,
                    Colors.purple.shade600,
                  ),
                ),
              ],
            ),
            if (official.lastBorderLocation != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Last location: ${official.lastBorderLocation}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialMetric(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
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
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
