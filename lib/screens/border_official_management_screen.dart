import 'package:flutter/material.dart';
import '../models/border_assignment.dart';
import '../models/border_official.dart';
import '../models/border.dart' as border_model;
import '../services/border_official_service.dart';

class BorderOfficialManagementScreen extends StatefulWidget {
  final Map<String, dynamic> selectedCountry;

  const BorderOfficialManagementScreen({
    super.key,
    required this.selectedCountry,
  });

  @override
  State<BorderOfficialManagementScreen> createState() =>
      _BorderOfficialManagementScreenState();
}

class _BorderOfficialManagementScreenState
    extends State<BorderOfficialManagementScreen> {
  bool _isLoading = true;
  String? _error;
  List<BorderOfficial> _borderOfficials = [];
  List<BorderAssignment> _borderAssignments = [];
  List<border_model.Border> _availableBorders = [];

  String get _countryId => widget.selectedCountry['id'] as String;
  String get _countryName => widget.selectedCountry['name'] as String;

  @override
  void initState() {
    super.initState();
    _loadCountryData();
  }

  Future<void> _loadCountryData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final futures = await Future.wait([
        BorderOfficialService.getBorderOfficialsForCountry(_countryId),
        BorderOfficialService.getAssignedBorders(countryId: _countryId),
        BorderOfficialService.getBordersForCountry(_countryId),
      ]);

      setState(() {
        _borderOfficials = futures[0] as List<BorderOfficial>;
        _borderAssignments = futures[1] as List<BorderAssignment>;
        _availableBorders = futures[2] as List<border_model.Border>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load country data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _revokeOfficialFromBorder(
      String officialId, String borderId) async {
    try {
      await BorderOfficialService.revokeOfficialFromBorder(
          officialId, borderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Border official revoked successfully'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadCountryData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revoke official: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Silent versions for batch operations (no snackbars, no reload)
  Future<void> _assignOfficialToBorderSilent(
      String officialId, String borderId) async {
    await BorderOfficialService.assignOfficialToBorder(officialId, borderId);
  }

  Future<void> _revokeOfficialFromBorderSilent(
      String officialId, String borderId) async {
    await BorderOfficialService.revokeOfficialFromBorder(officialId, borderId);
  }

  void _showBorderAssignmentDialog() async {
    if (_borderOfficials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No border officials available for assignment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _BorderAssignmentDialog(
        borderOfficials: _borderOfficials,
        availableBorders: _availableBorders,
        borderAssignments: _borderAssignments,
        onAssign: _assignOfficialToBorderSilent,
        onRevoke: _revokeOfficialFromBorderSilent,
        onSaved: _loadCountryData,
      ),
    );
  }

  void _showBorderAssignmentDialogForOfficial(BorderOfficial official) async {
    showDialog(
      context: context,
      builder: (context) => _BorderAssignmentDialog(
        borderOfficials: _borderOfficials,
        availableBorders: _availableBorders,
        borderAssignments: _borderAssignments,
        selectedOfficial: official,
        onAssign: _assignOfficialToBorderSilent,
        onRevoke: _revokeOfficialFromBorderSilent,
        onSaved: _loadCountryData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Border Official Management'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _showBorderAssignmentDialog,
              tooltip: 'Manage Border Assignments',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text('Loading border officials...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCountryData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildCountryHeader(),
        const SizedBox(height: 16),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildCountryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: Colors.orange.shade800,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Managing Border Officials for:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _countryName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.orange.shade700,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.orange.shade700,
            tabs: const [
              Tab(text: 'Border Officials', icon: Icon(Icons.person_outline)),
              Tab(
                  text: 'Border Assignments',
                  icon: Icon(Icons.assignment_outlined)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBorderOfficialsTab(),
                _buildBorderAssignmentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorderOfficialsTab() {
    if (_borderOfficials.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No border officials found for this country.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with Add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_borderOfficials.length} Border Officials',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showBorderAssignmentDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Assign Borders',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Officials list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _borderOfficials.length,
            itemBuilder: (context, index) {
              final official = _borderOfficials[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Text(
                      official.fullName.isNotEmpty
                          ? official.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    official.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        official.email,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                  trailing: SizedBox(
                    width: 80,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (official.hasAssignedBorders)
                          Icon(Icons.check_circle,
                              color: Colors.green.shade600, size: 20)
                        else
                          Icon(Icons.radio_button_unchecked,
                              color: Colors.grey.shade400, size: 20),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () =>
                              _showBorderAssignmentDialogForOfficial(official),
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Edit border assignments',
                          padding: const EdgeInsets.all(4),
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assigned Borders:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children:
                                official.assignedBordersList.map((borderName) {
                              return Chip(
                                label: Text(
                                  borderName,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                backgroundColor: Colors.orange.shade50,
                                side: BorderSide(color: Colors.orange.shade200),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBorderAssignmentsTab() {
    if (_borderAssignments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_late_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No border assignments found for this country.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _borderAssignments.length,
      itemBuilder: (context, index) {
        final assignment = _borderAssignments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              Icons.location_on,
              color: Colors.orange.shade600,
            ),
            title: Text(
              assignment.borderName,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Type: ${assignment.borderTypeLabel}',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  'Official: ${assignment.officialName}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  'Email: ${assignment.officialEmail}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  'Assigned: ${assignment.assignedAt.toString().split(' ')[0]}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
            trailing: IconButton(
              icon:
                  Icon(Icons.remove_circle_outline, color: Colors.red.shade600),
              onPressed: () => _showRevokeConfirmation(assignment),
              tooltip: 'Revoke Assignment',
            ),
          ),
        );
      },
    );
  }

  void _showRevokeConfirmation(BorderAssignment assignment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Assignment'),
        content: Text(
          'Are you sure you want to revoke ${assignment.officialName} from ${assignment.borderName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _revokeOfficialFromBorder(
                assignment.officialProfileId,
                assignment.borderId,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _BorderAssignmentDialog extends StatefulWidget {
  final List<BorderOfficial> borderOfficials;
  final List<border_model.Border> availableBorders;
  final List<BorderAssignment> borderAssignments;
  final BorderOfficial? selectedOfficial;
  final Function(String officialId, String borderId) onAssign;
  final Function(String officialId, String borderId) onRevoke;
  final VoidCallback? onSaved;

  const _BorderAssignmentDialog({
    required this.borderOfficials,
    required this.availableBorders,
    required this.borderAssignments,
    this.selectedOfficial,
    required this.onAssign,
    required this.onRevoke,
    this.onSaved,
  });

  @override
  State<_BorderAssignmentDialog> createState() =>
      _BorderAssignmentDialogState();
}

class _BorderAssignmentDialogState extends State<_BorderAssignmentDialog> {
  BorderOfficial? _selectedOfficial;
  final Map<String, bool> _borderAssignments = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedOfficial = widget.selectedOfficial ??
        (widget.borderOfficials.isNotEmpty
            ? widget.borderOfficials.first
            : null);
    _initializeBorderAssignments();
  }

  void _initializeBorderAssignments() {
    _borderAssignments.clear();
    for (final border in widget.availableBorders) {
      // Check if this border is assigned to the selected official
      final isAssigned = widget.borderAssignments.any(
        (assignment) =>
            assignment.borderId == border.id &&
            assignment.officialProfileId == _selectedOfficial?.profileId,
      );
      _borderAssignments[border.id] = isAssigned;
    }
  }

  Future<void> _saveBorderAssignments() async {
    if (_selectedOfficial == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current assignments for this official
      final currentAssignments = widget.borderAssignments
          .where((a) => a.officialProfileId == _selectedOfficial!.profileId)
          .map((a) => a.borderId)
          .toSet();

      // Get new assignments from checkboxes
      final newAssignments = _borderAssignments.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toSet();

      // Find borders to assign (in new but not in current)
      final toAssign = newAssignments.difference(currentAssignments);

      // Find borders to revoke (in current but not in new)
      final toRevoke = currentAssignments.difference(newAssignments);

      // Execute assignments
      for (final borderId in toAssign) {
        await widget.onAssign(_selectedOfficial!.profileId, borderId);
      }

      // Execute revocations
      for (final borderId in toRevoke) {
        await widget.onRevoke(_selectedOfficial!.profileId, borderId);
      }

      if (mounted) {
        Navigator.of(context).pop();

        // Call the onSaved callback to refresh parent data
        widget.onSaved?.call();

        // Only show snackbar if there were actual changes
        if (toAssign.isNotEmpty || toRevoke.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Updated ${toAssign.length + toRevoke.length} border assignment(s)'),
              backgroundColor: Colors.green,
            ),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    if (widget.borderOfficials.isEmpty) {
      return AlertDialog(
        title: const Text('No Border Officials'),
        content: const Text('No border officials available for assignment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Manage Border Assignments'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 600
            ? 500
            : MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Official selector
            DropdownButtonFormField<BorderOfficial>(
              value: _selectedOfficial,
              decoration: const InputDecoration(
                labelText: 'Select Border Official',
                border: OutlineInputBorder(),
              ),
              items: widget.borderOfficials.map((official) {
                return DropdownMenuItem<BorderOfficial>(
                  value: official,
                  child: Text(
                    '${official.fullName} (${official.email})',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (BorderOfficial? official) {
                setState(() {
                  _selectedOfficial = official;
                  _initializeBorderAssignments();
                });
              },
            ),
            const SizedBox(height: 20),

            // Border assignments header
            Text(
              'Border Access (${_borderAssignments.values.where((v) => v).length}/${widget.availableBorders.length} assigned)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Border checkboxes
            Expanded(
              child: widget.availableBorders.isEmpty
                  ? const Center(
                      child: Text(
                        'No borders available for this country.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: widget.availableBorders.length,
                      itemBuilder: (context, index) {
                        final border = widget.availableBorders[index];
                        final isAssigned =
                            _borderAssignments[border.id] ?? false;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: CheckboxListTile(
                            title: Text(
                              border.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            subtitle: Text(
                              'Type: ${border.borderTypeLabel ?? border.borderTypeId}',
                              style: TextStyle(color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            value: isAssigned,
                            onChanged: _isLoading
                                ? null
                                : (bool? value) {
                                    setState(() {
                                      _borderAssignments[border.id] =
                                          value ?? false;
                                    });
                                  },
                            activeColor: Colors.orange,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveBorderAssignments,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Save Changes',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
