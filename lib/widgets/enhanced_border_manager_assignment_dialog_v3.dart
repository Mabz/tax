import 'package:flutter/material.dart';
import '../models/border_manager.dart';
import '../models/border.dart' as border_model;
import '../services/border_manager_service.dart';

class EnhancedBorderManagerAssignmentDialogV3 extends StatefulWidget {
  final List<BorderManager> borderManagers;
  final String countryId;
  final String authorityId;
  final BorderManager? selectedManager;
  final VoidCallback onAssignmentComplete;

  const EnhancedBorderManagerAssignmentDialogV3({
    super.key,
    required this.borderManagers,
    required this.countryId,
    required this.authorityId,
    this.selectedManager,
    required this.onAssignmentComplete,
  });

  @override
  State<EnhancedBorderManagerAssignmentDialogV3> createState() =>
      _EnhancedBorderManagerAssignmentDialogV3State();
}

class _EnhancedBorderManagerAssignmentDialogV3State
    extends State<EnhancedBorderManagerAssignmentDialogV3> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  List<border_model.Border> _availableBorders = [];
  BorderManager? _selectedManager;
  Map<String, bool> _borderAssignments = {};

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

    try {
      // Get current assignments for this manager
      final response = await BorderManagerService.supabase
          .from('border_manager_borders')
          .select('border_id')
          .eq('profile_id', _selectedManager!.profileId)
          .eq('is_active', true);

      final currentAssignments =
          (response as List).map((item) => item['border_id'] as String).toSet();

      // Create assignment map
      final assignments = <String, bool>{};
      for (var border in _availableBorders) {
        assignments[border.id] = currentAssignments.contains(border.id);
      }

      setState(() {
        _borderAssignments = assignments;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load border assignments: $e';
      });
    }
  }

  Future<void> _saveBorderAssignments() async {
    if (_selectedManager == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Get current assignments
      final response = await BorderManagerService.supabase
          .from('border_manager_borders')
          .select('border_id')
          .eq('profile_id', _selectedManager!.profileId)
          .eq('is_active', true);

      final currentAssignments =
          (response as List).map((item) => item['border_id'] as String).toSet();

      // Get new assignments
      final newAssignments = _borderAssignments.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
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
    return AlertDialog(
      title: const Text('Border Manager Assignment'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.purple),
                    SizedBox(height: 16),
                    Text('Loading borders...'),
                  ],
                ),
              )
            : _error != null
                ? Center(
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
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Manager Selection
                      const Text(
                        'Select Border Manager:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<BorderManager>(
                        value: _selectedManager,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: widget.borderManagers.map((manager) {
                          return DropdownMenuItem(
                            value: manager,
                            child: Text(
                              manager.displayName ?? manager.fullName,
                              overflow: TextOverflow.ellipsis,
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
                      const SizedBox(height: 16),
                      // Border Assignments
                      if (_selectedManager != null) ...[
                        Text(
                          'Border Assignments (${_borderAssignments.values.where((v) => v).length}/${_borderAssignments.length}):',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _availableBorders.isEmpty
                              ? const Center(
                                  child: Text('No borders available'),
                                )
                              : ListView.builder(
                                  itemCount: _availableBorders.length,
                                  itemBuilder: (context, index) {
                                    final border = _availableBorders[index];
                                    final isAssigned =
                                        _borderAssignments[border.id] ?? false;

                                    return CheckboxListTile(
                                      title: Text(border.name),
                                      subtitle: border.description != null
                                          ? Text(border.description!)
                                          : null,
                                      value: isAssigned,
                                      onChanged: (value) {
                                        setState(() {
                                          _borderAssignments[border.id] =
                                              value ?? false;
                                        });
                                      },
                                      activeColor: Colors.purple,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving || _selectedManager == null
              ? null
              : _saveBorderAssignments,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
