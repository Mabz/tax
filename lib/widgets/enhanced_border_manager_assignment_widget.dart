import 'package:flutter/material.dart';
import '../services/border_manager_service.dart';

/// Enhanced border assignment widget for Border Managers
class EnhancedBorderManagerAssignmentWidget extends StatefulWidget {
  final BorderAssignmentForManager assignment;
  final Function(BorderAssignmentForManager) onChanged;

  const EnhancedBorderManagerAssignmentWidget({
    super.key,
    required this.assignment,
    required this.onChanged,
  });

  @override
  State<EnhancedBorderManagerAssignmentWidget> createState() =>
      _EnhancedBorderManagerAssignmentWidgetState();
}

class _EnhancedBorderManagerAssignmentWidgetState
    extends State<EnhancedBorderManagerAssignmentWidget> {
  late BorderAssignmentForManager _assignment;

  @override
  void initState() {
    super.initState();
    _assignment = widget.assignment;
  }

  void _updateAssignment(BorderAssignmentForManager newAssignment) {
    setState(() {
      _assignment = newAssignment;
    });
    widget.onChanged(newAssignment);
  }

  Color _getStatusColor() {
    return _assignment.isAssigned ? Colors.purple : Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: _assignment.isAssigned ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Checkbox(
              value: _assignment.isAssigned,
              onChanged: (bool? value) {
                _updateAssignment(_assignment.copyWith(
                  isAssigned: value ?? false,
                ));
              },
              activeColor: Colors.purple,
            ),
            Expanded(
              child: Text(
                _assignment.borderName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: _assignment.isAssigned
                      ? Colors.black87
                      : Colors.grey.shade600,
                ),
              ),
            ),
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getStatusColor().withOpacity(0.3)),
              ),
              child: Text(
                _assignment.isAssigned ? 'Assigned' : 'Not Assigned',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _getStatusColor(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
