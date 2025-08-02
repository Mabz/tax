import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/role_invitation.dart';
import '../models/country.dart';
import '../services/invitation_service.dart';
import '../services/role_service.dart';

/// Screen for managing role invitations (Superuser and Country Admin access)
class InvitationManagementScreen extends StatefulWidget {
  final Country? selectedCountry;

  const InvitationManagementScreen({
    super.key,
    this.selectedCountry,
  });

  @override
  State<InvitationManagementScreen> createState() =>
      _InvitationManagementScreenState();
}

class _InvitationManagementScreenState
    extends State<InvitationManagementScreen> {
  List<RoleInvitation> _invitations = [];
  List<Map<String, dynamic>> _roles = [];
  bool _isLoading = true;
  bool _isSuperuser = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      // Check permissions
      final canSend = await InvitationService.canSendInvitations();
      if (!canSend) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to manage invitations'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      _isSuperuser = await RoleService.isSuperuser();
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing screen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load invitations and roles concurrently
      final results = await Future.wait([
        InvitationService.getAllInvitations(),
        InvitationService.getInvitableRoles(),
      ]);

      setState(() {
        _invitations = results[0] as List<RoleInvitation>;
        _roles = results[1] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showInviteDialog() async {
    String email = '';
    String? selectedRoleName;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send Role Invitation'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'user@example.com',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => email = value.trim(),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.person),
                    ),
                    value: selectedRoleName,
                    isExpanded: true,
                    items: _roles.map((role) {
                      return DropdownMenuItem<String>(
                        value: role[AppConstants.fieldRoleName],
                        child: Flexible(
                          child: Text(
                            role[AppConstants.fieldRoleDisplayName] ??
                                role[AppConstants.fieldRoleName],
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedRoleName = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Show selected country info (read-only)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flag, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Country',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                widget.selectedCountry != null
                                    ? '${widget.selectedCountry!.name} (${widget.selectedCountry!.countryCode})'
                                    : 'No country selected',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.selectedCountry == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Please select a country in the drawer menu first',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: email.isNotEmpty &&
                      selectedRoleName != null &&
                      widget.selectedCountry != null
                  ? () async {
                      // Capture context before async operation
                      final navigator = Navigator.of(context);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      
                      try {
                        await InvitationService.inviteUserToRole(
                          email: email,
                          roleName: selectedRoleName!,
                          countryCode: widget.selectedCountry!.countryCode,
                        );

                        if (mounted) {
                          navigator.pop();
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Invitation sent successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadData(); // Refresh the list
                        }
                      } catch (e) {
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Error sending invitation: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  : null,
              child: const Text('Send Invitation'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteInvitation(RoleInvitation invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invitation'),
        content: Text(
          'Are you sure you want to delete the invitation for ${invitation.email}?\n\n'
          'Role: ${invitation.formattedRoleName}\n'
          'Country: ${invitation.formattedCountry}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await InvitationService.deleteInvitation(invitation.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invitation deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData(); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting invitation: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _resendInvitation(RoleInvitation invitation) async {
    try {
      await InvitationService.resendInvitation(invitation.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation resent successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resending invitation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInvitationCard(RoleInvitation invitation) {
    Color statusColor;
    IconData statusIcon;

    switch (invitation.status) {
      case AppConstants.invitationStatusPending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case AppConstants.invitationStatusAccepted:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case AppConstants.invitationStatusDeclined:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.email, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    invitation.email,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        invitation.statusDisplay,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Role: ${invitation.formattedRoleName}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Country: ${invitation.formattedCountry}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Invited: ${invitation.timeSinceInvited}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            if (invitation.inviterName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_add, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Invited by: ${invitation.inviterName}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (invitation.isPending) ...[
                  TextButton.icon(
                    onPressed: () => _resendInvitation(invitation),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Resend'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton.icon(
                  onPressed: () => _deleteInvitation(invitation),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _isSuperuser
        ? (Colors.red, Colors.red.shade100, Colors.red.shade800)
        : (Colors.orange, Colors.orange.shade100, Colors.orange.shade800);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Invitations'),
        backgroundColor: theme.$2,
        foregroundColor: theme.$3,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invitations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mail_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No invitations found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Send your first invitation using the + button',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    itemCount: _invitations.length,
                    itemBuilder: (context, index) {
                      return _buildInvitationCard(_invitations[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showInviteDialog,
        backgroundColor: theme.$1,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
