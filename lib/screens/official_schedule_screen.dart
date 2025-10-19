import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/date_utils.dart' as date_utils;

class OfficialScheduleScreen extends StatefulWidget {
  const OfficialScheduleScreen({super.key});

  @override
  State<OfficialScheduleScreen> createState() => _OfficialScheduleScreenState();
}

class _OfficialScheduleScreenState extends State<OfficialScheduleScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  String? _currentUserId;
  String? _officialName;
  List<Map<String, dynamic>> _currentAssignments = [];
  List<Map<String, dynamic>> _historicalAssignments = [];
  Map<String, dynamic>? _performanceMetrics;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOfficialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOfficialData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      _currentUserId = user.id;

      // Get official's profile information
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', _currentUserId!)
          .maybeSingle();

      _officialName = profileResponse?['full_name'] ?? 'Unknown Official';

      // Load current and historical assignments
      await Future.wait([
        _loadCurrentAssignments(),
        _loadHistoricalAssignments(),
        _loadPerformanceMetrics(),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentAssignments() async {
    try {
      final response = await Supabase.instance.client
          .from('official_schedule_assignments')
          .select('''
            *,
            schedule_time_slots!inner(
              *,
              border_schedule_templates!inner(
                *,
                borders!inner(name)
              )
            )
          ''')
          .eq('profile_id', _currentUserId!)
          .isFilter('effective_to', null)
          .order('created_at', ascending: false);

      _currentAssignments = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error loading current assignments: $e');
      _currentAssignments = [];
    }
  }

  Future<void> _loadHistoricalAssignments() async {
    try {
      final response = await Supabase.instance.client
          .from('official_schedule_assignments')
          .select('''
            *,
            schedule_time_slots!inner(
              *,
              border_schedule_templates!inner(
                *,
                borders!inner(name)
              )
            )
          ''')
          .eq('profile_id', _currentUserId!)
          .not('effective_to', 'is', null)
          .order('effective_to', ascending: false)
          .limit(20);

      _historicalAssignments = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error loading historical assignments: $e');
      _historicalAssignments = [];
    }
  }

  Future<void> _loadPerformanceMetrics() async {
    try {
      // Get performance data for the current month
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final response = await Supabase.instance.client
          .from('pass_movements')
          .select('id, created_at, processed_at')
          .eq('profile_id', _currentUserId!)
          .gte('created_at', monthStart.toIso8601String())
          .lte('created_at', now.toIso8601String());

      final movements = List<Map<String, dynamic>>.from(response);

      // Calculate basic metrics
      final totalScans = movements.length;
      final totalHours = _calculateScheduledHours();
      final efficiency = totalHours > 0 ? totalScans / totalHours : 0.0;

      // Calculate average processing time
      double avgProcessingTime = 0.0;
      if (movements.isNotEmpty) {
        final processingTimes = movements
            .where((m) => m['processed_at'] != null)
            .map((m) {
              final created = DateTime.parse(m['created_at']);
              final processed = DateTime.parse(m['processed_at']);
              return processed.difference(created).inSeconds;
            })
            .where((time) => time > 0 && time < 600) // Filter outliers
            .toList();

        if (processingTimes.isNotEmpty) {
          avgProcessingTime =
              processingTimes.reduce((a, b) => a + b) / processingTimes.length;
        }
      }

      _performanceMetrics = {
        'total_scans': totalScans,
        'scheduled_hours': totalHours,
        'efficiency': efficiency,
        'avg_processing_time': avgProcessingTime,
        'period': 'This Month',
      };
    } catch (e) {
      debugPrint('❌ Error loading performance metrics: $e');
      _performanceMetrics = {
        'total_scans': 0,
        'scheduled_hours': 0.0,
        'efficiency': 0.0,
        'avg_processing_time': 0.0,
        'period': 'This Month',
      };
    }
  }

  double _calculateScheduledHours() {
    double totalHours = 0.0;
    for (final assignment in _currentAssignments) {
      final timeSlot = assignment['schedule_time_slots'];
      if (timeSlot != null) {
        final startTime = timeSlot['start_time'] as String;
        final endTime = timeSlot['end_time'] as String;
        totalHours += _calculateSlotHours(startTime, endTime);
      }
    }
    return totalHours *
        4; // Approximate weekly hours (assuming 4 weeks in month)
  }

  double _calculateSlotHours(String startTime, String endTime) {
    try {
      final start = _parseTime(startTime);
      final end = _parseTime(endTime);
      return end.difference(start).inMinutes / 60.0;
    } catch (e) {
      return 8.0; // Default 8 hours if parsing fails
    }
  }

  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.schedule), text: 'Current Schedule'),
            Tab(icon: Icon(Icons.history), text: 'Schedule History'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOfficialData,
            tooltip: 'Refresh',
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
                    _buildCurrentScheduleTab(),
                    _buildHistoryTab(),
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
            'Failed to load schedule data',
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
            onPressed: _loadOfficialData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOfficialHeader(),
          const SizedBox(height: 16),
          if (_performanceMetrics != null) ...[
            _buildPerformanceMetrics(),
            const SizedBox(height: 16),
          ],
          _buildCurrentAssignmentsSection(),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHistoryHeader(),
          const SizedBox(height: 16),
          _buildHistoricalAssignmentsSection(),
        ],
      ),
    );
  }

  Widget _buildOfficialHeader() {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.red.shade50, Colors.red.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.red.shade600,
                radius: 30,
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _officialName ?? 'Border Official',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Border Official',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.red.shade600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildPerformanceMetrics() {
    final metrics = _performanceMetrics!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.red.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Performance Metrics - ${metrics['period']}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.red.shade800,
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
                  'Total Scans',
                  metrics['total_scans'].toString(),
                  Icons.qr_code_scanner,
                  Colors.blue.shade600,
                ),
                _buildMetricCard(
                  'Efficiency',
                  '${metrics['efficiency'].toStringAsFixed(1)} scans/hr',
                  Icons.speed,
                  Colors.green.shade600,
                ),
                _buildMetricCard(
                  'Scheduled Hours',
                  '${metrics['scheduled_hours'].toStringAsFixed(0)}h',
                  Icons.schedule,
                  Colors.orange.shade600,
                ),
                _buildMetricCard(
                  'Avg Processing',
                  '${metrics['avg_processing_time'].toStringAsFixed(1)}s',
                  Icons.timer,
                  Colors.purple.shade600,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentAssignmentsSection() {
    if (_currentAssignments.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.schedule_outlined,
                  size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No Current Schedule',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'You are not currently assigned to any time slots.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Group assignments by day of week and border
    final groupedAssignments =
        _groupAssignmentsByDayAndBorder(_currentAssignments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Schedule Assignments',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...groupedAssignments.entries.map(
            (dayEntry) => _buildDayScheduleCard(dayEntry.key, dayEntry.value)),
      ],
    );
  }

  Widget _buildHistoryHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.history, color: Colors.red.shade700, size: 24),
            const SizedBox(width: 8),
            Text(
              'Schedule History',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            Text(
              '${_historicalAssignments.length} past assignments',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalAssignmentsSection() {
    if (_historicalAssignments.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.history_outlined,
                  size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No Schedule History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'No previous schedule assignments found.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Group historical assignments by effective period and then by day
    final groupedByPeriod =
        _groupHistoricalAssignmentsByPeriod(_historicalAssignments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Previous Assignments',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...groupedByPeriod.entries.map((periodEntry) =>
            _buildHistoricalPeriodCard(periodEntry.key, periodEntry.value)),
      ],
    );
  }

  String _getDayName(int dayOfWeek) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[dayOfWeek - 1];
  }

  Map<int, Map<String, List<Map<String, dynamic>>>>
      _groupAssignmentsByDayAndBorder(List<Map<String, dynamic>> assignments) {
    final grouped = <int, Map<String, List<Map<String, dynamic>>>>{};

    for (final assignment in assignments) {
      final timeSlot = assignment['schedule_time_slots'];
      final template = timeSlot['border_schedule_templates'];
      final border = template['borders'];

      final dayOfWeek = timeSlot['day_of_week'] as int;
      final borderName = border['name'] as String;

      grouped.putIfAbsent(dayOfWeek, () => {});
      grouped[dayOfWeek]!.putIfAbsent(borderName, () => []);
      grouped[dayOfWeek]![borderName]!.add(assignment);
    }

    // Sort assignments within each border by priority: primary, temporary, backup
    for (final dayEntry in grouped.values) {
      for (final borderAssignments in dayEntry.values) {
        borderAssignments.sort((a, b) {
          final priorityOrder = {'primary': 0, 'temporary': 1, 'backup': 2};
          final aPriority = priorityOrder[a['assignment_type']] ?? 3;
          final bPriority = priorityOrder[b['assignment_type']] ?? 3;

          if (aPriority != bPriority) {
            return aPriority.compareTo(bPriority);
          }

          // If same priority, sort by time
          final aTimeSlot = a['schedule_time_slots'];
          final bTimeSlot = b['schedule_time_slots'];
          return aTimeSlot['start_time'].compareTo(bTimeSlot['start_time']);
        });
      }
    }

    return grouped;
  }

  Widget _buildDayScheduleCard(int dayOfWeek,
      Map<String, List<Map<String, dynamic>>> borderAssignments) {
    final dayName = _getDayName(dayOfWeek);
    final totalAssignments =
        borderAssignments.values.fold(0, (sum, list) => sum + list.length);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  dayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalAssignments assignment${totalAssignments != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: borderAssignments.entries
                  .map((borderEntry) => _buildBorderAssignmentsSection(
                      borderEntry.key, borderEntry.value))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorderAssignmentsSection(
      String borderName, List<Map<String, dynamic>> assignments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (assignments.length > 1 ||
            borderName !=
                assignments.first['schedule_time_slots']
                    ['border_schedule_templates']['borders']['name']) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  borderName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
        ...assignments.map((assignment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCompactAssignmentCard(assignment),
            )),
        if (assignments != assignments) const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCompactAssignmentCard(Map<String, dynamic> assignment) {
    final timeSlot = assignment['schedule_time_slots'];
    final template = timeSlot['border_schedule_templates'];

    final assignmentType = assignment['assignment_type'] as String;
    final effectiveFrom = DateTime.parse(assignment['effective_from']);

    Color typeColor;
    IconData typeIcon;

    switch (assignmentType) {
      case 'primary':
        typeColor = Colors.green.shade600;
        typeIcon = Icons.star;
        break;
      case 'backup':
        typeColor = Colors.orange.shade600;
        typeIcon = Icons.backup;
        break;
      case 'temporary':
        typeColor = Colors.blue.shade600;
        typeIcon = Icons.schedule;
        break;
      default:
        typeColor = Colors.grey.shade600;
        typeIcon = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: typeColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(typeIcon, color: typeColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${timeSlot['start_time']} - ${timeSlot['end_time']}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        assignmentType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  template['template_name'] ?? 'Unknown Template',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
          ),
          Text(
            'Since ${date_utils.DateUtils.formatFriendlyDateOnly(effectiveFrom)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupHistoricalAssignmentsByPeriod(
      List<Map<String, dynamic>> assignments) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final assignment in assignments) {
      final effectiveFrom = DateTime.parse(assignment['effective_from']);
      final effectiveTo = assignment['effective_to'] != null
          ? DateTime.parse(assignment['effective_to'])
          : DateTime.now();

      final periodKey =
          '${date_utils.DateUtils.formatFriendlyDateOnly(effectiveFrom)} - ${date_utils.DateUtils.formatFriendlyDateOnly(effectiveTo)}';

      grouped.putIfAbsent(periodKey, () => []);
      grouped[periodKey]!.add(assignment);
    }

    // Sort assignments within each period by priority and time
    for (final periodAssignments in grouped.values) {
      periodAssignments.sort((a, b) {
        final priorityOrder = {'primary': 0, 'temporary': 1, 'backup': 2};
        final aPriority = priorityOrder[a['assignment_type']] ?? 3;
        final bPriority = priorityOrder[b['assignment_type']] ?? 3;

        if (aPriority != bPriority) {
          return aPriority.compareTo(bPriority);
        }

        // If same priority, sort by day then time
        final aTimeSlot = a['schedule_time_slots'];
        final bTimeSlot = b['schedule_time_slots'];
        final dayComparison =
            aTimeSlot['day_of_week'].compareTo(bTimeSlot['day_of_week']);
        if (dayComparison != 0) return dayComparison;

        return aTimeSlot['start_time'].compareTo(bTimeSlot['start_time']);
      });
    }

    return grouped;
  }

  Widget _buildHistoricalPeriodCard(
      String period, List<Map<String, dynamic>> assignments) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.grey.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    period,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${assignments.length} assignment${assignments.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: assignments
                  .map((assignment) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildHistoricalAssignmentCard(assignment),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalAssignmentCard(Map<String, dynamic> assignment) {
    final timeSlot = assignment['schedule_time_slots'];
    final template = timeSlot['border_schedule_templates'];
    final border = template['borders'];

    final assignmentType = assignment['assignment_type'] as String;

    Color typeColor;
    IconData typeIcon;

    switch (assignmentType) {
      case 'primary':
        typeColor = Colors.green.shade600;
        typeIcon = Icons.star;
        break;
      case 'backup':
        typeColor = Colors.orange.shade600;
        typeIcon = Icons.backup;
        break;
      case 'temporary':
        typeColor = Colors.blue.shade600;
        typeIcon = Icons.schedule;
        break;
      default:
        typeColor = Colors.grey.shade600;
        typeIcon = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(typeIcon, color: typeColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      border['name'] ?? 'Unknown Border',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        assignmentType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_getDayName(timeSlot['day_of_week'])} ${timeSlot['start_time']} - ${timeSlot['end_time']}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                Text(
                  template['template_name'] ?? 'Unknown Template',
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
}
