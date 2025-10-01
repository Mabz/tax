import 'package:flutter/material.dart';
import '../models/enhanced_border_assignment.dart';

/// Enhanced border assignment widget with direction permissions
class EnhancedBorderAssignmentWidget extends StatefulWidget {
  final EnhancedBorderAssignment assignment;
  final Function(EnhancedBorderAssignment) onChanged;

  const EnhancedBorderAssignmentWidget({
    super.key,
    required this.assignment,
    required this.onChanged,
  });

  @override
  State<EnhancedBorderAssignmentWidget> createState() =>
      _EnhancedBorderAssignmentWidgetState();
}

class _EnhancedBorderAssignmentWidgetState
    extends State<EnhancedBorderAssignmentWidget> {
  late EnhancedBorderAssignment _assignment;

  @override
  void initState() {
    super.initState();
    _assignment = widget.assignment;
  }

  void _updateAssignment(EnhancedBorderAssignment newAssignment) {
    setState(() {
      _assignment = newAssignment;
    });
    widget.onChanged(newAssignment);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: _assignment.isAssigned ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Border name and main assignment checkbox
            Row(
              children: [
                Checkbox(
                  value: _assignment.isAssigned,
                  onChanged: (bool? value) {
                    _updateAssignment(_assignment.copyWith(
                      isAssigned: value ?? false,
                      // Reset permissions when unassigning
                      canCheckIn: value == true ? _assignment.canCheckIn : true,
                      canCheckOut:
                          value == true ? _assignment.canCheckOut : true,
                    ));
                  },
                  activeColor: Colors.orange,
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
                // Permission summary chip
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPermissionColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _getPermissionColor().withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _assignment.permissionDescription,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getPermissionColor(),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),

            // Direction permissions (only show when assigned)
            if (_assignment.isAssigned) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permissions:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPermissionCheckbox(
                            'Check-In',
                            'Process vehicle entries',
                            _assignment.canCheckIn,
                            Icons.login,
                            Colors.green,
                            (value) => _updateAssignment(
                              _assignment.copyWith(canCheckIn: value),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPermissionCheckbox(
                            'Check-Out',
                            'Process vehicle exits',
                            _assignment.canCheckOut,
                            Icons.logout,
                            Colors.blue,
                            (value) => _updateAssignment(
                              _assignment.copyWith(canCheckOut: value),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Warning if no permissions selected
                    if (_assignment.isAssigned &&
                        !_assignment.canCheckIn &&
                        !_assignment.canCheckOut)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning,
                                color: Colors.red.shade600, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'At least one permission must be selected',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCheckbox(
    String title,
    String description,
    bool value,
    IconData icon,
    Color color,
    Function(bool) onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: value ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? color.withValues(alpha: 0.3) : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: value ? color : Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: color,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: value ? color : Colors.grey.shade700,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: value ? _getDarkerColor(color) : Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Color _getPermissionColor() {
    if (!_assignment.isAssigned) return Colors.grey;
    if (_assignment.canCheckIn && _assignment.canCheckOut) return Colors.orange;
    if (_assignment.canCheckIn) return Colors.green;
    if (_assignment.canCheckOut) return Colors.blue;
    return Colors.red;
  }

  Color _getDarkerColor(Color color) {
    // Create a darker version of the color by reducing the lightness
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
  }
}
