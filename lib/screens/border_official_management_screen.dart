import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
    return FutureBuilder<List<BorderAssignmentWithLocation>>(
      future: EnhancedBorderService.getBorderAssignmentsWithLocationByAuthority(
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
                  'No border assignments found for this authority.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Group assignments by border
        final Map<String, List<BorderAssignmentWithLocation>> borderGroups = {};
        for (final assignment in enhancedAssignments) {
          if (!borderGroups.containsKey(assignment.borderName)) {
            borderGroups[assignment.borderName] = [];
          }
          borderGroups[assignment.borderName]!.add(assignment);
        }

        // Sort border names
        final sortedBorderNames = borderGroups.keys.toList()..sort();

        return Column(
          children: [
            // Header with statistics
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.assignment_ind,
                      color: Colors.orange.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Border Official Assignments',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${borderGroups.length} borders • ${enhancedAssignments.length} total assignments',
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
            ),
            // Borders list grouped by border
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sortedBorderNames.length,
                itemBuilder: (context, index) {
                  final borderName = sortedBorderNames[index];
                  final borderAssignments = borderGroups[borderName]!;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Border header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Map preview
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: borderAssignments.isNotEmpty &&
                                          borderAssignments
                                                  .first.borderLatitude !=
                                              null &&
                                          borderAssignments
                                                  .first.borderLongitude !=
                                              null
                                      ? GoogleMap(
                                          initialCameraPosition: CameraPosition(
                                            target: LatLng(
                                              borderAssignments
                                                  .first.borderLatitude!,
                                              borderAssignments
                                                  .first.borderLongitude!,
                                            ),
                                            zoom: 12,
                                          ),
                                          style: '''
                                            [
                                              {
                                                "featureType": "all",
                                                "elementType": "labels",
                                                "stylers": [
                                                  {
                                                    "visibility": "simplified"
                                                  }
                                                ]
                                              }
                                            ]
                                            ''',
                                          markers: {
                                            Marker(
                                              markerId: MarkerId(
                                                  'border_${borderAssignments.first.borderId}'),
                                              position: LatLng(
                                                borderAssignments
                                                    .first.borderLatitude!,
                                                borderAssignments
                                                    .first.borderLongitude!,
                                              ),
                                              icon: BitmapDescriptor
                                                  .defaultMarkerWithHue(
                                                BitmapDescriptor.hueOrange,
                                              ),
                                            ),
                                          },
                                          mapType: MapType.normal,
                                          myLocationButtonEnabled: false,
                                          zoomControlsEnabled: false,
                                          mapToolbarEnabled: false,
                                          compassEnabled: false,
                                          scrollGesturesEnabled: false,
                                          zoomGesturesEnabled: false,
                                          tiltGesturesEnabled: false,
                                          rotateGesturesEnabled: false,
                                          indoorViewEnabled: false,
                                          trafficEnabled: false,
                                          buildingsEnabled: false,
                                          liteModeEnabled: true,
                                          fortyFiveDegreeImageryEnabled: false,
                                        )
                                      : Container(
                                          color: Colors.grey.shade200,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.map_outlined,
                                                color: Colors.grey.shade500,
                                                size: 20,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'No Location',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Border info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            borderName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (borderAssignments.isNotEmpty &&
                                            borderAssignments
                                                    .first.borderType !=
                                                null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: Colors.blue.shade200),
                                            ),
                                            child: Text(
                                              borderAssignments
                                                  .first.borderType!,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (borderAssignments.isNotEmpty &&
                                        borderAssignments
                                                .first.borderDescription !=
                                            null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        borderAssignments
                                            .first.borderDescription!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: borderAssignments.isEmpty
                                            ? Colors.red.shade50
                                            : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: borderAssignments.isEmpty
                                              ? Colors.red.shade200
                                              : Colors.green.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        borderAssignments.isEmpty
                                            ? 'No officials assigned'
                                            : '${borderAssignments.length} official${borderAssignments.length == 1 ? '' : 's'} assigned',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: borderAssignments.isEmpty
                                              ? Colors.red.shade700
                                              : Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Assigned officials section
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assigned Border Officials',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Grid layout for officials (2 columns)
                              _buildOfficialsGrid(borderAssignments),
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
      },
    );
  }

  void _showEnhancedRevokeConfirmation(
      BorderAssignmentWithLocation assignment) {
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildOfficialsGrid(List<BorderAssignmentWithLocation> assignments) {
    if (assignments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No officials assigned',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    'This border currently has no assigned officials',
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

    // Create a grid with 2 columns
    final List<Widget> rows = [];
    for (int i = 0; i < assignments.length; i += 2) {
      final List<Widget> rowChildren = [];

      // First official in the row
      rowChildren.add(
        Expanded(
          child: _buildOfficialCard(assignments[i]),
        ),
      );

      // Second official in the row (if exists)
      if (i + 1 < assignments.length) {
        rowChildren.add(const SizedBox(width: 12));
        rowChildren.add(
          Expanded(
            child: _buildOfficialCard(assignments[i + 1]),
          ),
        );
      } else {
        // Add empty space if odd number of officials
        rowChildren.add(const SizedBox(width: 12));
        rowChildren.add(const Expanded(child: SizedBox()));
      }

      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowChildren,
        ),
      );

      // Add spacing between rows
      if (i + 2 < assignments.length) {
        rows.add(const SizedBox(height: 12));
      }
    }

    return Column(children: rows);
  }

  Widget _buildOfficialCard(BorderAssignmentWithLocation assignment) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Official info row
          Row(
            children: [
              ProfileImageWidget(
                currentImageUrl: assignment.officialProfileImageUrl,
                size: 32,
                isEditable: false,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.officialDisplayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      assignment.officialEmail,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Actions
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red.shade600,
                  size: 18,
                ),
                onPressed: () => _showEnhancedRevokeConfirmation(assignment),
                tooltip: 'Revoke Assignment',
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Permissions row
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildPermissionChip(
                      'In',
                      assignment.canCheckIn,
                      Colors.green,
                    ),
                    const SizedBox(width: 4),
                    _buildPermissionChip(
                      'Out',
                      assignment.canCheckOut,
                      Colors.blue,
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(assignment.assignedAt),
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
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
