import 'package:flutter/material.dart';
import '../models/authority.dart';
import '../services/authority_service.dart';
import '../services/role_service.dart';

import 'edit_authority_screen.dart';
import 'invitation_management_screen.dart';

/// Screen for managing a single authority - used by country admins
/// This is separate from AuthorityManagementScreen for security reasons
class SingleAuthorityManagementScreen extends StatefulWidget {
  final Authority authority;

  const SingleAuthorityManagementScreen({
    super.key,
    required this.authority,
  });

  @override
  State<SingleAuthorityManagementScreen> createState() =>
      _SingleAuthorityManagementScreenState();
}

class _SingleAuthorityManagementScreenState
    extends State<SingleAuthorityManagementScreen> {
  late Authority _authority;
  bool _isLoading = false;
  bool _hasAccess = false;
  bool _isCountryAdmin = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _authority = widget.authority;
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final isSuperuser = await RoleService.isSuperuser();
      final isCountryAdmin = await RoleService.hasAdminRole();

      setState(() {
        _hasAccess = isSuperuser || isCountryAdmin;
        _isCountryAdmin = isCountryAdmin;
      });

      if (!_hasAccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access denied. Admin privileges required.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking permissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _refreshAuthority() async {
    try {
      debugPrint(
          '🔍 SingleAuthority: Starting authority refresh for ID: ${_authority.id}');
      setState(() => _isLoading = true);

      final authority = await AuthorityService.getAuthorityById(_authority.id);
      debugPrint(
          '🔍 SingleAuthority: Retrieved authority from service: ${authority?.name}');

      if (authority != null) {
        debugPrint('✅ SingleAuthority: Authority found, updating state');
        debugPrint('🔍 SingleAuthority: Old name: ${_authority.name}');
        debugPrint('🔍 SingleAuthority: New name: ${authority.name}');
        debugPrint(
            '🔍 SingleAuthority: Old description: ${_authority.description}');
        debugPrint(
            '🔍 SingleAuthority: New description: ${authority.description}');

        setState(() {
          _authority = authority;
        });
        debugPrint('✅ SingleAuthority: State updated successfully');
      } else {
        debugPrint('❌ SingleAuthority: Authority not found in database');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ SingleAuthority: Error refreshing authority: $e');
      debugPrint('❌ SingleAuthority: Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing authority: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToEditAuthority() async {
    debugPrint('🔍 SingleAuthority: Navigating to EditAuthorityScreen');
    debugPrint(
        '🔍 SingleAuthority: Current authority: ${_authority.name} (${_authority.id})');

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditAuthorityScreen(authority: _authority),
      ),
    );

    debugPrint(
        '🔍 SingleAuthority: Returned from EditAuthorityScreen with result: $result');

    if (result == true) {
      debugPrint('✅ SingleAuthority: Changes detected, refreshing authority');
      await _refreshAuthority();
      // Mark that changes were made so the home screen can refresh
      _hasChanges = true;
    } else {
      debugPrint('ℹ️ SingleAuthority: No changes detected, skipping refresh');
    }
  }

  Future<void> _navigateToInviteUsers() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvitationManagementScreen(
          authorityId: _authority.id,
          authorityName: _authority.name,
        ),
      ),
    );
  }

  Color _getAuthorityColor(String authorityType) {
    switch (authorityType.toLowerCase()) {
      case 'country':
        return Colors.green;
      case 'state':
        return Colors.blue;
      case 'city':
        return Colors.orange;
      case 'local':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getAuthorityIcon(String authorityType) {
    switch (authorityType.toLowerCase()) {
      case 'country':
        return Icons.flag;
      case 'state':
        return Icons.location_city;
      case 'city':
        return Icons.business;
      case 'local':
        return Icons.home;
      default:
        return Icons.account_balance;
    }
  }

  String _formatFriendlyDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      }
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${_formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      // Format as "Jan 15, 2024 at 2:30 PM"
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final month = months[dateTime.month - 1];
      final day = dateTime.day;
      final year = dateTime.year;
      final time = _formatTime(dateTime);

      return '$month $day, $year at $time';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    return '$displayHour:$minute $period';
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.orange.shade600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Return true if changes were made, so the home screen can refresh
        Navigator.of(context).pop(_hasChanges);
        return false; // Prevent default pop behavior since we handled it
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_authority.name} Management'),
          backgroundColor: Colors.orange.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Return true if changes were made, so the home screen can refresh
              Navigator.of(context).pop(_hasChanges);
            },
          ),
          actions: [
            IconButton(
              onPressed: _navigateToInviteUsers,
              icon: const Icon(Icons.person_add),
              tooltip: 'Invite Users',
            ),
          ],
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _refreshAuthority,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAuthorityProfile(),
                        const SizedBox(
                            height: 100), // Extra space to prevent overflow
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAuthorityProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header section with icon, name, and edit button
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade600, Colors.orange.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getAuthorityIcon(_authority.authorityType),
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _authority.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _authority.code,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _navigateToEditAuthority,
                    icon: const Icon(Icons.edit, color: Colors.white, size: 28),
                    tooltip: 'Edit Authority',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _authority.isActive
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _authority.isActive ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _authority.statusDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _authority.isActive ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      _authority.authorityTypeDisplay,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Details section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Authority Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailRow(
                Icons.fingerprint,
                'Authority ID',
                _authority.id,
              ),
              const SizedBox(height: 16),
              if (_authority.countryName != null) ...[
                _buildDetailRow(
                  Icons.flag,
                  'Country',
                  _authority.countryName!,
                ),
                const SizedBox(height: 16),
              ],
              if (_authority.description != null &&
                  _authority.description!.isNotEmpty) ...[
                _buildDetailRow(
                  Icons.description,
                  'Description',
                  _authority.description!,
                ),
                const SizedBox(height: 16),
              ],
              if (_authority.defaultPassAdvanceDays != null) ...[
                _buildDetailRow(
                  Icons.schedule,
                  'Default Pass Advance Days',
                  '${_authority.defaultPassAdvanceDays} days',
                ),
                const SizedBox(height: 16),
              ],
              if (_authority.defaultCurrencyCode != null &&
                  _authority.defaultCurrencyCode!.isNotEmpty) ...[
                _buildDetailRow(
                  Icons.attach_money,
                  'Default Currency',
                  _authority.defaultCurrencyCode!,
                ),
                const SizedBox(height: 16),
              ],
              _buildDetailRow(
                Icons.calendar_today,
                'Created',
                _formatFriendlyDate(_authority.createdAt),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                Icons.update,
                'Last Updated',
                _formatFriendlyDate(_authority.updatedAt),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
