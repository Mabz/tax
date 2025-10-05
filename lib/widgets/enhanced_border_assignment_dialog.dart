import 'package:flutter/material.dart';
import '../models/border_official.dart';
import '../models/enhanced_border_assignment.dart';
import '../widgets/enhanced_border_assignment_widget.dart';
import '../services/enhanced_border_service.dart';

/// Enhanced border assignment dialog with direction permissions
class EnhancedBorderAssignmentDialog extends StatefulWidget {
  final List<BorderOfficial> borderOfficials;
  final String countryId;
  final BorderOfficial? selectedOfficial;
  final VoidCallback? onSaved;

  const EnhancedBorderAssignmentDialog({
    super.key,
    required this.borderOfficials,
    required this.countryId,
    this.selectedOfficial,
    this.onSaved,
  });

  @override
  State<EnhancedBorderAssignmentDialog> createState() =>
      _EnhancedBorderAssignmentDialogState();
}

class _EnhancedBorderAssignmentDialogState
    extends State<EnhancedBorderAssignmentDialog> {
  BorderOfficial? _selectedOfficial;
  List<EnhancedBorderAssignment> _borderAssignments = [];
  bool _isLoading = false;
  bool _isLoadingAssignments = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedOfficial = widget.selectedOfficial ??
        (widget.borderOfficials.isNotEmpty
            ? widget.borderOfficials.first
            : null);
    if (_selectedOfficial != null) {
      _loadBorderAssignments();
    }
  }

  Future<void> _loadBorderAssignments() async {
    if (_selectedOfficial == null) return;

    setState(() {
      _isLoadingAssignments = true;
      _error = null;
    });

    try {
      final assignments =
          await EnhancedBorderService.getEnhancedBorderAssignments(
        profileId: _selectedOfficial!.profileId,
        countryId: widget.countryId,
      );

      setState(() {
        _borderAssignments = assignments
            .map((a) => EnhancedBorderAssignment(
                  borderId: a['borderId'],
                  borderName: a['borderName'],
                  isAssigned: a['isAssigned'],
                  canCheckIn: a['canCheckIn'],
                  canCheckOut: a['canCheckOut'],
                ))
            .toList();
        _isLoadingAssignments = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load border assignments: $e';
        _isLoadingAssignments = false;
      });
    }
  }

  Future<void> _saveBorderAssignments() async {
    if (_selectedOfficial == null) return;

    // Validate assignments
    final errors = EnhancedBorderService.validateBorderAssignments(
      _borderAssignments
          .map((a) => {
                'borderName': a.borderName,
                'isAssigned': a.isAssigned,
                'canCheckIn': a.canCheckIn,
                'canCheckOut': a.canCheckOut,
              })
          .toList(),
    );

    if (errors.isNotEmpty) {
      _showValidationErrors(errors);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current assignments
      final currentAssignments =
          await EnhancedBorderService.getBorderAssignmentsWithPermissions(
        widget.countryId,
      );

      final currentForOfficial = currentAssignments
          .where((a) => a.profileId == _selectedOfficial!.profileId)
          .map((a) => a.borderId)
          .toSet();

      // Prepare new assignments
      final newAssignments = _borderAssignments
          .where((a) => a.isAssigned)
          .map((a) => {
                'borderId': a.borderId,
                'borderName': a.borderName,
                'canCheckIn': a.canCheckIn,
                'canCheckOut': a.canCheckOut,
              })
          .toList();

      final newBorderIds =
          newAssignments.map((a) => a['borderId'] as String).toSet();

      // Revoke removed assignments
      final toRevoke = currentForOfficial.difference(newBorderIds);
      for (final borderId in toRevoke) {
        await EnhancedBorderService.revokeOfficialFromBorder(
          _selectedOfficial!.profileId,
          borderId,
        );
      }

      // Add/update new assignments
      if (newAssignments.isNotEmpty) {
        await EnhancedBorderService.batchAssignOfficialToBorders(
          profileId: _selectedOfficial!.profileId,
          borderAssignments: newAssignments,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Updated border assignments for ${_selectedOfficial!.fullName}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update assignments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showValidationErrors(Map<String, String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Validation Errors'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: errors.entries
              .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${e.key}: ${e.value}'),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width > 700
            ? 700
            : MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.security, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Border Assignment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Official selector
            _buildOfficialSelector(),
            const SizedBox(height: 20),

            // Border assignments
            Expanded(child: _buildBorderAssignments()),

            // Actions
            const SizedBox(height: 20),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Select Border Official',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<BorderOfficial>(
            value: _selectedOfficial,
            decoration: InputDecoration(
              hintText: 'Choose an official...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.orange.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.orange.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: widget.borderOfficials.map((official) {
              return DropdownMenuItem<BorderOfficial>(
                value: official,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      official.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      official.email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
            selectedItemBuilder: (BuildContext context) {
              return widget.borderOfficials.map((official) {
                return Text(
                  official.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                );
              }).toList();
            },
            onChanged: (BorderOfficial? official) {
              setState(() {
                _selectedOfficial = official;
                _borderAssignments.clear();
              });
              if (official != null) {
                _loadBorderAssignments();
              }
            },
            isExpanded: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBorderAssignments() {
    if (_selectedOfficial == null) {
      return const Center(
        child: Text(
          'Please select a border official to manage assignments',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_isLoadingAssignments) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text('Loading border assignments...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBorderAssignments,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_borderAssignments.isEmpty) {
      return const Center(
        child: Text(
          'No borders available for assignment',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final assignedCount = _borderAssignments.where((a) => a.isAssigned).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Border Assignments ($assignedCount/${_borderAssignments.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Assignments list
        Expanded(
          child: ListView.builder(
            itemCount: _borderAssignments.length,
            itemBuilder: (context, index) {
              return EnhancedBorderAssignmentWidget(
                assignment: _borderAssignments[index],
                onChanged: (updatedAssignment) {
                  setState(() {
                    _borderAssignments[index] = updatedAssignment;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      children: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading || _selectedOfficial == null
              ? null
              : _saveBorderAssignments,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
