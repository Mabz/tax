import 'package:flutter/material.dart';
import '../models/border_official.dart';
import '../services/border_official_service.dart';
import '../services/enhanced_border_service.dart';
import '../widgets/enhanced_border_assignment_dialog.dart';
import '../widgets/profile_image_widget.dart';

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

  String get _countryId => widget.selectedCountry['id'] as String;
  String get _countryName => widget.selectedCountry['name'] as String;
  String get _authorityId => widget.selectedCountry['authority_id'] as String;
  String get _authorityName =>
      widget.selectedCountry['authority_name'] as String;

  @override
  void initState() {
    super.initState();
    _loadAuthorityData();
  }

  Future<void> _loadAuthorityData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final borderOfficials =
          await BorderOfficialService.getBorderOfficialsForAuthority(
              _authorityId);

      setState(() {
        _borderOfficials = borderOfficials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load border officials: $e';
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
        await _loadAuthorityData();
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
      builder: (context) => EnhancedBorderAssignmentDialog(
        borderOfficials: _borderOfficials,
        countryId: _countryId,
        onSaved: _loadAuthorityData,
      ),
    );
  }

  void _showBorderAssignmentDialogForOfficial(BorderOfficial official) async {
    showDialog(
      context: context,
      builder: (context) => EnhancedBorderAssignmentDialog(
        borderOfficials: _borderOfficials,
        countryId: _countryId,
        selectedOfficial: official,
        onSaved: _loadAuthorityData,
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
              onPressed: _loadAuthorityData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildAuthorityHeader(),
        const SizedBox(height: 16),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildAuthorityHeader() {
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
            Icons.business,
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
                  _authorityName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _countryName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade600,
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
                  leading: ProfileImageWidget(
                    currentImageUrl: official.profileImageUrl,
                    size: 40,
                    isEditable: false,
                  ),
                  title: Text(
                    official.displayName ?? official.fullName,
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
                  trailing: IconButton(
                    onPressed: () =>
                        _showBorderAssignmentDialogForOfficial(official),
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'Edit border assignments',
                    padding: const EdgeInsets.all(4),
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Assigned Borders:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildOfficialAssignedBorders(official),
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
    return FutureBuilder<List<BorderAssignmentWithPermissions>>(
      future:
          EnhancedBorderService.getBorderAssignmentsWithPermissionsByAuthority(
              _authorityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.orange),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading assignments: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final enhancedAssignments = snapshot.data ?? [];

        if (enhancedAssignments.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_late_outlined,
                    size: 64, color: Colors.grey),
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
          itemCount: enhancedAssignments.length,
          itemBuilder: (context, index) {
            final assignment = enhancedAssignments[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.orange.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            assignment.borderName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline,
                              color: Colors.red.shade600),
                          onPressed: () =>
                              _showEnhancedRevokeConfirmation(assignment),
                          tooltip: 'Revoke Assignment',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ProfileImageWidget(
                          currentImageUrl: assignment.officialProfileImageUrl,
                          size: 16,
                          isEditable: false,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            assignment.officialDisplayName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.email,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            assignment.officialEmail,
                            style: TextStyle(color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Permissions: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        _buildPermissionChip(
                          'Check-In',
                          assignment.canCheckIn,
                          Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _buildPermissionChip(
                          'Check-Out',
                          assignment.canCheckOut,
                          Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Assigned: ${assignment.assignedAt.toString().split(' ')[0]}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEnhancedRevokeConfirmation(
      BorderAssignmentWithPermissions assignment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Assignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to revoke ${assignment.officialDisplayName} from ${assignment.borderName}?',
            ),
            const SizedBox(height: 12),
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
                    'Current Permissions:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(assignment.permissionsDescription),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await EnhancedBorderService.revokeOfficialFromBorder(
                  assignment.profileId,
                  assignment.borderId,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Border official revoked successfully'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  setState(() {}); // Refresh the FutureBuilder
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
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionChip(String label, bool hasPermission, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasPermission
            ? color.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasPermission
              ? color.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasPermission ? Icons.check : Icons.close,
            size: 12,
            color: hasPermission ? color : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: hasPermission ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialAssignedBorders(BorderOfficial official) {
    if (official.assignedBordersList.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.grey.shade600,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'No borders assigned',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<BorderAssignmentWithPermissions>>(
      future:
          EnhancedBorderService.getBorderAssignmentsWithPermissionsByAuthority(
              _authorityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.orange,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          // Fallback to simple border names if detailed data fails
          return Wrap(
            spacing: 8,
            runSpacing: 4,
            children: official.assignedBordersList.map((borderName) {
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
          );
        }

        // Filter assignments for this specific official
        final officialAssignments = snapshot.data!
            .where((assignment) => assignment.profileId == official.profileId)
            .toList();

        if (officialAssignments.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.grey.shade600,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'No borders assigned',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: officialAssignments.map((assignment) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          assignment.borderName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.orange.shade800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Permissions: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      _buildPermissionChip(
                        'Check-In',
                        assignment.canCheckIn,
                        Colors.green,
                      ),
                      const SizedBox(width: 6),
                      _buildPermissionChip(
                        'Check-Out',
                        assignment.canCheckOut,
                        Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
