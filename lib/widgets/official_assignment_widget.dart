import 'package:flutter/material.dart';
import '../models/schedule_time_slot.dart';
import '../models/official_schedule_assignment.dart';
import '../services/border_schedule_service.dart';
import '../services/border_manager_service.dart';

class OfficialAssignmentWidget extends StatefulWidget {
  final ScheduleTimeSlot timeSlot;
  final String borderName;
  final VoidCallback onAssignmentChanged;

  const OfficialAssignmentWidget({
    super.key,
    required this.timeSlot,
    required this.borderName,
    required this.onAssignmentChanged,
  });

  @override
  State<OfficialAssignmentWidget> createState() =>
      _OfficialAssignmentWidgetState();
}

class _OfficialAssignmentWidgetState extends State<OfficialAssignmentWidget> {
  bool _isLoading = true;
  List<OfficialScheduleAssignment> _assignments = [];
  List<Map<String, dynamic>> _availableOfficials = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load current assignments for this time slot
      final assignments = await BorderScheduleService.getAssignmentsForTimeSlot(
        widget.timeSlot.id,
      );

      // Load available border officials for this border
      final officials = await _getAvailableBorderOfficials();

      setState(() {
        _assignments = assignments;
        _availableOfficials = officials;
        _isLoading = false;
      });

      debugPrint(
          '🔍 Data loaded - Assignments: ${assignments.length}, Officials: ${officials.length}');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getAvailableBorderOfficials() async {
    try {
      // Get the border ID from the template
      final template = await BorderScheduleService.getScheduleTemplate(
        widget.timeSlot.templateId,
      );

      if (template == null) return [];

      // Get border officials assigned to this border
      final response = await BorderManagerService.supabase
          .from('border_official_borders')
          .select('''
            profile_id,
            profiles!border_official_borders_profile_id_fkey(
              id,
              full_name,
              email,
              is_active
            )
          ''')
          .eq('border_id', template.borderId)
          .eq('is_active', true)
          .eq('profiles.is_active', true);

      final officials = (response as List).map((item) {
        final profile = item['profiles'];
        return {
          'id': profile['id'],
          'full_name': profile['full_name'],
          'email': profile['email'],
          'is_active': profile['is_active'],
        };
      }).toList();

      return officials;
    } catch (e) {
      debugPrint('❌ Error getting available border officials: $e');
      return [];
    }
  }

  Future<void> _assignOfficial(String profileId, String assignmentType) async {
    try {
      await BorderScheduleService.assignOfficialToTimeSlot(
        timeSlotId: widget.timeSlot.id,
        profileId: profileId,
        effectiveFrom: DateTime.now(),
        assignmentType: assignmentType,
      );

      await _loadData();
      widget.onAssignmentChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Official assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning official: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeAssignment(String assignmentId) async {
    try {
      await BorderScheduleService.removeOfficialAssignment(assignmentId);
      await _loadData();
      widget.onAssignmentChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment removed successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeSlotHeader(),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _buildErrorWidget()
            else
              _buildAssignmentContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: Colors.indigo.shade700, size: 20),
          const SizedBox(width: 8),
          Text(
            '${widget.timeSlot.dayName} ${widget.timeSlot.startTime} - ${widget.timeSlot.endTime}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade800,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${widget.timeSlot.minOfficials}-${widget.timeSlot.maxOfficials} officials',
              style: TextStyle(
                fontSize: 12,
                color: Colors.indigo.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 32),
          const SizedBox(height: 8),
          Text(
            'Error loading assignments',
            style: TextStyle(
              color: Colors.red.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _error!,
            style: TextStyle(color: Colors.red.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCurrentAssignments(),
        const SizedBox(height: 16),
        _buildAddAssignmentSection(),
      ],
    );
  }

  Widget _buildCurrentAssignments() {
    if (_assignments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Icon(Icons.person_off, color: Colors.grey.shade500, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No officials assigned',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    'Add officials to this time slot using the section below',
                    style: TextStyle(
                      fontSize: 12,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assigned Officials (${_assignments.length})',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ..._assignments.map((assignment) => _buildAssignmentCard(assignment)),
      ],
    );
  }

  Widget _buildAssignmentCard(OfficialScheduleAssignment assignment) {
    final official = _availableOfficials.firstWhere(
      (o) => o['id'] == assignment.profileId,
      orElse: () => {
        'id': assignment.profileId,
        'full_name': 'Unknown Official',
        'email': '',
      },
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _getAssignmentTypeColor(assignment.assignmentType),
            radius: 16,
            child: Icon(
              _getAssignmentTypeIcon(assignment.assignmentType),
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  official['full_name'] ?? 'Unknown Official',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (official['email'] != null && official['email'].isNotEmpty)
                  Text(
                    official['email'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getAssignmentTypeColor(assignment.assignmentType)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              assignment.assignmentTypeDisplayName,
              style: TextStyle(
                fontSize: 12,
                color: _getAssignmentTypeColor(assignment.assignmentType),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _confirmRemoveAssignment(assignment),
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            tooltip: 'Remove Assignment',
          ),
        ],
      ),
    );
  }

  Widget _buildAddAssignmentSection() {
    final unassignedOfficials = _availableOfficials.where((official) {
      return !_assignments
          .any((assignment) => assignment.profileId == official['id']);
    }).toList();

    if (unassignedOfficials.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'All available officials are assigned to this time slot',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add Official Assignment',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ...unassignedOfficials
            .map((official) => _buildAvailableOfficialCard(official)),
      ],
    );
  }

  Widget _buildAvailableOfficialCard(Map<String, dynamic> official) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            radius: 16,
            child: Icon(
              Icons.person,
              size: 16,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  official['full_name'] ?? 'Unknown Official',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (official['email'] != null && official['email'].isNotEmpty)
                  Text(
                    official['email'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (assignmentType) =>
                _assignOfficial(official['id'], assignmentType),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'primary',
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text('Assign as Primary'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Text('Assign as Backup'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'temporary',
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Text('Assign as Temporary'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Assign',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAssignmentTypeColor(String assignmentType) {
    switch (assignmentType) {
      case 'primary':
        return Colors.green.shade600;
      case 'backup':
        return Colors.orange.shade600;
      case 'temporary':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getAssignmentTypeIcon(String assignmentType) {
    switch (assignmentType) {
      case 'primary':
        return Icons.star;
      case 'backup':
        return Icons.backup;
      case 'temporary':
        return Icons.schedule;
      default:
        return Icons.person;
    }
  }

  Future<void> _confirmRemoveAssignment(
      OfficialScheduleAssignment assignment) async {
    final official = _availableOfficials.firstWhere(
      (o) => o['id'] == assignment.profileId,
      orElse: () => {'full_name': 'Unknown Official'},
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Assignment'),
        content: Text(
          'Are you sure you want to remove ${official['full_name']} from this time slot?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeAssignment(assignment.id);
    }
  }
}
