import 'package:flutter/material.dart';
import '../models/border_official.dart';
import '../models/border.dart' as border_model;
import '../services/border_manager_service.dart';
import '../widgets/profile_image_widget.dart';

class BorderManagerBorderOfficialScreen extends StatefulWidget {
  const BorderManagerBorderOfficialScreen({super.key});

  @override
  State<BorderManagerBorderOfficialScreen> createState() =>
      _BorderManagerBorderOfficialScreenState();
}

class _BorderManagerBorderOfficialScreenState
    extends State<BorderManagerBorderOfficialScreen> {
  bool _isLoading = true;
  String? _error;
  List<border_model.Border> _assignedBorders = [];
  border_model.Border? _selectedBorder;
  List<BorderOfficialWithPermissions> _borderOfficials = [];

  @override
  void initState() {
    super.initState();
    // Add a small delay to ensure the widget is fully built before loading data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAssignedBorders();
    });
  }

  Future<void> _loadAssignedBorders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      debugPrint('🔄 Loading assigned borders for current manager...');
      final borders =
          await BorderManagerService.getAssignedBordersForCurrentManager();

      debugPrint('🔄 Found ${borders.length} assigned borders');
      for (var border in borders) {
        debugPrint('   - ${border.name} (${border.id})');
      }

      setState(() {
        _assignedBorders = borders;
        _selectedBorder = borders.isNotEmpty ? borders.first : null;
        _isLoading = false;
      });

      if (_selectedBorder != null) {
        debugPrint('🔄 Loading officials for border: ${_selectedBorder!.name}');
        _loadBorderOfficials();
      } else {
        debugPrint('🔄 No borders assigned to current manager');
      }
    } catch (e) {
      debugPrint('🔄 Error loading assigned borders: $e');
      setState(() {
        _error = 'Failed to load assigned borders: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBorderOfficials() async {
    if (_selectedBorder == null) return;

    try {
      debugPrint(
          '🔄 Loading border officials for border: ${_selectedBorder!.id}');
      final officials = await BorderManagerService.getBorderOfficialsForBorder(
        _selectedBorder!.id,
      );

      debugPrint('🔄 Found ${officials.length} border officials');
      for (var official in officials) {
        debugPrint('   - ${official.fullName} (${official.email})');
      }

      setState(() {
        _borderOfficials = officials;
      });
    } catch (e) {
      debugPrint('🔄 Error loading border officials: $e');
      setState(() {
        _error = 'Failed to load border officials: $e';
      });
    }
  }

  void _showAssignOfficialDialog() async {
    if (_selectedBorder == null) return;

    // Get available border officials for the authority
    try {
      final availableOfficials =
          await BorderManagerService.getAvailableBorderOfficialsForBorder(
              _selectedBorder!.id);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => _AssignOfficialDialog(
          border: _selectedBorder!,
          availableOfficials: availableOfficials,
          onAssigned: _loadBorderOfficials,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load available officials: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditPermissionsDialog(BorderOfficialWithPermissions official) {
    showDialog(
      context: context,
      builder: (context) => _EditPermissionsDialog(
        official: official,
        border: _selectedBorder!,
        onUpdated: _loadBorderOfficials,
      ),
    );
  }

  Future<void> _removePermission(BorderOfficialWithPermissions official,
      {bool removeCheckIn = false, bool removeCheckOut = false}) async {
    if (_selectedBorder == null) return;

    try {
      bool newCanCheckIn = official.canCheckIn;
      bool newCanCheckOut = official.canCheckOut;

      if (removeCheckIn) newCanCheckIn = false;
      if (removeCheckOut) newCanCheckOut = false;

      // Update permissions in database
      await BorderManagerService.supabase
          .from('border_official_borders')
          .update({
            'can_check_in': newCanCheckIn,
            'can_check_out': newCanCheckOut,
          })
          .eq('profile_id', official.profileId)
          .eq('border_id', _selectedBorder!.id);

      if (mounted) {
        String action = removeCheckIn
            ? 'Check In access removed'
            : 'Check Out access removed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$action for ${official.fullName}'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadBorderOfficials();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update permissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _revokeOfficial(BorderOfficialWithPermissions official) async {
    if (_selectedBorder == null) return;

    try {
      await BorderManagerService.revokeOfficialFromBorderAsManager(
        official.profileId,
        _selectedBorder!.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Border official revoked successfully'),
            backgroundColor: Colors.purple,
          ),
        );
        _loadBorderOfficials();
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

  @override
  Widget build(BuildContext context) {
    // Handle loading and error states with full scaffold
    if (_isLoading || _error != null || _assignedBorders.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manage Border Officials'),
          backgroundColor: Colors.purple.shade700,
          foregroundColor: Colors.white,
        ),
        body: _buildBody(),
      );
    }

    // Normal state with actions
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Border Officials'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedBorder != null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _showAssignOfficialDialog,
              tooltip: 'Assign Border Official',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.purple),
              SizedBox(height: 16),
              Text('Loading your assigned borders...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Data',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadAssignedBorders,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_assignedBorders.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'No borders assigned to you',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You need to be assigned to borders as a Border Manager to manage border officials.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Contact your administrator to get assigned to borders.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadAssignedBorders,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          _buildBorderSelector(),
          Expanded(child: _buildOfficialsList()),
        ],
      ),
    );
  }

  Widget _buildBorderSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.purple.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Border to Manage:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.purple.shade800,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<border_model.Border>(
            value: _selectedBorder,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.purple.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
              ),
              prefixIcon:
                  Icon(Icons.location_on, color: Colors.purple.shade600),
            ),
            items: _assignedBorders.map((border) {
              return DropdownMenuItem(
                value: border,
                child: Text(
                  border.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              );
            }).toList(),
            onChanged: (border) {
              setState(() {
                _selectedBorder = border;
              });
              if (border != null) {
                _loadBorderOfficials();
              }
            },
          ),
          if (_selectedBorder?.description != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Text(
                _selectedBorder!.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.purple.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfficialsList() {
    if (_selectedBorder == null) {
      return const Center(
        child: Text('Please select a border to manage'),
      );
    }

    if (_borderOfficials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No border officials assigned to ${_selectedBorder!.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Assign border officials to manage this border.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAssignOfficialDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Assign Border Official'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.purple.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_borderOfficials.length} Border Officials assigned to ${_selectedBorder!.name}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showAssignOfficialDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Assign Official'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // Check In Section
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border(
                          bottom: BorderSide(
                              color: Colors.green.shade200, width: 2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.login,
                              color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Check In Officials',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade700,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_borderOfficials.where((o) => o.canCheckIn).length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildOfficialsSection(checkInOnly: true),
                    ),
                  ],
                ),
              ),

              // Divider
              Container(
                width: 1,
                color: Colors.grey.shade300,
              ),

              // Check Out Section
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border(
                          bottom:
                              BorderSide(color: Colors.red.shade200, width: 2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.logout,
                              color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Check Out Officials',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_borderOfficials.where((o) => o.canCheckOut).length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildOfficialsSection(checkOutOnly: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOfficialsSection(
      {bool checkInOnly = false, bool checkOutOnly = false}) {
    List<BorderOfficialWithPermissions> filteredOfficials = _borderOfficials;

    if (checkInOnly) {
      filteredOfficials = _borderOfficials.where((o) => o.canCheckIn).toList();
    } else if (checkOutOnly) {
      filteredOfficials = _borderOfficials.where((o) => o.canCheckOut).toList();
    }

    if (filteredOfficials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              checkInOnly ? Icons.login : Icons.logout,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              checkInOnly
                  ? 'No officials assigned for Check In'
                  : 'No officials assigned for Check Out',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Assign officials with the appropriate permissions.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredOfficials.length,
      itemBuilder: (context, index) {
        final official = filteredOfficials[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: ProfileImageWidget(
              currentImageUrl: official.profileImageUrl,
              size: 40,
              isEditable: false,
            ),
            title: Text(
              official.fullName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(official.email),
            trailing: PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) {
                List<PopupMenuEntry> items = [
                  PopupMenuItem(
                    value: 'edit',
                    child: const Row(
                      children: [
                        Icon(Icons.edit, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('Edit Permissions'),
                      ],
                    ),
                  ),
                ];

                // Smart revoke options based on current permissions
                if (official.canCheckIn && official.canCheckOut) {
                  // Has both permissions - offer individual removal or full revoke
                  items.addAll([
                    PopupMenuItem(
                      value: 'remove_checkin',
                      child: const Row(
                        children: [
                          Icon(Icons.login, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Remove Check In'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove_checkout',
                      child: const Row(
                        children: [
                          Icon(Icons.logout, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Remove Check Out'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'revoke_all',
                      child: const Row(
                        children: [
                          Icon(Icons.remove_circle_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Revoke All Access'),
                        ],
                      ),
                    ),
                  ]);
                } else {
                  // Has only one permission - direct revoke (will show confirmation)
                  items.add(
                    PopupMenuItem(
                      value: 'revoke_all',
                      child: const Row(
                        children: [
                          Icon(Icons.remove_circle_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Revoke Access'),
                        ],
                      ),
                    ),
                  );
                }

                return items;
              },
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditPermissionsDialog(official);
                } else if (value == 'remove_checkin') {
                  _removePermission(official, removeCheckIn: true);
                } else if (value == 'remove_checkout') {
                  _removePermission(official, removeCheckOut: true);
                } else if (value == 'revoke_all') {
                  _showRevokeConfirmation(official);
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _showRevokeConfirmation(BorderOfficialWithPermissions official) {
    // Determine what permissions will be revoked
    List<String> permissions = [];
    if (official.canCheckIn) permissions.add('Check In');
    if (official.canCheckOut) permissions.add('Check Out');

    String permissionText = permissions.join(' and ');
    bool isFullRevoke = permissions.length > 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFullRevoke ? 'Revoke All Access' : 'Revoke Access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to revoke ${official.fullName}\'s access to ${_selectedBorder!.name}?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'This will remove:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• $permissionText permissions',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                  if (isFullRevoke)
                    Text(
                      '• Complete access to this border',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
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
            onPressed: () {
              Navigator.of(context).pop();
              _revokeOfficial(official);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              isFullRevoke ? 'Revoke All' : 'Revoke',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignOfficialDialog extends StatefulWidget {
  final border_model.Border border;
  final List<BorderOfficial> availableOfficials;
  final VoidCallback onAssigned;

  const _AssignOfficialDialog({
    required this.border,
    required this.availableOfficials,
    required this.onAssigned,
  });

  @override
  State<_AssignOfficialDialog> createState() => _AssignOfficialDialogState();
}

class _AssignOfficialDialogState extends State<_AssignOfficialDialog> {
  BorderOfficial? _selectedOfficial;
  bool _canCheckIn = true;
  bool _canCheckOut = true;
  bool _isAssigning = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign Official to ${widget.border.name}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Border Official:'),
            const SizedBox(height: 8),
            DropdownButtonFormField<BorderOfficial>(
              value: _selectedOfficial,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Choose an official...',
              ),
              items: widget.availableOfficials.map((official) {
                return DropdownMenuItem(
                  value: official,
                  child: Text(
                    official.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (official) {
                setState(() {
                  _selectedOfficial = official;
                });
              },
            ),
            if (_selectedOfficial != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  children: [
                    ProfileImageWidget(
                      currentImageUrl: _selectedOfficial!.profileImageUrl,
                      size: 32,
                      isEditable: false,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedOfficial!.fullName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                          Text(
                            _selectedOfficial!.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Permissions:'),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Can Check In'),
              subtitle: const Text('Allow processing vehicle entries'),
              value: _canCheckIn,
              onChanged: (value) {
                setState(() {
                  _canCheckIn = value ?? true;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Can Check Out'),
              subtitle: const Text('Allow processing vehicle exits'),
              value: _canCheckOut,
              onChanged: (value) {
                setState(() {
                  _canCheckOut = value ?? true;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isAssigning ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isAssigning || _selectedOfficial == null
              ? null
              : _assignOfficial,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          child: _isAssigning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Assign', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _assignOfficial() async {
    if (_selectedOfficial == null) return;

    setState(() {
      _isAssigning = true;
    });

    try {
      await BorderManagerService.assignOfficialToBorderAsManager(
        _selectedOfficial!.profileId,
        widget.border.id,
        canCheckIn: _canCheckIn,
        canCheckOut: _canCheckOut,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully assigned ${_selectedOfficial!.fullName} to ${widget.border.name}',
            ),
            backgroundColor: Colors.purple,
          ),
        );
        widget.onAssigned();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAssigning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign official: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _EditPermissionsDialog extends StatefulWidget {
  final BorderOfficialWithPermissions official;
  final border_model.Border border;
  final VoidCallback onUpdated;

  const _EditPermissionsDialog({
    required this.official,
    required this.border,
    required this.onUpdated,
  });

  @override
  State<_EditPermissionsDialog> createState() => _EditPermissionsDialogState();
}

class _EditPermissionsDialogState extends State<_EditPermissionsDialog> {
  bool _canCheckIn = true;
  bool _canCheckOut = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _canCheckIn = widget.official.canCheckIn;
    _canCheckOut = widget.official.canCheckOut;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Permissions - ${widget.official.fullName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Border: ${widget.border.name}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          const Text('Permissions:'),
          const SizedBox(height: 8),
          CheckboxListTile(
            title: const Text('Can Check In'),
            subtitle: const Text('Allow processing vehicle entries'),
            value: _canCheckIn,
            onChanged: (value) {
              setState(() {
                _canCheckIn = value ?? false;
              });
            },
            activeColor: Colors.purple,
          ),
          CheckboxListTile(
            title: const Text('Can Check Out'),
            subtitle: const Text('Allow processing vehicle exits'),
            value: _canCheckOut,
            onChanged: (value) {
              setState(() {
                _canCheckOut = value ?? false;
              });
            },
            activeColor: Colors.purple,
          ),
          if (!_canCheckIn && !_canCheckOut)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Official must have at least one permission',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUpdating || (!_canCheckIn && !_canCheckOut)
              ? null
              : _updatePermissions,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          child: _isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Update', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _updatePermissions() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      // Update permissions in database
      await BorderManagerService.supabase
          .from('border_official_borders')
          .update({
            'can_check_in': _canCheckIn,
            'can_check_out': _canCheckOut,
          })
          .eq('profile_id', widget.official.profileId)
          .eq('border_id', widget.border.id);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully updated permissions for ${widget.official.fullName}',
            ),
            backgroundColor: Colors.purple,
          ),
        );
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update permissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
