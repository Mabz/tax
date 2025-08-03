import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../services/role_assignment_service.dart';
import '../services/role_service.dart';
import '../services/country_service.dart';
import '../models/country.dart';
import '../constants/app_constants.dart';

class ProfileDetailScreen extends StatefulWidget {
  final Profile profile;

  const ProfileDetailScreen({
    super.key,
    required this.profile,
  });

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  List<Map<String, dynamic>> _userRoles = [];
  List<Map<String, dynamic>> _availableRoles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadData();
  }

  Future<void> _checkPermissionsAndLoadData() async {
    try {
      final isSuperuser = await RoleService.isSuperuser();

      if (!isSuperuser) {
        if (mounted) {
          final navigator = Navigator.of(context);
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          navigator.pop();
          scaffoldMessenger.showSnackBar(
            const SnackBar(
                content: Text('Access denied: Superuser role required')),
          );
        }
        return;
      }

      // Permission check passed, continue

      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking permissions: $e')),
        );
      }
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final userRoles =
          await RoleAssignmentService.getUserRoles(widget.profile.id);
      final availableRoles = await RoleAssignmentService.getAllRoles();

      setState(() {
        _userRoles = userRoles;
        _availableRoles = availableRoles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _assignRole(String roleId, String? countryId) async {
    try {
      await RoleAssignmentService.assignRoleToUser(
        userId: widget.profile.id,
        roleId: roleId,
        countryId: countryId,
      );

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role assigned successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning role: $e')),
        );
      }
    }
  }

  Future<void> _removeRole(String profileRoleId) async {
    try {
      await RoleAssignmentService.removeRoleFromUser(profileRoleId);

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing role: $e')),
        );
      }
    }
  }

  Future<void> _updateRole({
    required String profileRoleId,
    String? countryId,
    DateTime? expiresAt,
    bool? isActive,
  }) async {
    try {
      await RoleAssignmentService.updateRoleAssignment(
        profileRoleId: profileRoleId,
        countryId: countryId,
        expiresAt: expiresAt,
        isActive: isActive,
      );

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating role: $e')),
        );
      }
    }
  }

  void _showEditRoleDialog(Map<String, dynamic> role) {
    showDialog(
      context: context,
      builder: (context) => _EditRoleDialog(
        role: role,
        onUpdate: _updateRole,
      ),
    );
  }

  void _showAssignRoleDialog() {
    showDialog(
      context: context,
      builder: (context) => _AssignRoleDialog(
        availableRoles: _availableRoles,
        onAssign: _assignRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Profile: ${widget.profile.fullName ?? 'Unknown'}'),
          backgroundColor: Colors.red.shade100,
          foregroundColor: Colors.red.shade800,
        ),
        body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Information Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Profile Information',
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow('Full Name',
                                    widget.profile.fullName ?? 'Not set'),
                                _buildInfoRow(
                                    'Email', widget.profile.email ?? 'Not set'),
                                _buildInfoRow(
                                    'Status',
                                    widget.profile.isActive
                                        ? 'Active'
                                        : 'Inactive'),
                                _buildInfoRow('Created',
                                    widget.profile.createdAt.toString()),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Roles Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Assigned Roles',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            ElevatedButton.icon(
                              onPressed: _showAssignRoleDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Assign Role'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        if (_userRoles.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.person_off,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No roles assigned',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          ..._userRoles.map((role) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: Icon(
                                      Icons.security,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  title: Text(role['roles']['display_name'] ??
                                      'Unknown Role'),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Role: ${role['roles']['name'] ?? 'Unknown'}'),
                                      if (role['countries'] != null)
                                        Text(
                                            'Country: ${role['countries']['name']} (${role['countries']['country_code']})'),
                                      if (role['expires_at'] != null)
                                        Text('Expires: ${role['expires_at']}'),
                                    ],
                                  ),
                                  trailing: role['roles']['name'] ==
                                          AppConstants.roleTraveller
                                      ? Tooltip(
                                          message:
                                              'Default role cannot be removed',
                                          child: Icon(
                                            Icons.lock,
                                            color: Colors.grey.shade400,
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  color: Colors.blue),
                                              onPressed: () =>
                                                  _showEditRoleDialog(role),
                                              tooltip: 'Edit Role',
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.remove_circle,
                                                  color: Colors.red),
                                              onPressed: () =>
                                                  _showRemoveRoleConfirmation(
                                                      role),
                                              tooltip: 'Remove Role',
                                            ),
                                          ],
                                        ),
                                  isThreeLine: true,
                                ),
                              )),
                      ],
                    ),
                  )));
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showRemoveRoleConfirmation(Map<String, dynamic> role) {
    final roleName = role['roles']['name'] as String?;
    final roleDisplayName = role['roles']['display_name'] as String?;

    // Check if this is the traveller role - cannot be removed
    if (roleName == AppConstants.roleTraveller) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Remove Role'),
          content: Text(
            'The "$roleDisplayName" role cannot be removed as it is a default role required for all users.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Show normal confirmation dialog for other roles
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Role'),
        content: Text(
          'Are you sure you want to remove the "$roleDisplayName" role from this user?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeRole(role['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _AssignRoleDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableRoles;
  final Future<void> Function(String roleId, String? countryId) onAssign;

  const _AssignRoleDialog({
    required this.availableRoles,
    required this.onAssign,
  });

  @override
  State<_AssignRoleDialog> createState() => _AssignRoleDialogState();
}

class _AssignRoleDialogState extends State<_AssignRoleDialog> {
  String? _selectedRoleId;
  String? _selectedCountryId;
  List<Country> _availableCountries = [];
  bool _isLoading = false;
  bool _isLoadingCountries = true;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await CountryService.getAllCountries();
      setState(() {
        _availableCountries =
            countries.where((country) => country.isActive).toList();
        _isLoadingCountries = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCountries = false;
      });
    }
  }

  bool _requiresCountry(String? roleId) {
    if (roleId == null) return false;
    final role = widget.availableRoles.firstWhere(
      (r) => r['id'] == roleId,
      orElse: () => <String, dynamic>{},
    );
    final roleName = role['name'] as String?;
    return roleName != null &&
        roleName != AppConstants.roleSuperuser &&
        roleName != AppConstants.roleTraveller;
  }

  bool _isSuperuserRole(String? roleId) {
    if (roleId == null) return false;
    final role = widget.availableRoles.firstWhere(
      (r) => r['id'] == roleId,
      orElse: () => <String, dynamic>{},
    );
    final roleName = role['name'] as String?;
    return roleName == AppConstants.roleSuperuser;
  }

  void _autoAssignGlobalCountry() {
    // Find the Global country (country_code = 'ALL', is_global = true)
    final globalCountry = _availableCountries.firstWhere(
      (country) => country.countryCode == 'ALL',
      orElse: () => Country(
        id: '',
        name: '',
        countryCode: '',
        revenueServiceName: '',
        isActive: false,
        isGlobal: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (globalCountry.id.isNotEmpty) {
      setState(() {
        _selectedCountryId = globalCountry.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Role'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Select Role',
              border: OutlineInputBorder(),
            ),
            value: _selectedRoleId,
            items: widget.availableRoles
                .where((role) => role['name'] != AppConstants.roleTraveller)
                .map((role) {
              return DropdownMenuItem<String>(
                value: role['id'],
                child: Text(role['display_name'] ?? role['name']),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRoleId = value;
                // Reset country selection when role changes
                if (!_requiresCountry(value)) {
                  _selectedCountryId = null;
                }
                // Auto-assign Global country for superuser role
                if (_isSuperuserRole(value)) {
                  _autoAssignGlobalCountry();
                }
              });
            },
          ),
          const SizedBox(height: 16),
          // Country selection for country-specific roles
          if (_requiresCountry(_selectedRoleId)) ...[
            if (_isLoadingCountries)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Country',
                  border: OutlineInputBorder(),
                ),
                value: _selectedCountryId,
                items: _availableCountries.map((country) {
                  return DropdownMenuItem<String>(
                    value: country.id,
                    child: Text('${country.name} (${country.countryCode})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCountryId = value;
                  });
                },
                validator: (value) {
                  if (_requiresCountry(_selectedRoleId) && value == null) {
                    return 'Please select a country for this role';
                  }
                  return null;
                },
              ),
            const SizedBox(height: 8),
            Text(
              'This role requires country assignment',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ] else if (_isSuperuserRole(_selectedRoleId)) ...[
            if (_isLoadingCountries)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Global Country Assignment',
                  border: OutlineInputBorder(),
                ),
                value: _selectedCountryId,
                items: _availableCountries
                    .where((country) => country.countryCode == 'ALL')
                    .map((country) {
                  return DropdownMenuItem<String>(
                    value: country.id,
                    child: Text('${country.name} (${country.countryCode})'),
                  );
                }).toList(),
                onChanged: null, // Disabled - auto-assigned
              ),
            const SizedBox(height: 8),
            Text(
              'Superuser role is automatically assigned to Global country',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
            ),
          ] else ...[
            Text(
              'This role is global (no country required)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ||
                  _selectedRoleId == null ||
                  (_requiresCountry(_selectedRoleId) &&
                      _selectedCountryId == null) ||
                  (_isSuperuserRole(_selectedRoleId) &&
                      _selectedCountryId == null)
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  final navigator = Navigator.of(context);
                  try {
                    await widget.onAssign(_selectedRoleId!, _selectedCountryId);
                    if (mounted) navigator.pop();
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Assign'),
        ),
      ],
    );
  }
}

class _EditRoleDialog extends StatefulWidget {
  final Map<String, dynamic> role;
  final Future<void> Function({
    required String profileRoleId,
    String? countryId,
    DateTime? expiresAt,
    bool? isActive,
  }) onUpdate;

  const _EditRoleDialog({
    required this.role,
    required this.onUpdate,
  });

  @override
  State<_EditRoleDialog> createState() => _EditRoleDialogState();
}

class _EditRoleDialogState extends State<_EditRoleDialog> {
  String? _selectedCountryId;
  DateTime? _selectedExpiresAt;
  bool _isActive = true;
  List<Country> _availableCountries = [];
  bool _isLoading = false;
  bool _isLoadingCountries = true;

  @override
  void initState() {
    super.initState();
    _initializeValues();
    _loadCountries();
  }

  void _initializeValues() {
    // Initialize with current values
    _selectedCountryId = widget.role['country_id'];
    _isActive = widget.role['is_active'] ?? true;

    // Parse expiration date if exists
    if (widget.role['expires_at'] != null) {
      try {
        _selectedExpiresAt = DateTime.parse(widget.role['expires_at']);
      } catch (e) {
        // If parsing fails, leave as null
      }
    }
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await CountryService.getAllCountries();
      setState(() {
        _availableCountries =
            countries.where((country) => country.isActive).toList();
        _isLoadingCountries = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCountries = false;
      });
    }
  }

  bool _requiresCountry() {
    final roleName = widget.role['roles']['name'] as String?;
    return roleName != null &&
        roleName != AppConstants.roleSuperuser &&
        roleName != AppConstants.roleTraveller;
  }

  Future<void> _selectExpirationDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedExpiresAt ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 years
    );
    if (picked != null) {
      setState(() {
        _selectedExpiresAt = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleName = widget.role['roles']['display_name'] ?? 'Unknown Role';

    return AlertDialog(
      title: Text('Edit Role: $roleName'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Role Status
            SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text('Enable or disable this role assignment'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Country selection for country-specific roles
            if (_requiresCountry()) ...[
              const Text(
                'Country Assignment',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_isLoadingCountries)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Country',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCountryId,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No Country (Global)'),
                    ),
                    ..._availableCountries.map((country) {
                      return DropdownMenuItem<String>(
                        value: country.id,
                        child: Text('${country.name} (${country.countryCode})'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCountryId = value;
                    });
                  },
                ),
              const SizedBox(height: 16),
            ] else ...[
              Text(
                'This role is global (no country assignment)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
            ],

            // Expiration Date
            const Text(
              'Expiration Date',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedExpiresAt != null
                        ? 'Expires: ${_selectedExpiresAt!.toLocal().toString().split(' ')[0]}'
                        : 'No expiration date set',
                    style: TextStyle(
                      color: _selectedExpiresAt != null
                          ? Colors.black
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _selectExpirationDate,
                  child: const Text('Select Date'),
                ),
                if (_selectedExpiresAt != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedExpiresAt = null;
                      });
                    },
                    child: const Text('Clear'),
                  ),
              ],
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
          onPressed: _isLoading
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  final navigator = Navigator.of(context);
                  try {
                    await widget.onUpdate(
                      profileRoleId: widget.role['id'],
                      countryId: _selectedCountryId,
                      expiresAt: _selectedExpiresAt,
                      isActive: _isActive,
                    );
                    if (mounted) navigator.pop();
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}
