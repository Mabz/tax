import 'package:flutter/material.dart';
import 'package:flutter_supabase_auth/services/invitation_service.dart';
import '../models/profile.dart';
import '../services/country_user_service.dart';
import '../constants/app_constants.dart';
import '../utils/role_colors.dart';

/// Screen for country administrators to manage users in their country
class CountryUserManagementScreen extends StatefulWidget {
  final Map<String, dynamic> selectedCountry;

  const CountryUserManagementScreen({
    super.key,
    required this.selectedCountry,
  });

  @override
  State<CountryUserManagementScreen> createState() =>
      _CountryUserManagementScreenState();
}

class _CountryUserManagementScreenState
    extends State<CountryUserManagementScreen> {
  bool _isLoading = true;
  List<CountryUserProfile> _users = [];
  List<CountryUserProfile> _filteredUsers = [];
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  // Helper getter to extract authority information from selectedCountry
  String get _authorityName {
    return widget.selectedCountry['authority_name'] as String? ??
        widget.selectedCountry['name'] as String;
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          final name = user.fullName?.toLowerCase() ?? '';
          final email = user.email?.toLowerCase() ?? '';
          final roles = user.roles.toLowerCase();
          return name.contains(query) ||
              email.contains(query) ||
              roles.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check permissions first
      final canManage = await CountryUserService.canManageCountryUsers(
        widget.selectedCountry['id'] as String,
      );

      if (!canManage) {
        setState(() {
          _errorMessage =
              'Access denied. Country admin role required for this country.';
          _isLoading = false;
        });
        return;
      }

      // Load users for this authority
      final users = await CountryUserService.getProfilesByAuthority(
        widget.selectedCountry['authority_id'] as String,
      );

      if (mounted) {
        setState(() {
          _users = users;
          _filteredUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading users: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading users: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showUserRoles(CountryUserProfile user) async {
    final profile = await CountryUserService.getProfileDetails(user.profileId);
    if (profile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading user details')),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => _UserRoleManagementDialog(
          profile: profile,
          authorityId: widget.selectedCountry['authority_id'] as String,
          authorityName: _authorityName,
          onRoleChanged: _loadUsers,
        ),
      );
    }
  }

  Future<void> _showInviteDialog() async {
    showDialog(
      context: context,
      builder: (context) => _InviteUserDialog(
        authorityId: widget.selectedCountry['authority_id'] as String,
        authorityName: _authorityName,
        onInviteSent: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invitation sent successfully')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: Colors.orange.shade100,
        foregroundColor: Colors.orange.shade800,
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Authority header - fixed below app bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(
                bottom: BorderSide(
                  color: Colors.orange.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _authorityName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_users.length} user(s) assigned',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Content area - scrollable
          Expanded(
            child: SafeArea(
              top: false, // Don't add safe area at top since we have the header
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Access Error',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Colors.red.shade700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _users.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Users Found',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Colors.grey.shade600,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No users have been assigned roles in this authority yet.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.grey.shade500,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _showInviteDialog,
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Invite User'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade600,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                // Modern search bar with better spacing
                                Container(
                                  margin: const EdgeInsets.all(20),
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText:
                                          'Search users by name, email, or role...',
                                      hintStyle: TextStyle(
                                          color: Colors.grey.shade500),
                                      prefixIcon: Icon(
                                        Icons.search_rounded,
                                        color: Colors.grey.shade600,
                                      ),
                                      suffixIcon:
                                          _searchController.text.isNotEmpty
                                              ? IconButton(
                                                  icon: Icon(
                                                    Icons.clear_rounded,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  onPressed: () {
                                                    _searchController.clear();
                                                  },
                                                )
                                              : null,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                            color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                            color: Colors.orange.shade400,
                                            width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                ),

                                // User list
                                Expanded(
                                  child: _filteredUsers.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.search_off,
                                                size: 64,
                                                color: Colors.grey.shade400,
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'No Results Found',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Try adjusting your search terms.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color:
                                                          Colors.grey.shade500,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : RefreshIndicator(
                                          onRefresh: _loadUsers,
                                          child: ListView.builder(
                                            padding: const EdgeInsets.only(
                                                bottom: 20),
                                            itemCount: _filteredUsers.length,
                                            itemBuilder: (context, index) {
                                              return _buildUserCard(
                                                  _filteredUsers[index]);
                                            },
                                          ),
                                        ),
                                ),
                              ],
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(CountryUserProfile user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showUserRoles(user),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with avatar and status
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: user.anyActive
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [Colors.grey.shade400, Colors.grey.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName ?? 'Unknown User',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          if (user.email != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              user.email!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: user.anyActive
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: user.anyActive
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: user.anyActive
                                  ? Colors.green.shade500
                                  : Colors.red.shade500,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            user.anyActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: user.anyActive
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Roles section with color coding
                if (user.roles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Roles',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: user.roles.split(', ').map((role) {
                      return _buildRoleChip(role.trim());
                    }).toList(),
                  ),
                ],

                // Last assigned info
                if (user.latestAssignedAt != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Last assigned: ${_formatDate(user.latestAssignedAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    return RoleColors.buildRoleChip(role);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Dialog for managing user roles within a country
class _UserRoleManagementDialog extends StatefulWidget {
  final Profile profile;
  final String authorityId;
  final String authorityName;
  final VoidCallback onRoleChanged;

  const _UserRoleManagementDialog({
    required this.profile,
    required this.authorityId,
    required this.authorityName,
    required this.onRoleChanged,
  });

  @override
  State<_UserRoleManagementDialog> createState() =>
      _UserRoleManagementDialogState();
}

class _UserRoleManagementDialogState extends State<_UserRoleManagementDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _userRoles = [];
  List<Map<String, dynamic>> _availableRoles = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userRoles = await CountryUserService.getUserRolesInAuthority(
        widget.profile.id,
        widget.authorityId,
      );
      final availableRoles = await CountryUserService.getAssignableRoles();

      if (mounted) {
        setState(() {
          _userRoles = userRoles;
          _availableRoles = availableRoles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _removeRole(String profileRoleId, String roleName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Role'),
        content: Text(
            'Are you sure you want to remove the "$roleName" role from this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CountryUserService.deleteUserRole(profileRoleId);
        widget.onRoleChanged();
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
  }

  Future<void> _toggleRoleStatus(
      String profileRoleId, bool newStatus, String roleName) async {
    try {
      await CountryUserService.toggleUserRoleStatus(profileRoleId, newStatus);
      widget.onRoleChanged();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Role "$roleName" ${newStatus ? "activated" : "deactivated"} successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating role status: $e')),
        );
      }
    }
  }

  Future<void> _assignRole() async {
    showDialog(
      context: context,
      builder: (context) => _AssignRoleDialog(
        profileId: widget.profile.id,
        authorityId: widget.authorityId,
        availableRoles: _availableRoles,
        existingRoles:
            _userRoles.map((r) => r['roles']['name'] as String).toList(),
        onRoleAssigned: () {
          widget.onRoleChanged();
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Icon(Icons.person, color: Colors.orange.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.profile.fullName ?? 'Unknown User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Roles in ${widget.authorityName}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _userRoles.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                Icons.assignment_ind_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Roles Assigned',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This user has no roles in ${widget.authorityName}',
                                style: TextStyle(color: Colors.grey.shade500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: _userRoles.length,
                          itemBuilder: (context, index) {
                            final roleData = _userRoles[index];
                            final role = roleData['roles'];
                            final isActive = roleData['is_active'] as bool;
                            final assignedAt = DateTime.parse(
                                roleData['assigned_at'] as String);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title Row
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            role['display_name'] as String,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color:
                                                  isActive ? null : Colors.grey,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => _removeRole(
                                            roleData['id'] as String,
                                            role['display_name'] as String,
                                          ),
                                          icon: const Icon(
                                              Icons.remove_circle_outline),
                                          color: Colors.red,
                                          tooltip: 'Remove Role',
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Description Row
                                    Text(
                                      role['description'] as String? ??
                                          'No description',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Assignment Date Row
                                    Text(
                                      'Assigned: ${assignedAt.day}/${assignedAt.month}/${assignedAt.year}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Status Toggle Row
                                    Row(
                                      children: [
                                        Text(
                                          'Status:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Switch(
                                          value: isActive,
                                          onChanged: (value) =>
                                              _toggleRoleStatus(
                                            roleData['id'] as String,
                                            value,
                                            role['display_name'] as String,
                                          ),
                                          activeColor: Colors.orange.shade600,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isActive
                                                ? Colors.green.shade600
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _assignRole,
                      icon: const Icon(Icons.add),
                      label: const Text('Assign Role'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Done'),
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

/// Dialog for assigning a new role to a user
class _AssignRoleDialog extends StatefulWidget {
  final String profileId;
  final String authorityId;
  final List<Map<String, dynamic>> availableRoles;
  final List<String> existingRoles;
  final VoidCallback onRoleAssigned;

  const _AssignRoleDialog({
    required this.profileId,
    required this.authorityId,
    required this.availableRoles,
    required this.existingRoles,
    required this.onRoleAssigned,
  });

  @override
  State<_AssignRoleDialog> createState() => _AssignRoleDialogState();
}

class _AssignRoleDialogState extends State<_AssignRoleDialog> {
  String? _selectedRoleId;
  bool _isLoading = false;

  List<Map<String, dynamic>> get _assignableRoles {
    return widget.availableRoles
        .where((role) => !widget.existingRoles.contains(role['name']))
        .toList();
  }

  Future<void> _assignRole() async {
    if (_selectedRoleId == null) return;

    setState(() => _isLoading = true);

    try {
      await CountryUserService.assignUserRole(
        profileId: widget.profileId,
        roleId: _selectedRoleId!,
        authorityId: widget.authorityId,
      );

      widget.onRoleAssigned();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role assigned successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning role: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Role'),
      content: _assignableRoles.isEmpty
          ? const Text('No additional roles can be assigned to this user.')
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a role to assign:'),
                const SizedBox(height: 16),
                ..._assignableRoles.map((role) {
                  return RadioListTile<String>(
                    title: Text(role['display_name'] as String),
                    subtitle: Text(
                      role['description'] as String? ?? 'No description',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    value: role['id'] as String,
                    groupValue: _selectedRoleId,
                    onChanged: (value) {
                      setState(() {
                        _selectedRoleId = value;
                      });
                    },
                  );
                }),
              ],
            ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_assignableRoles.isNotEmpty)
          ElevatedButton(
            onPressed:
                _isLoading || _selectedRoleId == null ? null : _assignRole,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
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

/// Dialog for inviting a new user to the authority
class _InviteUserDialog extends StatefulWidget {
  final String authorityId;
  final String authorityName;
  final VoidCallback onInviteSent;

  const _InviteUserDialog({
    required this.authorityId,
    required this.authorityName,
    required this.onInviteSent,
  });

  @override
  State<_InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends State<_InviteUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false;

  final List<Map<String, String>> _roleOptions = [
    {'name': AppConstants.roleCountryAdmin, 'display': 'Country Administrator'},
    {'name': AppConstants.roleCountryAuditor, 'display': 'Country Auditor'},
    {'name': AppConstants.roleBorderOfficial, 'display': 'Border Official'},
    {
      'name': AppConstants.roleBusinessIntelligence,
      'display': 'Business Intelligence'
    },
    {'name': AppConstants.roleLocalAuthority, 'display': 'Local Authority'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedRole = AppConstants.roleBorderOfficial; // Default selection
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvitation() async {
    if (!_formKey.currentState!.validate() || _selectedRole == null) return;

    setState(() => _isLoading = true);

    try {
      await InvitationService.inviteUserToRole(
        email: _emailController.text.trim(),
        roleName: _selectedRole!,
        authorityId: widget.authorityId,
      );

      widget.onInviteSent();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending invitation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Invite User to ${widget.authorityName}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter user email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an email address';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Role to assign:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._roleOptions.map((role) {
              return RadioListTile<String>(
                title: Text(role['display']!),
                value: role['name']!,
                groupValue: _selectedRole,
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendInvitation,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade600,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Invitation'),
        ),
      ],
    );
  }
}
