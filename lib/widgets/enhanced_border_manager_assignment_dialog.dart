import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/border_manager.dart';
import '../models/border.dart' as border_model;
import '../services/border_manager_service.dart';
import '../widgets/profile_image_widget.dart';

class EnhancedBorderManagerAssignmentDialog extends StatefulWidget {
  final List<BorderManager> borderManagers;
  final String countryId;
  final String authorityId;
  final BorderManager? selectedManager;
  final VoidCallback onAssignmentComplete;

  const EnhancedBorderManagerAssignmentDialog({
    super.key,
    required this.borderManagers,
    required this.countryId,
    required this.authorityId,
    this.selectedManager,
    required this.onAssignmentComplete,
  });

  @override
  State<EnhancedBorderManagerAssignmentDialog> createState() =>
      _EnhancedBorderManagerAssignmentDialogState();
}

class _EnhancedBorderManagerAssignmentDialogState
    extends State<EnhancedBorderManagerAssignmentDialog> {
  bool _isLoading = true;
  String? _error;
  List<border_model.Border> _availableBorders = [];
  BorderManager? _selectedManager;
  Set<String> _selectedBorderIds = <String>{};
  Set<String> _originallyAssignedBorderIds = <String>{};
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedManager != null) {
      _selectedManager = widget.selectedManager;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final borders = await BorderManagerService.getBordersForCountry(
        widget.countryId,
      );

      // If a manager is selected, load their current border assignments
      Set<String> assignedBorderIds = <String>{};
      if (_selectedManager != null) {
        try {
          final assignments =
              await BorderManagerService.getBorderManagerAssignmentsByAuthority(
            widget.authorityId,
          );

          // Find assignments for the selected manager
          for (final assignment in assignments) {
            for (final managerAssignment in assignment.assignedManagers) {
              if (managerAssignment.profileId == _selectedManager!.profileId) {
                assignedBorderIds.add(assignment.borderId);
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('Error loading manager assignments: $e');
        }
      }

      debugPrint(
          '🔍 Available borders: ${borders.map((b) => '${b.name} (${b.id})').toList()}');
      debugPrint('🔍 Selected border IDs: $assignedBorderIds');

      setState(() {
        _availableBorders = borders;
        _selectedBorderIds = Set<String>.from(assignedBorderIds);
        _originallyAssignedBorderIds = Set<String>.from(assignedBorderIds);
        _isLoading = false;
      });

      debugPrint('🔍 Final _selectedBorderIds: $_selectedBorderIds');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_selectedManager == null) return;

    setState(() {
      _isAssigning = true;
    });

    try {
      // Find borders to assign (newly selected)
      final bordersToAssign =
          _selectedBorderIds.difference(_originallyAssignedBorderIds);

      // Find borders to unassign (previously selected but now unchecked)
      final bordersToUnassign =
          _originallyAssignedBorderIds.difference(_selectedBorderIds);

      // Assign new borders
      for (final borderId in bordersToAssign) {
        await BorderManagerService.assignManagerToBorder(
          _selectedManager!.profileId,
          borderId,
        );
      }

      // Unassign removed borders
      for (final borderId in bordersToUnassign) {
        await BorderManagerService.revokeManagerFromBorder(
          _selectedManager!.profileId,
          borderId,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();

        // Show appropriate success message
        String message;
        if (bordersToAssign.isNotEmpty && bordersToUnassign.isNotEmpty) {
          message =
              'Successfully updated border assignments for ${_selectedManager!.fullName}';
        } else if (bordersToAssign.isNotEmpty) {
          message =
              'Successfully assigned ${bordersToAssign.length} border(s) to ${_selectedManager!.fullName}';
        } else if (bordersToUnassign.isNotEmpty) {
          message =
              'Successfully removed ${bordersToUnassign.length} border(s) from ${_selectedManager!.fullName}';
        } else {
          message = 'No changes made to border assignments';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
          ),
        );
        widget.onAssignmentComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating assignments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAssigning = false;
        });
      }
    }
  }

  void _onManagerSelected(BorderManager manager) {
    setState(() {
      _selectedManager = manager;
    });
    _loadData(); // Reload data to get the manager's current assignments
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.manage_accounts,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Assign Border Manager',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
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
            // Content
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.orange),
                            SizedBox(height: 16),
                            Text('Loading managers and borders...'),
                          ],
                        ),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading data',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: const TextStyle(fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadData,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Manager Selection
                              Text(
                                'Select Border Manager',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (widget.borderManagers.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_outlined,
                                        color: Colors.orange.shade600,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'No border managers available. Please assign the Border Manager role to users first.',
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children:
                                        widget.borderManagers.map((manager) {
                                      final isSelected =
                                          _selectedManager?.profileId ==
                                              manager.profileId;
                                      return InkWell(
                                        onTap: () {
                                          _onManagerSelected(manager);
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.orange.shade50
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Radio<BorderManager>(
                                                value: manager,
                                                groupValue: _selectedManager,
                                                onChanged: (value) {
                                                  if (value != null) {
                                                    _onManagerSelected(value);
                                                  }
                                                },
                                                activeColor: Colors.orange,
                                              ),
                                              const SizedBox(width: 12),
                                              ProfileImageWidget(
                                                currentImageUrl:
                                                    manager.profileImageUrl,
                                                size: 40,
                                                isEditable: false,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      manager.displayName ??
                                                          manager.fullName,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    Text(
                                                      manager.email,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              const SizedBox(height: 24),
                              // Border Selection
                              Text(
                                'Select Border',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_availableBorders.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.orange.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_outlined,
                                        color: Colors.orange.shade600,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'No borders available for assignment.',
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: _availableBorders.map((border) {
                                      final isSelected = _selectedBorderIds
                                          .contains(border.id);
                                      debugPrint(
                                          '🔍 Border ${border.name} (${border.id}): isSelected = $isSelected, _selectedBorderIds = $_selectedBorderIds');
                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedBorderIds
                                                  .remove(border.id);
                                            } else {
                                              _selectedBorderIds.add(border.id);
                                            }
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.orange.shade50
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value: isSelected,
                                                onChanged: (value) {
                                                  setState(() {
                                                    if (value == true) {
                                                      _selectedBorderIds
                                                          .add(border.id);
                                                    } else {
                                                      _selectedBorderIds
                                                          .remove(border.id);
                                                    }
                                                  });
                                                },
                                                activeColor: Colors.orange,
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(
                                                Icons.location_on,
                                                color: Colors.orange.shade400,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      border.name,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    if (border.description !=
                                                        null)
                                                      Text(
                                                        border.description!,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
            ),
            // Actions
            if (!_isLoading && _error == null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isAssigning
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isAssigning || _selectedManager == null
                            ? null
                            : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isAssigning
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
