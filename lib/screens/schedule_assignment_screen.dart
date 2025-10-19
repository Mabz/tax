import 'package:flutter/material.dart';
import '../models/border_schedule_template.dart';
import '../models/schedule_time_slot.dart';
import '../services/border_schedule_service.dart';
import '../services/border_manager_service.dart';
import '../widgets/official_assignment_widget.dart';

class ScheduleAssignmentScreen extends StatefulWidget {
  final BorderScheduleTemplate template;
  final String borderName;

  const ScheduleAssignmentScreen({
    super.key,
    required this.template,
    required this.borderName,
  });

  @override
  State<ScheduleAssignmentScreen> createState() =>
      _ScheduleAssignmentScreenState();
}

class _ScheduleAssignmentScreenState extends State<ScheduleAssignmentScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  List<ScheduleTimeSlot> _timeSlots = [];
  final Map<int, List<ScheduleTimeSlot>> _slotsByDay = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTimeSlots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTimeSlots() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final timeSlots =
          await BorderScheduleService.getTimeSlots(widget.template.id);

      // Group slots by day
      final slotsByDay = <int, List<ScheduleTimeSlot>>{};
      for (int day = 1; day <= 7; day++) {
        slotsByDay[day] = timeSlots
            .where((slot) => slot.dayOfWeek == day)
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
      }

      setState(() {
        _timeSlots = timeSlots;
        _slotsByDay.clear();
        _slotsByDay.addAll(slotsByDay);
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
        title: Text('Assign Officials: ${widget.template.templateName}'),
        backgroundColor: Colors.purple.shade700,
        elevation: 0,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.schedule), text: 'Template View'),
            Tab(icon: Icon(Icons.people), text: 'Official View'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTimeSlots,
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
                    _buildTemplateViewTab(),
                    _buildOfficialViewTab(),
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
            onPressed: _loadTimeSlots,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialViewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOfficialViewHeader(),
          const SizedBox(height: 16),
          _buildOfficialsList(),
        ],
      ),
    );
  }

  Widget _buildTemplateViewTab() {
    if (_timeSlots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Time Slots Configured',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure time slots in the schedule template first.',
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
          _buildTemplateOverviewCard(),
          const SizedBox(height: 16),
          _buildAssignmentHeader(),
          const SizedBox(height: 16),
          _buildWeeklyScheduleView(),
        ],
      ),
    );
  }

  Widget _buildTemplateHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.purple.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  widget.template.templateName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.purple.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.template.isActive
                        ? Colors.green.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.template.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.template.isActive
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  widget.borderName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
            if (widget.template.description != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.template.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatChip(
                  'Total Slots',
                  _timeSlots.length.toString(),
                  Icons.schedule,
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  'Total Hours',
                  _calculateTotalHours().toStringAsFixed(1),
                  Icons.access_time,
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  'Coverage',
                  '${(_calculateTotalHours() / 168 * 100).toStringAsFixed(0)}%',
                  Icons.pie_chart,
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
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

  Widget _buildAssignmentHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.purple.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Official Assignments',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.purple.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Assign border officials to specific time slots. Each time slot can have multiple officials with different assignment types.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildAssignmentTypeLegend(
                    'Primary', Colors.green.shade600, Icons.star),
                const SizedBox(width: 16),
                _buildAssignmentTypeLegend(
                    'Backup', Colors.orange.shade600, Icons.backup),
                const SizedBox(width: 16),
                _buildAssignmentTypeLegend(
                    'Temporary', Colors.purple.shade600, Icons.schedule),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentTypeLegend(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  double _calculateTotalHours() {
    return _timeSlots.fold(0.0, (sum, slot) => sum + slot.durationHours);
  }

  Widget _buildTemplateOverviewCard() {
    return Card(
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.purple.shade700, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    widget.template.templateName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.purple.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.template.isActive
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.template.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.template.isActive
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    widget.borderName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
              if (widget.template.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.template.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatChip(
                    'Total Slots',
                    _timeSlots.length.toString(),
                    Icons.schedule,
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    'Total Hours',
                    _calculateTotalHours().toStringAsFixed(1),
                    Icons.access_time,
                    Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    'Coverage',
                    '${(_calculateTotalHours() / 168 * 100).toStringAsFixed(0)}%',
                    Icons.pie_chart,
                    Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyScheduleView() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Schedule - Assignment View',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Assign officials to time slots organized by day of the week',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        const SizedBox(height: 16),
        ...days.asMap().entries.map((entry) {
          final dayIndex = entry.key + 1; // 1-based indexing
          final dayName = entry.value;
          final daySlots = _slotsByDay[dayIndex] ?? [];

          return _buildDaySection(dayIndex, dayName, daySlots);
        }),
      ],
    );
  }

  Widget _buildDaySection(
      int dayOfWeek, String dayName, List<ScheduleTimeSlot> slots) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getDayIcon(dayOfWeek),
                    color: Colors.purple.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  dayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.purple.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${slots.length} time slot${slots.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (slots.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.schedule_outlined,
                      size: 32, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No time slots configured for $dayName',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add time slots in the template configuration',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Time slots summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Time Slots: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            children: slots
                                .map((slot) => Text(
                                      '${slot.startTime}-${slot.endTime}',
                                      style: TextStyle(
                                        color: Colors.purple.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Assignment widgets for each time slot
                  ...slots.map((timeSlot) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: OfficialAssignmentWidget(
                          timeSlot: timeSlot,
                          borderName: widget.borderName,
                          onAssignmentChanged: _loadTimeSlots,
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _getDayIcon(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return Icons.work; // Monday
      case 2:
        return Icons.work; // Tuesday
      case 3:
        return Icons.work; // Wednesday
      case 4:
        return Icons.work; // Thursday
      case 5:
        return Icons.work; // Friday
      case 6:
        return Icons.weekend; // Saturday
      case 7:
        return Icons.weekend; // Sunday
      default:
        return Icons.calendar_today;
    }
  }

  Widget _buildOfficialViewHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.purple.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Officials Schedule View',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.purple.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'View each official\'s assigned time slots and schedule',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialsList() {
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _getOfficialsWithAssignments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading officials: ${snapshot.error}'),
          );
        }

        final officialsData = snapshot.data ?? {};

        if (officialsData.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No Officials Assigned',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Assign officials to time slots in the Template View tab.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: officialsData.entries.map((entry) {
            final officialName = entry.key;
            final assignments = entry.value;
            return _buildOfficialCard(officialName, assignments);
          }).toList(),
        );
      },
    );
  }

  Widget _buildOfficialCard(
      String officialName, List<Map<String, dynamic>> assignments) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  child: Icon(
                    Icons.person,
                    color: Colors.purple.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        officialName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        '${assignments.length} time slot${assignments.length != 1 ? 's' : ''} assigned',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_calculateOfficialHours(assignments).toStringAsFixed(1)}h/week',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: assignments
                  .map((assignment) => _buildAssignmentChip(assignment))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentChip(Map<String, dynamic> assignment) {
    final timeSlot = assignment['timeSlot'] as ScheduleTimeSlot;
    final assignmentType = assignment['assignmentType'] as String;

    Color chipColor;
    IconData chipIcon;

    switch (assignmentType) {
      case 'primary':
        chipColor = Colors.green.shade600;
        chipIcon = Icons.star;
        break;
      case 'backup':
        chipColor = Colors.orange.shade600;
        chipIcon = Icons.backup;
        break;
      case 'temporary':
        chipColor = Colors.purple.shade600;
        chipIcon = Icons.schedule;
        break;
      default:
        chipColor = Colors.grey.shade600;
        chipIcon = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chipIcon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            '${timeSlot.shortDayName} ${timeSlot.startTime}-${timeSlot.endTime}',
            style: TextStyle(
              fontSize: 12,
              color: chipColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>>
      _getOfficialsWithAssignments() async {
    final Map<String, List<Map<String, dynamic>>> officialsData = {};

    // Get all assignments for all time slots
    for (final timeSlot in _timeSlots) {
      final assignments =
          await BorderScheduleService.getAssignmentsForTimeSlot(timeSlot.id);

      for (final assignment in assignments) {
        if (assignment.isCurrentlyActive) {
          // Get official name (you might want to cache this)
          final officialName = await _getOfficialName(assignment.profileId);

          if (!officialsData.containsKey(officialName)) {
            officialsData[officialName] = [];
          }

          officialsData[officialName]!.add({
            'timeSlot': timeSlot,
            'assignment': assignment,
            'assignmentType': assignment.assignmentType,
          });
        }
      }
    }

    // Sort assignments by day and time for each official
    for (final assignments in officialsData.values) {
      assignments.sort((a, b) {
        final slotA = a['timeSlot'] as ScheduleTimeSlot;
        final slotB = b['timeSlot'] as ScheduleTimeSlot;

        if (slotA.dayOfWeek != slotB.dayOfWeek) {
          return slotA.dayOfWeek.compareTo(slotB.dayOfWeek);
        }
        return slotA.startTime.compareTo(slotB.startTime);
      });
    }

    return officialsData;
  }

  Future<String> _getOfficialName(String profileId) async {
    try {
      final response = await BorderManagerService.supabase
          .from('profiles')
          .select('full_name')
          .eq('id', profileId)
          .maybeSingle();

      return response?['full_name'] ?? 'Unknown Official';
    } catch (e) {
      return 'Unknown Official';
    }
  }

  double _calculateOfficialHours(List<Map<String, dynamic>> assignments) {
    return assignments.fold(0.0, (sum, assignment) {
      final timeSlot = assignment['timeSlot'] as ScheduleTimeSlot;
      return sum + timeSlot.durationHours;
    });
  }
}
