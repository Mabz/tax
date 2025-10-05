import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/authority.dart';
import '../models/currency.dart';
import '../services/authority_service.dart';
import '../services/role_service.dart';
import '../services/vehicle_tax_rate_service.dart';
import '../constants/app_constants.dart';
import 'invitation_management_screen.dart';
import 'edit_authority_screen.dart';

/// Screen for managing all authorities - used by superusers only
/// For single authority management, use SingleAuthorityManagementScreen
class AuthorityManagementScreen extends StatefulWidget {
  const AuthorityManagementScreen({super.key});

  @override
  State<AuthorityManagementScreen> createState() =>
      _AuthorityManagementScreenState();
}

class _AuthorityManagementScreenState extends State<AuthorityManagementScreen> {
  List<Authority> _authorities = [];
  bool _isLoading = true;
  bool _isSuperuser = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoad();
  }

  Future<void> _checkPermissionsAndLoad() async {
    try {
      debugPrint('🔍 Authority Management: Starting permission check');

      final isSuperuser = await RoleService.isSuperuser();

      debugPrint('🔍 Authority Management: isSuperuser=$isSuperuser');

      setState(() => _isSuperuser = isSuperuser);

      // This screen is only for superusers managing all authorities
      if (!isSuperuser) {
        debugPrint(
            '❌ Authority Management: Access denied - superuser required');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access denied. Superuser privileges required.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      await _loadAuthorities();
    } catch (e, stackTrace) {
      debugPrint(
          '❌ Authority Management: Error in _checkPermissionsAndLoad: $e');
      debugPrint('❌ Authority Management: Stack trace: $stackTrace');

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking permissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAuthorities() async {
    try {
      debugPrint('🔍 Authority Management: Starting _loadAuthorities');
      setState(() => _isLoading = true);

      final authorities = await AuthorityService.getAllAuthorities();
      debugPrint(
          '✅ Authority Management: Loaded ${authorities.length} authorities');

      setState(() {
        _authorities = authorities;
        _isLoading = false;
      });
      debugPrint('✅ Authority Management: State updated successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Authority Management: Error in _loadAuthorities: $e');
      debugPrint('❌ Authority Management: Stack trace: $stackTrace');

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading authorities: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAuthorityDialog({Authority? authority}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AuthorityDialog(authority: authority),
    );

    if (result == true) {
      _loadAuthorities();
    }
  }

  Future<void> _navigateToEditAuthority(Authority authority) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditAuthorityScreen(authority: authority),
      ),
    );

    if (result == true) {
      _loadAuthorities();
    }
  }

  Future<void> _deleteAuthority(Authority authority) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('Disable Authority'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to disable this authority?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will deactivate the authority without permanently deleting it. The authority data will be preserved but marked as inactive.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authority.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Code: ${authority.code}'),
                  const SizedBox(height: 4),
                  Text('Type: ${authority.authorityTypeDisplay}'),
                  if (authority.countryName != null) ...[
                    const SizedBox(height: 4),
                    Text('Country: ${authority.countryName}'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_outlined,
                      color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Once disabled, this authority will no longer be available for new operations, but existing data will remain intact.',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Disable Authority'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AuthorityService.deleteAuthority(authority.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authority disabled successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        _loadAuthorities();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error disabling authority: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _navigateToInviteUsers(Authority authority) {
    // Show a dialog explaining the current limitation and offering alternatives
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            const Text('Invitation Options'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You can invite users to ${authority.name} using the following options:',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Option 1: Direct invitation management
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.mail, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Direct Invitation',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Open the invitation management screen for this authority',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Option 2: Home screen navigation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.home, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Via Home Screen',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Go to Home → Select Authority → Manage Invitations',
                    style: TextStyle(fontSize: 13),
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => InvitationManagementScreen(
                    authorityId: authority.id,
                    authorityName: authority.name,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Invitations'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSuperuser) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Authority Management'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSuperuser)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                AppConstants.superuserBadge,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _authorities.isEmpty
                ? _buildEmptyState()
                : _buildAuthorityList(),
      ),
      floatingActionButton: _isSuperuser
          ? FloatingActionButton(
              onPressed: () => _showAuthorityDialog(),
              backgroundColor: Colors.purple.shade600,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No authorities found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first authority to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAuthorityDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Create Authority'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Authority Management',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Authorities can be disabled to prevent new operations while preserving existing data. Disabled authorities are marked as "Inactive" and can be reactivated by editing them.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorityList() {
    return RefreshIndicator(
      onRefresh: _loadAuthorities,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _authorities.length + 1, // +1 for info header
        itemBuilder: (context, index) {
          // Show info header as first item
          if (index == 0) {
            return _buildInfoHeader();
          }

          final authority = _authorities[index - 1]; // Adjust index for header
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isSuperuser
                  ? () => _navigateToEditAuthority(authority)
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with authority name and menu
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getAuthorityColor(authority.authorityType)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getAuthorityIcon(authority.authorityType),
                            color: _getAuthorityColor(authority.authorityType),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authority.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: authority.isActive
                                          ? Colors.green.shade100
                                          : Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      authority.statusDisplay,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: authority.isActive
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      authority.authorityTypeDisplay,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (_isSuperuser)
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  _navigateToEditAuthority(authority);
                                  break;
                                case 'invite':
                                  _navigateToInviteUsers(authority);
                                  break;
                                case 'delete':
                                  _deleteAuthority(authority);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 20),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'invite',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_add,
                                        size: 20, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Invite Users',
                                        style: TextStyle(color: Colors.blue)),
                                  ],
                                ),
                              ),
                              // Only show delete/disable for superusers
                              if (_isSuperuser)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.block,
                                          size: 20, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text('Disable',
                                          style:
                                              TextStyle(color: Colors.orange)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Authority details
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            Icons.code,
                            'Code',
                            authority.code,
                          ),
                          if (authority.countryName != null) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              Icons.flag,
                              'Country',
                              authority.countryName!,
                            ),
                          ],
                          if (authority.description != null) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              Icons.description,
                              'Description',
                              authority.description!,
                            ),
                          ],
                          if (authority.defaultPassAdvanceDays != null) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              Icons.schedule,
                              'Default Pass Advance Days',
                              '${authority.defaultPassAdvanceDays} days',
                            ),
                          ],
                          if (authority.defaultCurrencyCode != null) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              Icons.attach_money,
                              'Default Currency',
                              authority.defaultCurrencyCode!,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Footer with creation date
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Created ${_formatDate(authority.createdAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const Spacer(),
                        if (authority.updatedAt != authority.createdAt) ...[
                          Icon(
                            Icons.update,
                            size: 16,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Updated ${_formatDate(authority.updatedAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getAuthorityIcon(String authorityType) {
    switch (authorityType) {
      case 'revenue_service':
        return Icons.account_balance;
      case 'customs':
        return Icons.local_shipping;
      case 'immigration':
        return Icons.person_pin;
      case 'global':
        return Icons.public;
      default:
        return Icons.account_balance;
    }
  }

  Color _getAuthorityColor(String authorityType) {
    switch (authorityType) {
      case 'revenue_service':
        return Colors.blue;
      case 'customs':
        return Colors.orange;
      case 'immigration':
        return Colors.green;
      case 'global':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final difference = today.difference(dateOnly).inDays;

    if (difference == 0) {
      return 'today';
    } else if (difference == 1) {
      return 'yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (difference < 365) {
      final months = (difference / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = (difference / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
  }
}

class AuthorityDialog extends StatefulWidget {
  final Authority? authority;

  const AuthorityDialog({super.key, this.authority});

  @override
  State<AuthorityDialog> createState() => _AuthorityDialogState();
}

class _AuthorityDialogState extends State<AuthorityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _advanceDaysController = TextEditingController();

  String? _selectedCountryId;
  String? _selectedAuthorityType;
  String? _selectedCurrencyCode;
  bool _isActive = true;

  List<Map<String, dynamic>> _countries = [];
  List<Currency> _currencies = [];
  bool _isLoading = false;
  bool _isLoadingCountries = true;
  bool _isLoadingCurrencies = true;

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _loadCurrencies();
    if (widget.authority != null) {
      _populateFields();
    } else {
      // Set defaults for new authority
      _selectedAuthorityType = 'revenue_service';
      _advanceDaysController.text = '30';
    }
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await AuthorityService.getAllCountries();
      setState(() {
        _countries = countries;
        _isLoadingCountries = false;
      });
    } catch (e) {
      setState(() => _isLoadingCountries = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading countries: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadCurrencies() async {
    try {
      final currencies = await VehicleTaxRateService.getActiveCurrencies();
      setState(() {
        _currencies = currencies;
        _isLoadingCurrencies = false;
      });
    } catch (e) {
      setState(() => _isLoadingCurrencies = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading currencies: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _populateFields() {
    final authority = widget.authority!;
    _nameController.text = authority.name;
    _codeController.text = authority.code;
    _descriptionController.text = authority.description ?? '';
    _advanceDaysController.text =
        authority.defaultPassAdvanceDays?.toString() ?? '30';

    _selectedCountryId = authority.countryId;
    _selectedAuthorityType = authority.authorityType;
    _selectedCurrencyCode = authority.defaultCurrencyCode;
    _isActive = authority.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _advanceDaysController.dispose();
    super.dispose();
  }

  Future<void> _saveAuthority() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final code = _codeController.text.trim().toUpperCase();
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final advanceDays =
          int.tryParse(_advanceDaysController.text.trim()) ?? 30;
      final currency = _selectedCurrencyCode;

      if (widget.authority == null) {
        // Create new authority
        await AuthorityService.createAuthority(
          countryId: _selectedCountryId!,
          name: name,
          code: code,
          authorityType: _selectedAuthorityType!,
          description: description,
          defaultPassAdvanceDays: advanceDays,
          defaultCurrencyCode: currency,
          isActive: _isActive,
        );
      } else {
        // Update existing authority
        await AuthorityService.updateAuthority(
          authorityId: widget.authority!.id,
          name: name,
          code: code,
          authorityType: _selectedAuthorityType!,
          description: description,
          defaultPassAdvanceDays: advanceDays,
          defaultCurrencyCode: currency,
          isActive: _isActive,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.authority == null
                  ? 'Authority created successfully'
                  : 'Authority updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving authority: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.authority == null ? 'Create Authority' : 'Edit Authority'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: _isLoadingCountries || _isLoadingCurrencies
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information Section
                      _buildSectionHeader('Basic Information'),
                      const SizedBox(height: 12),

                      // Country Selection
                      DropdownButtonFormField<String>(
                        value: _selectedCountryId,
                        decoration: const InputDecoration(
                          labelText: 'Country *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flag),
                        ),
                        items: _countries.map((country) {
                          return DropdownMenuItem(
                            value: country['id'] as String,
                            child: Text(country['name'] as String),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCountryId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Country is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Authority Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Authority Name *',
                          hintText: 'e.g., Kenya Revenue Authority',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.account_balance),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Authority name is required';
                          }
                          if (value.trim().length < 3) {
                            return 'Authority name must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Authority Code
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Authority Code *',
                          hintText: 'e.g., KRA',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.code),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Z0-9]')),
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Authority code is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Authority code must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Authority Type
                      DropdownButtonFormField<String>(
                        value: _selectedAuthorityType,
                        decoration: const InputDecoration(
                          labelText: 'Authority Type *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        isExpanded: true, // This fixes the overflow issue
                        items: AuthorityService.getAuthorityTypes().map((type) {
                          return DropdownMenuItem(
                            value: type['value'],
                            child: Text(
                              type['label']!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedAuthorityType = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Authority type is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Configuration Section
                      _buildSectionHeader('Configuration'),
                      const SizedBox(height: 12),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Brief description of the authority',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),

                      // Default Pass Advance Days
                      TextFormField(
                        controller: _advanceDaysController,
                        decoration: const InputDecoration(
                          labelText: 'Default Pass Advance Days',
                          hintText: '30',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.schedule),
                          suffixText: 'days',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final days = int.tryParse(value);
                            if (days == null || days < 1 || days > 365) {
                              return 'Enter a valid number between 1 and 365';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Default Currency Code
                      DropdownButtonFormField<String>(
                        value: _selectedCurrencyCode,
                        decoration: const InputDecoration(
                          labelText: 'Default Currency',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.monetization_on),
                        ),
                        isExpanded: true,
                        items: _currencies.map((currency) {
                          return DropdownMenuItem(
                            value: currency.code,
                            child: Text(
                              '${currency.code} - ${currency.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCurrencyCode = value;
                          });
                        },
                        validator: (value) {
                          // Currency is optional, so no validation needed
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Status Section
                      _buildSectionHeader('Status'),
                      const SizedBox(height: 12),

                      SwitchListTile(
                        title: const Text('Active'),
                        subtitle: Text(
                          _isActive
                              ? 'Authority is active and operational'
                              : 'Authority is inactive and cannot be used',
                        ),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveAuthority,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade600,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(widget.authority == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.purple.shade700,
      ),
    );
  }
}
