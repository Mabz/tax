import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../models/role_invitation.dart';
import '../models/country.dart';
import '../services/invitation_service.dart';

/// Screen for managing role invitations (Superuser and Country Admin access)
class InvitationManagementScreen extends StatefulWidget {
  final Country? selectedCountry;
  final String? authorityId;
  final String? authorityName;

  const InvitationManagementScreen({
    super.key,
    this.selectedCountry,
    this.authorityId,
    this.authorityName,
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
  RealtimeChannel? _invitationRealtimeChannel;

  // Helper getter for authority name
  String? get _authorityName {
    return widget.authorityName ?? widget.selectedCountry?.name;
  }

  // Helper getter for authority ID
  String? get _authorityId {
    return widget.authorityId;
  }

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _invitationRealtimeChannel?.unsubscribe();
    super.dispose();
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

      await _loadData();

      // Set up real-time subscription for invitation changes
      // _setupInvitationRealtimeSubscription(); // Disabled due to binding error
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
      // Determine which invitations to load based on selected country/authority
      Future<List<RoleInvitation>> invitationsFuture;

      if (_authorityId != null && _authorityId!.isNotEmpty) {
        // Load invitations for the specific authority (preferred method)
        invitationsFuture =
            InvitationService.getAllInvitationsForAuthority(_authorityId!);
        debugPrint(
            '🏛️ Loading invitations for authority: $_authorityName ($_authorityId)');
      } else if (widget.selectedCountry != null &&
          widget.selectedCountry!.id.isNotEmpty) {
        // Fallback: Load invitations for the specific country using legacy function
        debugPrint(
            '⚠️ No authority ID provided, falling back to country-based loading');
        debugPrint('🌍 Country ID: ${widget.selectedCountry!.id}');
        debugPrint('🌍 Country Name: ${widget.selectedCountry!.name}');

        invitationsFuture = InvitationService.getAllInvitationsForCountry(
            widget.selectedCountry!.id);
        debugPrint(
            '🌍 Loading invitations for country: ${widget.selectedCountry!.name}');
      } else {
        // Load all invitations (fallback for superusers or when no country selected)
        debugPrint(
            '⚠️ No authority or country information available, loading all invitations');
        invitationsFuture = InvitationService.getAllInvitations();
        debugPrint('🌍 Loading all invitations (no filter)');
      }

      // Load invitations and roles concurrently
      final results = await Future.wait([
        invitationsFuture,
        InvitationService.getInvitableRoles(),
      ]);

      setState(() {
        _invitations = results[0] as List<RoleInvitation>;
        // Filter out superuser role - it should never be available for invitation
        _roles = (results[1] as List<Map<String, dynamic>>)
            .where((role) => role[AppConstants.fieldRoleName] != 'superuser')
            .toList();
        _isLoading = false;
      });

      debugPrint(
          '✅ Loaded ${_invitations.length} invitations and ${_roles.length} roles');

      // Debug: Log the first few invitations to see what we got
      for (int i = 0; i < _invitations.length && i < 3; i++) {
        debugPrint(
            '   Invitation $i: ${_invitations[i].email} - ${_invitations[i].formattedRoleName} (ID: ${_invitations[i].id})');
      }
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

  /// Set up real-time subscription for invitation changes
  void _setupInvitationRealtimeSubscription() {
    try {
      debugPrint(
          '🔄 Setting up real-time subscription for invitation management');
      debugPrint('   Authority ID: $_authorityId');
      debugPrint('   Country ID: ${widget.selectedCountry?.id}');

      // Clean up existing subscription first
      _invitationRealtimeChannel?.unsubscribe();

      _invitationRealtimeChannel = Supabase.instance.client
          .channel(
              'invitation_management_changes_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: AppConstants.tableRoleInvitations,
            // No filter - listen to ALL changes to catch accept/decline from any authority
            callback: (payload) {
              try {
                debugPrint(
                    '🔄 Real-time invitation change detected in management screen: ${payload.eventType}');
                debugPrint(
                    '   Invitation ID: ${payload.newRecord?['id'] ?? payload.oldRecord?['id'] ?? 'unknown'}');
                debugPrint(
                    '   Email: ${payload.newRecord?['email'] ?? payload.oldRecord?['email'] ?? 'unknown'}');
                debugPrint(
                    '   Status: ${payload.newRecord?['status'] ?? payload.oldRecord?['status'] ?? 'unknown'}');
                debugPrint(
                    '   Authority ID: ${payload.newRecord?['authority_id'] ?? payload.oldRecord?['authority_id'] ?? 'unknown'}');

                // Add a small delay to avoid race conditions with manual refreshes
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    debugPrint(
                        '🔄 Real-time triggered reload of invitation list');
                    _loadData();
                  }
                });
              } catch (e) {
                debugPrint('🔄 Error processing realtime callback: $e');
              }
            },
          )
          .subscribe((status, [error]) {
        debugPrint('🔄 Subscription status: $status');
        if (error != null) {
          debugPrint('🔄 Subscription error: $error');
        } else if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint(
              '✅ Real-time subscription set up for invitation management');
        }
      });
    } catch (e) {
      debugPrint('🔄 Failed to setup realtime subscription: $e');
      // Continue without realtime - the app should still work
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
                        child: Text(
                          role[AppConstants.fieldRoleDisplayName] ??
                              role[AppConstants.fieldRoleName],
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedRoleName = value);
                    },
                  ),
                  if (_authorityId == null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning,
                              color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Authority information not available. Please select an authority from the home screen.',
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
                      _authorityId != null
                  ? () async {
                      // Capture context before async operation
                      final navigator = Navigator.of(context);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);

                      try {
                        await InvitationService.inviteUserToRole(
                          email: email,
                          roleName: selectedRoleName!,
                          authorityId: _authorityId!,
                        );

                        if (mounted) {
                          navigator.pop();
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Invitation sent successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );

                          // Refresh the list immediately
                          debugPrint(
                              '🔄 Manually refreshing invitation list after sending invitation');
                          await _loadData();
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
    final theme =
        (Colors.orange, Colors.orange.shade100, Colors.orange.shade800);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitations'),
        backgroundColor: theme.$2,
        foregroundColor: theme.$3,
        actions: [
          IconButton(
            onPressed: () {
              debugPrint('🔄 Manual refresh button pressed');
              _loadData();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Authority header - fixed below app bar
          if (_authorityName != null)
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
                    _authorityName!,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_invitations.length} invitation(s) sent',
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
                  : _invitations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No Invitations',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _authorityName != null
                                    ? 'No role invitations have been sent for $_authorityName yet.'
                                    : 'No role invitations have been sent yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              if (_authorityName != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Use the + button to send your first invitation.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
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
            ),
          ),
        ],
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
