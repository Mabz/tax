import 'package:flutter/material.dart';
import '../models/border_manager.dart';
import '../models/border.dart' as border_model;
import '../services/border_manager_service.dart';
import '../widgets/profile_image_widget.dart';
import '../widgets/enhanced_border_manager_assignment_widget.dart';

class EnhancedBorderManagerAssignmentDialogV2 extends StatefulWidget {
  final List<BorderManager> borderManagers;
  final String countryId;
  final String authorityId;
  final BorderManager? selectedManager;
  final VoidCallback onAssignmentComplete;

  const EnhancedBorderManagerAssignmentDialogV2({
    super.key,
    required this.borderManagers,
    required this.countryId,
    required this.authorityId,
    this.selectedManager,
    required this.onAssignmentComplete,
  });

  @override
  State<EnhancedBorderManagerAssignmentDialogV2> createState() =>
      _EnhancedBorderManagerAssignmentDialogV2State();
}

class _EnhancedBorderManagerAssignmentDialogV2State
    extends State<EnhancedBorderManagerAssignmentDialogV2> {
  bool _isLoading = true;
  bool _isLoadingAssignments = false;
  bool _isSaving = false;
  String? _error;
  List<border_model.Border> _availableBorders = [];
  BorderManager? _selectedManager;
  List<BorderAssignmentForManager> _borderAssignments = [];

  @override
  void initState() {
    super.initState();
    _selectedManager = widget.selectedManager ??
        (widget.borderManagers.isNotEmpty ? widget.borderManagers.first : null);
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

      setState(() {
        _availableBorders = borders;
        _isLoading = false;
      });

      if (_selectedManager != null) {
        _loadBorderAssignments();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBorderAssignments() async {
    if (_selectedManager == null) return;

    setState(() {
      _isLoadingAssignments = true;
    });

    try {
      // Get current assignments for this manager
      final currentAssignments =
          await _getCurrentAssignments(_selectedManager!.profileId);

      // Create assignment objects for all borders
      final assignments = _availableBorders.map((border) {
        final isAssigned = currentAssignments.contains(border.id);
        return BorderAssignmentForManager(
          borderId: border.id,
          borderName: border.name,
          isAssigned: isAssigned,
        );
      }).toList();

      setState(() {
        _borderAssignments = assignments;
        _isLoadingAssignments = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load border assignments: $e';
        _isLoadingAssignments = false;
      });
    }
  }

  Future<Set<String>> _getCurrentAssignments(String profileId) async {
    try {
      final response = await BorderManagerService.supabase
          .from('border_manager_borders')
          .select('border_id')
          .eq('profile_id', profileId)
          .eq('is_active', true);

      return (response as List)
          .map((item) => item['border_id'] as String)
          .toSet();
    } catch (e) {
      return <String>{};
    }
  }

  Future<void> _saveBorderAssignments() async {
    if (_selectedManager == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Get current assignments
      final currentAssignments =
          await _getCurrentAssignments(_selectedManager!.profileId);

      // Get new assignments
      final newAssignments = _borderAssignments
          .where((a) => a.isAssigned)
          .map((a) => a.borderId)
          .toSet();

      // Revoke removed assignments
      final toRevoke = currentAssignments.difference(newAssignments);
      for (final borderId in toRevoke) {
        await BorderManagerService.revokeManagerFromBorder(
          _selectedManager!.profileId,
          borderId,
        );
      }

      // Add new assignments
      final toAdd = newAssignments.difference(currentAssignments);
      for (final borderId in toAdd) {
        await BorderManagerService.assignManagerToBorder(
          _selectedManager!.profileId,
          borderId,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully updated assignments for ${_selectedManager!.fullName}',
            ),
            backgroundColor: Colors.purple,
          ),
        );
        widget.onAssignmentComplete();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save assignments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade400, Colors.purple.shade600],
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
                      'Border Manager Assignment',
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
                            CircularProgressIndicator(color: Colors.purple),
                            SizedBox(height: 16),
                            Text('Loading borders...'),
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
                                    backgroundColor: Colors.purple,
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
                              DropdownButtonFormField<BorderManager>(
                                value: _selectedManager,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.purple.shade600,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                items: widget.borderManagers.map((manager) {
                                  return DropdownMenuItem(
                                    value: manager,
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: Row(
                                        children: [
                                          ProfileImageWidget(
                                            currentImageUrl:
                                                manager.profileImageUrl,
                                            size: 32,
                                            isEditable: false,
                                          ),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  manager.displayName ??
                                                      manager.fullName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  manager.email,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (manager) {
                                  setState(() {
                                    _selectedManager = manager;
                                  });
                                  if (manager != null) {
                                    _loadBorderAssignments();
                                  }
                                },
                              ),
                              const SizedBox(height: 24),
                              // Border Assignments
                              if (_selectedManager != null) ...[
                                Row(
                                  children: [
                                    Text(
                                      'Border Assignments (${_borderAssignments.where((a) => a.isAssigned).length}/${_borderAssignments.length})',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_isLoadingAssignments)
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.purple,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_borderAssignments.isEmpty &&
                                    !_isLoadingAssignments)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info_outline,
                                            color: Colors.grey),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'No borders available for assignment.',
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ...(_borderAssignments.map((assignment) {
                                    return EnhancedBorderManagerAssignmentWidget(
                                      assignment: assignment,
                                      onChanged: (updatedAssignment) {
                                        final index =
                                            _borderAssignments.indexWhere(
                                          (a) =>
                                              a.borderId ==
                                              updatedAssignment.borderId,
                                        );
                                        if (index != -1) {
                                          setState(() {
                                            _borderAssignments[index] =
                                                updatedAssignment;
                                          });
                                        }
                                      },
                                    );
                                  }).toList()),
                              ],
                            ],
                          ),
                        ),
            ),
            // Actions
            if (!_isLoading && _error == null && _selectedManager != null)
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
                        onPressed: _isSaving
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
                        onPressed: _isSaving ? null : _saveBorderAssignments,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Assignments',
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
