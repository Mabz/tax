import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../models/country.dart';
import '../services/role_service.dart';
import '../services/country_service.dart';
import '../services/invitation_service.dart';
import 'country_management_screen.dart';
import 'profile_management_screen.dart';
import 'border_type_management_screen.dart';
import 'border_management_screen.dart';
import 'audit_management_screen.dart';
import 'invitation_management_screen.dart';
import 'invitation_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSuperuser = false;
  bool _isLoadingRoles = true;
  bool _isCountryAdmin = false;
  bool _isCountryAuditor = false;

  // Country selection state
  List<Country> _countries = [];
  Country? _selectedCountry;
  bool _isLoadingCountries = false;
  
  // Invitation state
  int _pendingInvitationsCount = 0;
  bool _isLoadingInvitations = false;
  RealtimeChannel? _invitationRealtimeChannel;

  @override
  void initState() {
    super.initState();
    _checkSuperuserStatus();
  }

  @override
  void dispose() {
    _invitationRealtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _checkSuperuserStatus() async {
    try {
      final isSuperuser = await RoleService.isSuperuser();
      final isCountryAdmin = await RoleService.hasAdminRole();
      final isCountryAuditor =
          await RoleService.userHasRole(AppConstants.roleCountryAuditor);

      if (mounted) {
        setState(() {
          _isSuperuser = isSuperuser;
          _isCountryAdmin = isCountryAdmin;
          _isCountryAuditor = isCountryAuditor;
          _isLoadingRoles = false;
        });
      }

      debugPrint('🔑 Superuser check: $_isSuperuser');
      debugPrint('🌍 Country Admin check: $_isCountryAdmin');
      debugPrint('🔍 Country Auditor check: $_isCountryAuditor');

      // Load countries if user has admin, auditor, or superuser role
      if (isSuperuser || isCountryAdmin || isCountryAuditor) {
        await _loadCountries();
      }
      
      // Load pending invitations for all users
      await _loadPendingInvitations();
      
      // Setup real-time subscription for invitation changes
      _setupInvitationRealtimeSubscription();
    } catch (e) {
      debugPrint('❌ Error checking user roles: $e');
      if (mounted) {
        setState(() {
          _isSuperuser = false;
          _isCountryAdmin = false;
          _isCountryAuditor = false;
          _isLoadingRoles = false;
        });
      }
    }
  }

  void _setupInvitationRealtimeSubscription() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _invitationRealtimeChannel = Supabase.instance.client
        .channel('home_invitation_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConstants.tableRoleInvitations,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: AppConstants.fieldRoleInvitationEmail,
            value: user.email!,
          ),
          callback: (payload) {
            debugPrint('🔄 Real-time invitation change detected on home screen: ${payload.eventType}');
            _loadPendingInvitations();
          },
        )
        .subscribe();
  }

  Future<void> _loadCountries() async {
    if (_isLoadingCountries) return;

    setState(() {
      _isLoadingCountries = true;
    });

    try {
      List<Country> countries;
      
      if (_isSuperuser) {
        // Superusers get all active countries excluding Global
        countries = await CountryService.getActiveCountriesExcludingGlobal();
        debugPrint('🔑 Loaded ${countries.length} active countries for superuser (excluding Global)');
      } else {
        // Country admins and auditors get only their assigned countries
        final countryMaps = await RoleService.getCountryAdminCountries();
        countries = countryMaps.map((map) => Country(
          id: map[AppConstants.fieldId],
          name: map[AppConstants.fieldCountryName],
          countryCode: map[AppConstants.fieldCountryCode],
          revenueServiceName: map[AppConstants.fieldCountryRevenueServiceName] ?? '',
          isActive: map[AppConstants.fieldCountryIsActive] ?? true,
          isGlobal: map[AppConstants.fieldCountryIsGlobal] ?? false,
          createdAt: DateTime.tryParse(map[AppConstants.fieldCreatedAt] ?? '') ?? DateTime.now(),
          updatedAt: DateTime.tryParse(map[AppConstants.fieldUpdatedAt] ?? '') ?? DateTime.now(),
        )).toList();
        debugPrint('🌍 Loaded ${countries.length} assigned countries for admin/auditor');
      }
      
      if (mounted) {
        setState(() {
          _countries = countries;
          if (_countries.isNotEmpty && _selectedCountry == null) {
            _selectedCountry = _countries.first;
          }
          _isLoadingCountries = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading countries: $e');
      if (mounted) {
        setState(() {
          _countries = [];
          _selectedCountry = null;
          _isLoadingCountries = false;
        });
      }
    }
  }

  void _showCountrySelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Country'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _countries.length,
              itemBuilder: (context, index) {
                final country = _countries[index];
                final isSelected = _selectedCountry?.id == country.id;
                return ListTile(
                  leading: Icon(
                    Icons.public,
                    color: Colors.orange.shade700,
                  ),
                  title: Text(country.name),
                  subtitle: Text(country.countryCode),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCountry = country;
                    });
                    debugPrint('🌍 Selected country: ${country.name}');
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadPendingInvitations() async {
    if (_isLoadingInvitations) return;

    setState(() {
      _isLoadingInvitations = true;
    });

    try {
      final invitations = await InvitationService.getPendingInvitationsForUser();
      if (mounted) {
        setState(() {
          _pendingInvitationsCount = invitations.length;
          _isLoadingInvitations = false;
        });
      }
      debugPrint('📧 Loaded ${invitations.length} pending invitations');
    } catch (e) {
      debugPrint('❌ Error loading pending invitations: $e');
      if (mounted) {
        setState(() {
          _pendingInvitationsCount = 0;
          _isLoadingInvitations = false;
        });
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_isSuperuser)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Text(
                      AppConstants.superuserBadge,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                else if (_isCountryAdmin)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Text(
                      'COUNTRY ADMIN',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                else if (_isCountryAuditor)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.purple.shade300),
                    ),
                    child: Text(
                      'COUNTRY AUDITOR',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Superuser functions
          if (_isSuperuser) ...[
            ListTile(
              leading: const Icon(Icons.public, color: Colors.red),
              title: const Text('Manage Countries'),
              subtitle: const Text('Add, edit, or remove countries'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CountryManagementScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.red),
              title: const Text('Manage Users'),
              subtitle: const Text('Search and manage user profiles'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ProfileManagementScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.border_all, color: Colors.red),
              title: const Text('Manage Border Types'),
              subtitle: const Text('Configure border crossing types'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BorderTypeManagementScreen(),
                  ),
                );
              },
            ),

            const Divider(),
          ],
          // Country Selection (for Superusers, Country Admins and Auditors)
          if ((_isSuperuser || _isCountryAdmin || _isCountryAuditor) &&
              _countries.isNotEmpty) ...[
            Container(
              color: Colors.orange.shade100,
              child: ListTile(
                leading: Icon(
                  Icons.public,
                  color: Colors.orange.shade800,
                ),
                title: Text(
                  'Select Country',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  _selectedCountry != null
                      ? '${_selectedCountry!.name} (${_selectedCountry!.countryCode})'
                      : 'Choose working country',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.orange.shade800,
                ),
                onTap: () {
                  _showCountrySelectionDialog();
                },
              ),
            ),
            const Divider(),
          ],
          // Country Admin functions
          if (_isCountryAdmin) ...[
            ListTile(
              leading: const Icon(Icons.policy, color: Colors.orange),
              title: const Text('Tax Policies'),
              subtitle: const Text('Manage country tax policies'),
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Navigate to tax policies screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tax Policies - Coming Soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail, color: Colors.orange),
              title: const Text('Manage Invitations'),
              subtitle: const Text('Send and manage role invitations'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => InvitationManagementScreen(
                      selectedCountry: _selectedCountry,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.orange),
              title: const Text('Audit Logs'),
              subtitle: const Text('View audit trail and activity logs'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AuditManagementScreen(
                      selectedCountry: _selectedCountry?.toJson(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.orange),
              title: const Text('Manage Borders'),
              subtitle: const Text('Create and manage border crossings'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BorderManagementScreen(
                      selectedCountry: _selectedCountry?.toJson(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.orange),
              title: const Text('Customs Officials'),
              subtitle: const Text('Manage customs officials'),
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Navigate to customs officials screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Customs Officials - Coming Soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics, color: Colors.orange),
              title: const Text('Country Reports'),
              subtitle: const Text('View country-specific reports'),
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Navigate to country reports screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Country Reports - Coming Soon')),
                );
              },
            ),
          ],
          // Country Auditor functions (for auditors who are not admins)
          if (_isCountryAuditor && !_isCountryAdmin) ...[
            ListTile(
              leading: const Icon(Icons.history, color: Colors.purple),
              title: const Text('Audit Logs'),
              subtitle: const Text('View audit trail and activity logs'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AuditManagementScreen(
                      selectedCountry: _selectedCountry?.toJson(),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('No user found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('EasyTax'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      drawer: (_isSuperuser || _isCountryAdmin || _isCountryAuditor) &&
              !_isLoadingRoles
          ? _buildDrawer()
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Invitation Dashboard Card
            if (_pendingInvitationsCount > 0 && !_isLoadingInvitations) ...[
              Card(
                elevation: 4,
                color: Colors.blue.shade50,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const InvitationDashboardScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.mail,
                            color: Colors.blue.shade700,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You have $_pendingInvitationsCount pending invitation${_pendingInvitationsCount == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to review and respond to role invitations',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Admin Panel Hint Card (for admin users)
            if ((_isSuperuser || _isCountryAdmin || _isCountryAuditor) && !_isLoadingRoles) ...[
              Card(
                elevation: 2,
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Access admin functions through the menu drawer',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.menu,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // Welcome message for regular users
            if (!_isSuperuser && !_isCountryAdmin && !_isCountryAuditor && !_isLoadingRoles) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.home,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome to EasyTax',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your tax management platform',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
