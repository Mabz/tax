import 'package:flutter/material.dart';
import '../models/border_schedule_template.dart';
import '../models/schedule_time_slot.dart';
import '../services/border_schedule_service.dart';
import '../screens/schedule_assignment_screen.dart';

class ScheduleTemplateBuilderWidget extends StatefulWidget {
  final BorderScheduleTemplate template;
  final String borderName;

  const ScheduleTemplateBuilderWidget({
    super.key,
    required this.template,
    required this.borderName,
  });

  @override
  State<ScheduleTemplateBuilderWidget> createState() =>
      _ScheduleTemplateBuilderWidgetState();
}

class _ScheduleTemplateBuilderWidgetState
    extends State<ScheduleTemplateBuilderWidget> {
  bool _isLoading = true;
  String? _error;
  List<ScheduleTimeSlot> _timeSlots = [];
  final Map<int, List<ScheduleTimeSlot>> _slotsByDay = {};

  @override
  void initState() {
    super.initState();
    _loadTimeSlots();
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

  Future<void> _addTimeSlot(int dayOfWeek) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _TimeSlotDialog(dayOfWeek: dayOfWeek),
    );

    if (result != null) {
      try {
        await BorderScheduleService.createTimeSlot(
          templateId: widget.template.id,
          dayOfWeek: dayOfWeek,
          startTime: result['startTime'] as String,
          endTime: result['endTime'] as String,
          minOfficials: result['minOfficials'] as int,
          maxOfficials: result['maxOfficials'] as int,
        );

        await _loadTimeSlots();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Time slot added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding time slot: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editTimeSlot(ScheduleTimeSlot slot) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _TimeSlotDialog(
        dayOfWeek: slot.dayOfWeek,
        existingSlot: slot,
      ),
    );

    if (result != null) {
      try {
        await BorderScheduleService.updateTimeSlot(
          slot.id,
          startTime: result['startTime'] as String,
          endTime: result['endTime'] as String,
          minOfficials: result['minOfficials'] as int,
          maxOfficials: result['maxOfficials'] as int,
        );

        await _loadTimeSlots();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Time slot updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating time slot: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteTimeSlot(ScheduleTimeSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Time Slot'),
        content: Text(
          'Are you sure you want to delete the ${slot.startTime}-${slot.endTime} slot on ${slot.dayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await BorderScheduleService.deleteTimeSlot(slot.id);
        await _loadTimeSlots();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Time slot deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting time slot: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configure: ${widget.template.templateName}'),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: _navigateToAssignments,
            tooltip: 'Assign Officials',
          ),
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
              : _buildScheduleBuilder(),
      floatingActionButton: _timeSlots.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _navigateToAssignments,
              backgroundColor: Colors.indigo.shade700,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.people),
              label: const Text('Assign Officials'),
            )
          : null,
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

  Widget _buildScheduleBuilder() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTemplateHeader(),
          const SizedBox(height: 24),
          _buildWeeklyScheduleGrid(),
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
                Icon(Icons.schedule, color: Colors.indigo.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  widget.template.templateName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.indigo.shade800,
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

  Widget _buildWeeklyScheduleGrid() {
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
          'Weekly Schedule Configuration',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        ...days.asMap().entries.map((entry) {
          final dayIndex = entry.key + 1; // 1-based indexing
          final dayName = entry.value;
          final daySlots = _slotsByDay[dayIndex] ?? [];

          return _buildDayCard(dayIndex, dayName, daySlots);
        }),
      ],
    );
  }

  Widget _buildDayCard(
      int dayOfWeek, String dayName, List<ScheduleTimeSlot> slots) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  dayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  '${slots.length} slots',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _addTimeSlot(dayOfWeek),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add Time Slot',
                  color: Colors.indigo.shade700,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (slots.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.grey.shade300, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    Icon(Icons.schedule_outlined,
                        size: 32, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No time slots configured',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () => _addTimeSlot(dayOfWeek),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Slot'),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    slots.map((slot) => _buildTimeSlotChip(slot)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotChip(ScheduleTimeSlot slot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.indigo.shade700),
          const SizedBox(width: 6),
          Text(
            '${slot.startTime} - ${slot.endTime}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.indigo.shade800,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${slot.minOfficials}-${slot.maxOfficials}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.indigo.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _editTimeSlot(slot);
                  break;
                case 'delete':
                  _deleteTimeSlot(slot);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            child:
                Icon(Icons.more_vert, size: 16, color: Colors.indigo.shade600),
          ),
        ],
      ),
    );
  }

  double _calculateTotalHours() {
    return _timeSlots.fold(0.0, (sum, slot) => sum + slot.durationHours);
  }

  void _navigateToAssignments() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScheduleAssignmentScreen(
          template: widget.template,
          borderName: widget.borderName,
        ),
      ),
    );
  }
}

class _TimeSlotDialog extends StatefulWidget {
  final int dayOfWeek;
  final ScheduleTimeSlot? existingSlot;

  const _TimeSlotDialog({
    required this.dayOfWeek,
    this.existingSlot,
  });

  @override
  State<_TimeSlotDialog> createState() => _TimeSlotDialogState();
}

class _TimeSlotDialogState extends State<_TimeSlotDialog> {
  final _formKey = GlobalKey<FormState>();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  int _minOfficials = 1;
  int _maxOfficials = 3;

  @override
  void initState() {
    super.initState();
    if (widget.existingSlot != null) {
      final slot = widget.existingSlot!;
      _startTime = _parseTimeString(slot.startTime);
      _endTime = _parseTimeString(slot.endTime);
      _minOfficials = slot.minOfficials;
      _maxOfficials = slot.maxOfficials;
    }
  }

  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String get _dayName {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[widget.dayOfWeek - 1];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingSlot != null
            ? 'Edit Time Slot - $_dayName'
            : 'Add Time Slot - $_dayName',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Start Time'),
                    subtitle: Text(_formatTimeOfDay(_startTime)),
                    leading: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (time != null) {
                        setState(() {
                          _startTime = time;
                        });
                      }
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('End Time'),
                    subtitle: Text(_formatTimeOfDay(_endTime)),
                    leading: const Icon(Icons.access_time_filled),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (time != null) {
                        setState(() {
                          _endTime = time;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _minOfficials.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Min Officials',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final num = int.tryParse(value);
                      if (num == null || num < 1) {
                        return 'Must be ≥ 1';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _minOfficials = int.tryParse(value) ?? 1;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _maxOfficials.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Max Officials',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final num = int.tryParse(value);
                      if (num == null || num < _minOfficials) {
                        return 'Must be ≥ $_minOfficials';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      _maxOfficials = int.tryParse(value) ?? 3;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'startTime': _formatTimeOfDay(_startTime),
                'endTime': _formatTimeOfDay(_endTime),
                'minOfficials': _minOfficials,
                'maxOfficials': _maxOfficials,
              });
            }
          },
          child: Text(widget.existingSlot != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
