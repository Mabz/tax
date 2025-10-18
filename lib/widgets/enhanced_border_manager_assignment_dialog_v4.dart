import 'package:flutter/material.dart';
import '../models/border_manager.dart';
import '../models/border.dart' as border_model;
import '../services/border_manager_service.dart';

class EnhancedBorderManagerAssignmentDialogV4 extends StatefulWidget {
  final List<BorderManager> borderManagers;
  final String countryId;
  final String authorityId;
  final BorderManager? selectedManager;
  final VoidCallback onAssignmentComplete;

  const EnhancedBorderManagerAssignmentDialogV4({
    super.key,
    required this.borderManagers,
    required this.countryId,
    required this.authorityId,
    this.selectedManager,
    required this.onAssignmentComplete,
  });

  @override
  State<EnhancedBorderManagerAssignmentDialogV4> createState() =>
      _EnhancedBorderManagerAssignmentDialogV4State();
}

class _EnhancedBorderManagerAssignmentDialogV4State
    extends State<EnhancedBorderManagerAssignmentDialogV4> {
  bool _isLoading = false;
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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load borders
      final borders = await BorderManagerService.getBordersForCountry(
        widget.countryId,
      );

      setState(() {
        _availableBorders = borders;
        _isLoading = false;
      });

      // Load assignments if manager is selected
      if (_selectedManager != null) {
        await _loadBorderAssignments();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
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
        _error = 'Failed to load assignments: $e';
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

  int get _assignedCount => _borderAssignments.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.people, color: Colors.purple, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Border Manager Assignment',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Manager Selection
            const Text(
              'Select Border Manager:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<BorderManager>(
                  value: _selectedManager,
                  hint: const Text('Select a manager'),
                  isExpanded: true,
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
                      _borderAssignments.clear();
                    });
                    if (manager != null) {
                      _loadBorderAssignments();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
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
                                'Error',
                                style: TextStyle(
                                  fontSize: 18,
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
                      : _selectedManager == null
                          ? const Center(
                              child: Text(
                                'Please select a border manager to view assignments',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Assignment counter
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.purple.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.assignment,
                                        color: Colors.purple.shade700,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Border Assignments: $_assignedCount/${_availableBorders.length}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.purple.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Border list
                                Expanded(
                                  child: _availableBorders.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No borders available for assignment',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: _availableBorders.length,
                                          itemBuilder: (context, index) {
                                            final border =
                                                _availableBorders[index];
                                            final isAssigned =
                                                _borderAssignments[border.id] ??
                                                    false;

                                            return Card(
                                              margin: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: CheckboxListTile(
                                                title: Text(
                                                  border.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                subtitle: border.description !=
                                                        null
                                                    ? Text(border.description!)
                                                    : null,
                                                value: isAssigned,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _borderAssignments[border
                                                        .id] = value ?? false;
                                                  });
                                                },
                                                activeColor: Colors.purple,
                                                controlAffinity:
                                                    ListTileControlAffinity
                                                        .leading,
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
            ),

            // Actions
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving || _selectedManager == null
                      ? null
                      : _saveBorderAssignments,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Assignments'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
