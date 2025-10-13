import 'package:flutter/material.dart';
import 'package:flutter_supabase_auth/models/role_invitation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';
import '../widgets/profile_image_widget.dart';
import 'profile_settings_screen.dart';
import '../models/authority.dart';
import '../models/country.dart';
import '../services/role_service.dart';
import '../services/authority_service.dart';
import '../services/invitation_service.dart';
import 'authority_management_screen.dart';
import 'single_authority_management_screen.dart';
import 'country_management_screen.dart';
import 'profile_management_screen.dart';
import 'border_type_management_screen.dart';
import 'border_management_screen.dart';
import 'border_official_management_screen.dart';
import 'audit_management_screen.dart';
import 'country_user_management_screen.dart';
import 'manage_users_screen.dart';
import 'bi/bi_dashboard_screen.dart';
import 'bi/pass_analytics_screen.dart';
import 'bi/non_compliance_screen.dart';
import 'bi/revenue_analytics_screen.dart';
import 'invitation_management_screen.dart';
import 'invitation_dashboard_screen.dart';
import 'vehicle_tax_rate_management_screen.dart';
import 'pass_template_management_screen.dart';
import 'vehicle_management_screen.dart';
import 'pass_dashboard_screen.dart';
import 'authority_validation_screen.dart';
import 'account_security_screen.dart';

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
  bool _isBorderOfficial = false;
  bool _isBusinessIntelligence = false;
  bool _isLocalAuthority = false;

  // Authority selection state
  List<Authority> _authorities = [];
  Authority? _selectedAuthority;
  bool _isLoadingAuthorities = false;
  RealtimeChannel? _authorityRealtimeChannel;

  // Invitation state
  int _pendingInvitationsCount = 0;
  bool _isLoadingInvitations = false;
  List<RoleInvitation> _pendingInvitations = [];
  RealtimeChannel? _invitationRealtimeChannel;

  // User profile state
  Profile? _currentProfile;
  bool _isLoadingProfile = true;
  bool _isAccountDisabled = false;
  RealtimeChannel? _profileRealtimeChannel;
  RealtimeChannel? _profileRolesRealtimeChannel;

  // Current authority's country roles
  List<String> _currentCountryRoles = [];

  @override
  void initState() {
    super.initState();
    _checkSuperuserStatus();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _invitationRealtimeChannel?.unsubscribe();
    _profileRealtimeChannel?.unsubscribe();
    _authorityRealtimeChannel?.unsubscribe();
    _profileRolesRealtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _checkSuperuserStatus() async {
    try {
      debugPrint('🔍 Starting role check for current user...');

      // Get current user info
      final user = Supabase.instance.client.auth.currentUser;
      debugPrint('👤 Current user ID: ${user?.id}');
      debugPrint('📧 Current user email: ${user?.email}');

      // Get all user roles for debugging
      final allRoles = await RoleService.getCurrentUserRoles();
      debugPrint('🎭 All user roles: $allRoles');

      final isSuperuser = await RoleService.isSuperuser();
      final isCountryAdmin = await RoleService.hasAdminRole();
      final isCountryAuditor = await RoleService.hasAuditorRole();
      final isBorderOfficial = await RoleService.hasBorderOfficialRole();
      final isBusinessIntelligence =
          await RoleService.hasBusinessIntelligenceRole();
      final isLocalAuthority = await RoleService.hasLocalAuthorityRole();

      // Additional debugging - check country admin countries
      if (isCountryAdmin) {
        final adminCountries = await RoleService.getCountryAdminCountries();
        debugPrint('🌍 Country admin countries: ${adminCountries.length}');
        for (final country in adminCountries) {
          debugPrint('  - ${country['name']} (${country['country_code']})');
        }
      }

      if (mounted) {
        setState(() {
          _isSuperuser = isSuperuser;
          _isCountryAdmin = isCountryAdmin;
          _isCountryAuditor = isCountryAuditor;
          _isBorderOfficial = isBorderOfficial;
          _isBusinessIntelligence = isBusinessIntelligence;
          _isLocalAuthority = isLocalAuthority;
          _isLoadingRoles = false;
        });
      }

      debugPrint('🔑 Superuser check: $_isSuperuser');
      debugPrint('🌍 Country Admin check: $_isCountryAdmin');
      debugPrint('🔍 Country Auditor check: $_isCountryAuditor');
      debugPrint('🛡️ Border Official check: $_isBorderOfficial');
      debugPrint('📊 Business Intelligence check: $_isBusinessIntelligence');
      debugPrint('🏛️ Local Authority check: $_isLocalAuthority');
      debugPrint(
          '🎯 Should load authorities: ${isSuperuser || isCountryAdmin || isCountryAuditor}');

      // Load authorities if user has admin, auditor, superuser, border official, business intelligence, or local authority role
      if (isSuperuser ||
          isCountryAdmin ||
          isCountryAuditor ||
          isBorderOfficial ||
          isBusinessIntelligence ||
          isLocalAuthority) {
        debugPrint('✅ Loading authorities...');
        await _loadAuthorities();
      } else {
        debugPrint('❌ Not loading authorities - user has no operational roles');
      }

      // Load pending invitations for all users
      await _loadPendingInvitations();

      // Setup real-time subscription for invitation changes
      _setupInvitationRealtimeSubscription();

      // Setup real-time subscription for authority changes
      _setupAuthorityRealtimeSubscription();

      // Setup real-time subscription for profile role changes
      _setupProfileRolesRealtimeSubscription();
    } catch (e) {
      debugPrint('❌ Error checking user roles: $e');
      if (mounted) {
        setState(() {
          _isSuperuser = false;
          _isCountryAdmin = false;
          _isCountryAuditor = false;
          _isBorderOfficial = false;
          _isBusinessIntelligence = false;
          _isLocalAuthority = false;
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
            debugPrint(
                '🔄 Real-time invitation change detected on home screen: ${payload.eventType}');
            _loadPendingInvitations();
          },
        )
        .subscribe();
  }

  void _setupAuthorityRealtimeSubscription() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Only set up subscription if user has roles that can see authorities
    if (!(_isSuperuser ||
        _isCountryAdmin ||
        _isCountryAuditor ||
        _isBorderOfficial ||
        _isBusinessIntelligence ||
        _isLocalAuthority)) {
      debugPrint('🔄 User has no roles that require authority subscription');
      return;
    }

    debugPrint('🔄 Setting up authority real-time subscription...');

    _authorityRealtimeChannel = Supabase.instance.client
        .channel('home_authority_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'authorities',
          callback: (payload) {
            debugPrint(
                '🔄 Real-time authority change detected: ${payload.eventType}');
            debugPrint(
                '   Authority ID: ${payload.newRecord['id'] ?? payload.oldRecord['id'] ?? 'unknown'}');

            // Reload authorities when changes occur
            _loadAuthorities();
          },
        )
        .subscribe();

    debugPrint('✅ Authority real-time subscription set up successfully');
  }

  void _setupProfileRolesRealtimeSubscription() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    debugPrint('🔄 Setting up profile roles real-time subscription...');

    _profileRolesRealtimeChannel = Supabase.instance.client
        .channel('home_profile_roles_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profile_roles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'profile_id',
            value: user.id,
          ),
          callback: (payload) async {
            debugPrint(
                '🔄 Real-time profile role change detected: ${payload.eventType}');
            debugPrint('   Role change for user: ${user.id}');

            // Reload user roles and authorities when role assignments change
            await _checkSuperuserStatus();

            // Also reload country roles for the selected authority to update menu items
            if (_selectedAuthority != null) {
              await _loadAuthorityCountryRoles();
            }

            debugPrint(
                '🔄 Profile role change processing complete, UI should update');
          },
        )
        .subscribe();

    debugPrint('✅ Profile roles real-time subscription set up successfully');
  }

  Future<void> _loadAuthorities() async {
    debugPrint(
        '🏛️ _loadAuthorities called - isLoading: $_isLoadingAuthorities');

    if (_isLoadingAuthorities) {
      debugPrint('⏳ Already loading authorities, skipping...');
      return;
    }

    setState(() {
      _isLoadingAuthorities = true;
    });

    try {
      List<Authority> authorities = []; // Initialize with empty list

      debugPrint(
          '🔍 Loading authorities - Superuser: $_isSuperuser, Country Admin: $_isCountryAdmin, Country Auditor: $_isCountryAuditor, Border Official: $_isBorderOfficial, Local Authority: $_isLocalAuthority');

      if (_isSuperuser) {
        // Superusers get all active authorities
        debugPrint('🔑 Loading all authorities for superuser...');
        authorities = await AuthorityService.getAllAuthorities();
        debugPrint(
            '🔑 Loaded ${authorities.length} active authorities for superuser');
      } else if (_isCountryAdmin || _isCountryAuditor) {
        // Country admins and auditors get only their assigned authorities
        debugPrint('🔍 Loading admin authorities for country admin/auditor...');
        authorities = await AuthorityService.getAdminAuthorities();
        debugPrint(
            '🌍 Loaded ${authorities.length} assigned authorities for admin/auditor');

        // Debug: Print authority details
        if (authorities.isEmpty) {
          debugPrint('⚠️ No authorities returned for country admin/auditor!');
        } else {
          debugPrint('📋 Authority details:');
          for (final authority in authorities) {
            debugPrint(
                '  - ${authority.name} (${authority.code}) - ${authority.countryName}');
          }
        }
      } else if (_isBorderOfficial ||
          _isBusinessIntelligence ||
          _isLocalAuthority) {
        // Border officials, business intelligence, and local authorities get their assigned authorities
        debugPrint(
            '🛡️ Loading operational authorities for border official/local authority...');
        authorities = await AuthorityService.getOperationalAuthorities();
        debugPrint(
            '🛡️ Loaded ${authorities.length} assigned authorities for operational roles');

        // Debug: Print authority details
        if (authorities.isEmpty) {
          debugPrint(
              '⚠️ No authorities returned for border official/local authority!');
        } else {
          debugPrint('📋 Authority details:');
          for (final authority in authorities) {
            debugPrint(
                '  - ${authority.name} (${authority.code}) - ${authority.countryName}');
          }
        }
      } else {
        // For users with no operational roles, keep empty list
        debugPrint('ℹ️ User has no roles that require authority access');
      }

      if (mounted) {
        setState(() {
          // Filter out global authorities
          _authorities = authorities.where((authority) {
            return authority.authorityType != 'global' &&
                authority.code != 'GLOBAL';
          }).toList();

          if (_authorities.isNotEmpty && _selectedAuthority == null) {
            _selectedAuthority = _authorities.first;
            // Load roles for the selected authority's country
            _loadAuthorityCountryRoles();
          }
          _isLoadingAuthorities = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading authorities: $e');
      if (mounted) {
        setState(() {
          _authorities = [];
          _selectedAuthority = null;
          _isLoadingAuthorities = false;
        });
      }
    }
  }

  void _showAuthoritySelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _AuthoritySelectionDialog(
          authorities: _authorities,
          selectedAuthority: _selectedAuthority,
          onAuthoritySelected: (authority) {
            setState(() {
              _selectedAuthority = authority;
            });
            _loadAuthorityCountryRoles();
            debugPrint(
                '🏛️ Selected authority: ${authority.name} (${authority.countryName})');
          },
        );
      },
    );
  }

  Future<void> _loadAuthorityCountryRoles() async {
    if (_selectedAuthority?.countryId == null) {
      setState(() {
        _currentCountryRoles = [];
      });
      return;
    }

    try {
      final roles = await RoleService.getUserRolesForCountry(
          _selectedAuthority!.countryId);
      if (mounted) {
        setState(() {
          _currentCountryRoles = roles;
        });
      }
      debugPrint(
          '🎭 Loaded roles for ${_selectedAuthority!.countryName}: $roles');
      debugPrint(
          '🔄 Country roles updated, drawer should rebuild with new menu items');
    } catch (e) {
      debugPrint('❌ Error loading authority country roles: $e');
      if (mounted) {
        setState(() {
          _currentCountryRoles = [];
        });
      }
    }
  }

  Future<void> _loadPendingInvitations() async {
    if (_isLoadingInvitations) return;

    setState(() {
      _isLoadingInvitations = true;
    });

    try {
      final invitations =
          await InvitationService.getPendingInvitationsForUser();
      if (mounted) {
        setState(() {
          _pendingInvitations = invitations;
          _pendingInvitationsCount = invitations.length;
          _isLoadingInvitations = false;
        });
      }
      debugPrint('📧 Loaded ${invitations.length} pending invitations');
    } catch (e) {
      debugPrint('❌ Error loading pending invitations: $e');
      if (mounted) {
        setState(() {
          _pendingInvitations = [];
          _pendingInvitationsCount = 0;
          _isLoadingInvitations = false;
        });
      }
    }
  }

  /// Load current user profile and set up real-time subscription
  Future<void> _loadCurrentProfile() async {
    try {
      setState(() {
        _isLoadingProfile = true;
      });

      final user = Supabase.instance.client.auth.currentUser;
      if (user?.email == null) {
        debugPrint('❌ No user email found');
        return;
      }

      // Get current profile
      final profile = await ProfileService.getProfileByEmail(user!.email!);

      setState(() {
        _currentProfile = profile;
        _isAccountDisabled = profile?.isActive == false;
        _isLoadingProfile = false;
      });

      // Set up real-time subscription for profile changes
      _setupProfileRealtimeSubscription();

      debugPrint('✅ Loaded profile: ${profile?.fullName ?? profile?.email}');

      // Show account disabled message if needed
      if (_isAccountDisabled && mounted) {
        _showAccountDisabledDialog();
      }
    } catch (e) {
      debugPrint('❌ Error loading profile: $e');
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  /// Set up real-time subscription for profile changes
  void _setupProfileRealtimeSubscription() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user?.id == null) return;

    _profileRealtimeChannel = Supabase.instance.client
        .channel('profile_changes_${user!.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: user.id,
          ),
          callback: (payload) {
            debugPrint(
                '🔄 Real-time profile change detected: ${payload.eventType}');
            _handleProfileChange(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Handle real-time profile changes
  void _handleProfileChange(Map<String, dynamic>? newRecord) {
    if (newRecord == null) return;

    try {
      final updatedProfile = Profile.fromJson(newRecord);
      final wasDisabled = _isAccountDisabled;

      setState(() {
        _currentProfile = updatedProfile;
        _isAccountDisabled = !updatedProfile.isActive;
      });

      // Show account disabled dialog if account was just disabled
      if (!wasDisabled && _isAccountDisabled && mounted) {
        _showAccountDisabledDialog();
      }

      debugPrint(
          '✅ Profile updated: ${updatedProfile.fullName ?? updatedProfile.email}');
    } catch (e) {
      debugPrint('❌ Error handling profile change: $e');
    }
  }

  /// Show account disabled dialog
  void _showAccountDisabledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Account Disabled'),
          ],
        ),
        content: const Text(
          'Your account has been disabled by an administrator. '
          'Please contact support for assistance.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _signOut(context);
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
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

  // Helper methods to check country-specific roles for selected authority
  bool _hasCountryRole(String roleName) {
    return _currentCountryRoles.contains(roleName);
  }

  bool _isCountryAdminForSelected() {
    return _hasCountryRole(AppConstants.roleCountryAdmin);
  }

  bool _isCountryAuditorForSelected() {
    return _hasCountryRole(AppConstants.roleCountryAuditor);
  }

  bool _isBorderOfficialForSelected() {
    return _hasCountryRole(AppConstants.roleBorderOfficial);
  }

  bool _isBusinessIntelligenceForSelected() {
    return _hasCountryRole(AppConstants.roleBusinessIntelligence);
  }

  bool _isLocalAuthorityForSelected() {
    return _hasCountryRole(AppConstants.roleLocalAuthority);
  }

  Widget _buildDrawer() {
    // Debug logging for authority selection visibility
    debugPrint(
        '🎯 Drawer build - Superuser: $_isSuperuser, Country Admin: $_isCountryAdmin, Country Auditor: $_isCountryAuditor');
    debugPrint('🎯 Authorities count: ${_authorities.length}');
    debugPrint(
        '🎯 Should show authority selection: ${(_isSuperuser || _isCountryAdmin || _isCountryAuditor || _isBorderOfficial || _isBusinessIntelligence || _isLocalAuthority) && _authorities.isNotEmpty}');
    debugPrint(
        '🎭 Current country roles for selected authority: $_currentCountryRoles');
    debugPrint(
        '🏛️ Selected authority: ${_selectedAuthority?.name} (${_selectedAuthority?.countryName})');

    return SafeArea(
        child: Drawer(
            child: ListView(padding: EdgeInsets.zero, children: [
      Container(
        height: 140, // Reduced from default DrawerHeader height (164)
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade700,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User information
            if (_isLoadingProfile)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Loading user...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              )
            else if (_currentProfile != null)
              Row(
                children: [
                  // Profile Image
                  ProfileImageWidget(
                    currentImageUrl: _currentProfile!.profileImageUrl,
                    size: 50,
                    isEditable: false,
                  ),
                  const SizedBox(width: 12),
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentProfile!.fullName ??
                              _currentProfile!.email ??
                              'Unknown User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_currentProfile!.fullName != null &&
                            _currentProfile!.email != null)
                          Text(
                            _currentProfile!.email!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (_isAccountDisabled)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ACCOUNT DISABLED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              )
            else
              const Text(
                'No user information',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            const SizedBox(height: 4),

            // Authority selection dropdown for users with operational roles
            if ((_isSuperuser ||
                    _isCountryAdmin ||
                    _isCountryAuditor ||
                    _isBorderOfficial ||
                    _isBusinessIntelligence ||
                    _isLocalAuthority) &&
                _authorities.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: InkWell(
                  onTap: _showAuthoritySelectionDialog,
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedAuthority?.name ?? 'Select Authority',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (_selectedAuthority != null)
                              Text(
                                _selectedAuthority!.countryName ??
                                    'Unknown Country',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],

            // Role badges - using Wrap to prevent overflow
            if (_isSuperuser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            else if (_selectedAuthority != null) ...[
              // Show country-specific role badges for selected authority's country
              Wrap(
                spacing: 2,
                runSpacing: 1,
                children: [
                  if (_isCountryAdminForSelected())
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                            color: Colors.orange.shade300, width: 0.5),
                      ),
                      child: Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  if (_isCountryAuditorForSelected())
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                            color: Colors.purple.shade300, width: 0.5),
                      ),
                      child: Text(
                        'AUDITOR',
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  if (_isBorderOfficialForSelected())
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(3),
                        border:
                            Border.all(color: Colors.red.shade300, width: 0.5),
                      ),
                      child: Text(
                        'BORDER',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  if (_isBusinessIntelligenceForSelected())
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                            color: Colors.green.shade300, width: 0.5),
                      ),
                      child: Text(
                        'BI',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  if (_isLocalAuthorityForSelected())
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(3),
                        border:
                            Border.all(color: Colors.blue.shade300, width: 0.5),
                      ),
                      child: Text(
                        'LOCAL',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ] else if (_isCountryAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              )
            else if (_isBorderOfficial)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  'BORDER OFFICIAL',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
            else if (_isBusinessIntelligence)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(
                  'BUSINESS INTELLIGENCE',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
            else if (_isLocalAuthority)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Text(
                  'LOCAL AUTHORITY',
                  style: TextStyle(
                    color: Colors.blue.shade700,
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
        // System Status (Debug info)
        Container(
          color: Colors.purple.shade50,
          child: ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'System Status',
                    style: TextStyle(
                      color: Colors.purple.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _isLoadingAuthorities
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.purple.shade600),
                        ),
                      )
                    : Icon(Icons.refresh,
                        color: Colors.purple.shade600, size: 20),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style:
                        TextStyle(color: Colors.purple.shade600, fontSize: 11),
                    children: [
                      TextSpan(
                          text: 'Superuser: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: _isSuperuser ? "Yes" : "No"),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style:
                        TextStyle(color: Colors.purple.shade600, fontSize: 11),
                    children: [
                      TextSpan(
                          text: 'Country Admin: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: _isCountryAdmin ? "Yes" : "No"),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style:
                        TextStyle(color: Colors.purple.shade600, fontSize: 11),
                    children: [
                      TextSpan(
                          text: 'Country Auditor: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: _isCountryAuditor ? "Yes" : "No"),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style:
                        TextStyle(color: Colors.purple.shade600, fontSize: 11),
                    children: [
                      TextSpan(
                          text: 'Border Official: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: _isBorderOfficial ? "Yes" : "No"),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style:
                        TextStyle(color: Colors.purple.shade600, fontSize: 11),
                    children: [
                      TextSpan(
                          text: 'Business Intelligence: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: _isBusinessIntelligence ? "Yes" : "No"),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style:
                        TextStyle(color: Colors.purple.shade600, fontSize: 11),
                    children: [
                      TextSpan(
                          text: 'Local Authority: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: _isLocalAuthority ? "Yes" : "No"),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style:
                        TextStyle(color: Colors.purple.shade600, fontSize: 11),
                    children: [
                      TextSpan(
                          text: 'Authorities: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: '${_authorities.length} loaded'),
                    ],
                  ),
                ),
                if (_selectedAuthority != null) ...[
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                          color: Colors.purple.shade600, fontSize: 11),
                      children: [
                        TextSpan(
                            text: 'Selected: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: '${_selectedAuthority!.countryName}'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            onTap: _isLoadingAuthorities
                ? null
                : () async {
                    debugPrint('🔄 Manual refresh requested...');
                    await _loadAuthorities();
                    await _checkSuperuserStatus();
                    setState(() {});
                  },
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings,
                  color: Colors.purple.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'System Administration',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.purple.shade50,
          child: ListTile(
            leading: const Icon(Icons.public, color: Colors.purple),
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
        ),
        Container(
          color: Colors.purple.shade50,
          child: ListTile(
            leading: const Icon(Icons.people, color: Colors.purple),
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
        ),
        Container(
          color: Colors.purple.shade50,
          child: ListTile(
            leading: const Icon(Icons.account_balance, color: Colors.purple),
            title: const Text('Manage Authorities'),
            subtitle: const Text('Create and manage revenue authorities'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AuthorityManagementScreen(),
                ),
              );
            },
          ),
        ),
        Container(
          color: Colors.purple.shade50,
          child: ListTile(
            leading: const Icon(Icons.border_all, color: Colors.purple),
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
        ),
      ],

      // Authority Management functions (show after superuser section)
      if (_isSuperuser ||
          (_selectedAuthority != null && _isCountryAdminForSelected())) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.account_balance,
                  color: Colors.orange.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Authority Management',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.mail, color: Colors.orange),
          title: const Text('Manage Invitations'),
          subtitle: Text(_selectedAuthority != null
              ? 'Send invitations for ${_selectedAuthority!.name}'
              : 'Send and manage role invitations'),
          onTap: () {
            if (_selectedAuthority == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select an authority first'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => InvitationManagementScreen(
                  authorityId: _selectedAuthority!.id,
                  authorityName: _selectedAuthority!.name,
                  selectedCountry: Country(
                    id: _selectedAuthority!.countryId,
                    name: _selectedAuthority!.countryName ?? 'Unknown',
                    countryCode: _selectedAuthority!.countryCode ?? '',
                    isActive: true,
                    isGlobal: false,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
          title: const Text('Manage Authority'),
          subtitle: Text(_selectedAuthority != null
              ? 'Manage ${_selectedAuthority!.name}'
              : 'Manage authority details'),
          onTap: () async {
            if (_selectedAuthority == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select an authority first'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            Navigator.of(context).pop();
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SingleAuthorityManagementScreen(
                  authority: _selectedAuthority!,
                ),
              ),
            );

            // Refresh authorities if the authority was updated
            if (result == true) {
              await _loadAuthorities();
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.people, color: Colors.orange),
          title: const Text('Manage Users'),
          subtitle: Text(_selectedAuthority != null
              ? 'Manage authority user profiles for ${_selectedAuthority!.name}'
              : 'Manage authority user profiles'),
          onTap: () {
            if (_selectedAuthority == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select an authority first'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ManageUsersScreen(
                  selectedAuthority: {
                    'id': _selectedAuthority!.countryId,
                    'name': _selectedAuthority!.countryName ?? 'Unknown',
                    'country_code': _selectedAuthority!.countryCode ?? '',
                    'authority_id': _selectedAuthority!.id,
                    'authority_name': _selectedAuthority!.name,
                  },
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.admin_panel_settings_outlined,
              color: Colors.orange),
          title: const Text('Manage Roles'),
          subtitle: Text(_selectedAuthority != null
              ? 'Assign roles and send invitations for ${_selectedAuthority!.name}'
              : 'Manage user roles and send invitations'),
          onTap: () {
            if (_selectedAuthority == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select an authority first'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CountryUserManagementScreen(
                  selectedCountry: {
                    'id': _selectedAuthority!.countryId,
                    'name': _selectedAuthority!.countryName ?? 'Unknown',
                    'country_code': _selectedAuthority!.countryCode ?? '',
                    'authority_id': _selectedAuthority!.id,
                    'authority_name': _selectedAuthority!.name,
                  },
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.history, color: Colors.orange),
          title: const Text('Audit Logs'),
          subtitle: Text(_selectedAuthority != null
              ? 'View logs for ${_selectedAuthority!.name}'
              : 'View audit trail and activity logs'),
          onTap: () {
            if (_selectedAuthority == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select an authority first'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AuditManagementScreen(
                  selectedCountry: {
                    'id': _selectedAuthority!.countryId,
                    'name': _selectedAuthority!.countryName ?? 'Unknown',
                    'country_code': _selectedAuthority!.countryCode ?? '',
                    'authority_id': _selectedAuthority!.id,
                    'authority_name': _selectedAuthority!.name,
                  },
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.location_on, color: Colors.orange),
          title: const Text('Manage Borders'),
          subtitle: Text(_selectedAuthority != null
              ? 'Manage borders for ${_selectedAuthority!.name}'
              : 'Create and manage border crossings'),
          onTap: () {
            if (_selectedAuthority == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select an authority first'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => BorderManagementScreen(
                  selectedCountry: {
                    'id': _selectedAuthority!.countryId,
                    'name': _selectedAuthority!.countryName ?? 'Unknown',
                    'country_code': _selectedAuthority!.countryCode ?? '',
                    'authority_id': _selectedAuthority!.id,
                    'authority_name': _selectedAuthority!.name,
                  },
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.security, color: Colors.orange),
          title: const Text('Border Officials'),
          subtitle: Text(_selectedAuthority != null
              ? 'Assign officials for ${_selectedAuthority!.name}'
              : 'Assign border officials to borders'),
          onTap: () {
            if (_selectedAuthority == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select an authority first'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => BorderOfficialManagementScreen(
                  selectedCountry: {
                    'id': _selectedAuthority!.countryId,
                    'name': _selectedAuthority!.countryName ?? 'Unknown',
                    'country_code': _selectedAuthority!.countryCode ?? '',
                    'authority_id': _selectedAuthority!.id,
                    'authority_name': _selectedAuthority!.name,
                  },
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.local_taxi, color: Colors.orange),
          title: const Text('Vehicle Tax Rates'),
          subtitle: Text(_selectedAuthority != null
              ? 'Manage rates for ${_selectedAuthority!.name}'
              : 'Manage tax rates for vehicles'),
          onTap: () {
            if (_selectedAuthority == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select an authority first'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => VehicleTaxRateManagementScreen(
                  selectedCountry: {
                    'id': _selectedAuthority!.countryId,
                    'name': _selectedAuthority!.countryName ?? 'Unknown',
                    'country_code': _selectedAuthority!.countryCode ?? '',
                    'authority_id': _selectedAuthority!.id,
                    'authority_name': _selectedAuthority!.name,
                    'default_currency_code':
                        _selectedAuthority!.defaultCurrencyCode,
                  },
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.receipt_long, color: Colors.orange),
          title: const Text('Pass Templates'),
          subtitle: Text(_selectedAuthority != null
              ? 'Manage templates for ${_selectedAuthority!.name}'
              : 'Create and manage pass templates'),
          onTap: () {
            if (_selectedAuthority == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select an authority first'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            Navigator.of(context).pop();
            debugPrint(
                '🔍 Selected authority defaultPassAdvanceDays: ${_selectedAuthority!.defaultPassAdvanceDays}');
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PassTemplateManagementScreen(
                  authorityId: _selectedAuthority!.id,
                  authorityName: _selectedAuthority!.name,
                ),
              ),
            );
          },
        ),
      ],
      // Border Control (Border Officials)
      if (_selectedAuthority != null && _isBorderOfficialForSelected()) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.shield, color: Colors.red.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Border Control',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.shield, color: Colors.red),
          title: const Text('Validate Passes'),
          subtitle: Text(
            'Validate passes at ${_selectedAuthority!.name}',
          ),
          onTap: () async {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AuthorityValidationScreen(
                  role: AuthorityRole.borderOfficial,
                  currentAuthorityId: _selectedAuthority?.id,
                  currentCountryId: _selectedAuthority?.countryId,
                ),
              ),
            );
          },
        ),
      ],

      // Local Authority Control (Local Authorities)
      if (_selectedAuthority != null && _isLocalAuthorityForSelected()) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.verified, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Local Authority Control',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.verified, color: Colors.blue),
          title: const Text('Validate Passes'),
          subtitle: Text(
            'Validate passes for ${_selectedAuthority!.name}',
          ),
          onTap: () async {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AuthorityValidationScreen(
                  role: AuthorityRole.localAuthority,
                  currentAuthorityId: _selectedAuthority?.id,
                  currentCountryId: _selectedAuthority?.countryId,
                ),
              ),
            );
          },
        ),
      ],

      // Invitations (if user has pending invitations)
      if (_pendingInvitationsCount > 0) ...[
        ListTile(
          leading: Stack(
            children: [
              const Icon(Icons.mail, color: Colors.orange),
              if (_pendingInvitationsCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_pendingInvitationsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          title: const Text('Role Invitations'),
          subtitle: Text(
            '$_pendingInvitationsCount pending invitation${_pendingInvitationsCount == 1 ? '' : 's'}',
          ),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const InvitationDashboardScreen(),
              ),
            );
          },
        ),
      ],

      // Business Intelligence functions (only show if user has BI role for selected country)
      if (_selectedAuthority != null &&
          (_isSuperuser || _isBusinessIntelligenceForSelected())) ...[
        // Section Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.analytics, color: Colors.green.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Business Intelligence',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dashboard, color: Colors.green),
          title: const Text('Dashboard Overview'),
          subtitle:
              Text('Key metrics and insights for ${_selectedAuthority!.name}'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => BiDashboardScreen(
                  authority: _selectedAuthority!,
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.analytics, color: Colors.green),
          title: const Text('Pass Analytics'),
          subtitle:
              Text('Pass trends and analytics for ${_selectedAuthority!.name}'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PassAnalyticsScreen(
                  authority: _selectedAuthority!,
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.warning, color: Colors.green),
          title: const Text('Non-Compliance'),
          subtitle: Text(
              'Non-compliance detection and analysis for ${_selectedAuthority!.name}'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => NonComplianceScreen(
                  authority: _selectedAuthority!,
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.attach_money, color: Colors.green),
          title: const Text('Revenue Analytics'),
          subtitle: Text(
              'Revenue insights and financial analytics for ${_selectedAuthority!.name}'),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => RevenueAnalyticsScreen(
                  authority: _selectedAuthority!,
                ),
              ),
            );
          },
        ),
      ],

      // Country Auditor functions (for auditors who are not admins for selected authority's country)
      if (_selectedAuthority != null &&
          _isCountryAuditorForSelected() &&
          !_isCountryAdminForSelected()) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.fact_check, color: Colors.purple.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Audit & Compliance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.history, color: Colors.purple),
          title: const Text('Audit Logs'),
          subtitle: Text(_selectedAuthority != null
              ? 'View logs for ${_selectedAuthority!.name}'
              : 'View audit trail and activity logs'),
          onTap: () {
            if (_selectedAuthority == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select an authority first'),
                  backgroundColor: Colors.purple,
                ),
              );
              return;
            }
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AuditManagementScreen(
                  selectedCountry: {
                    'id': _selectedAuthority!.countryId,
                    'name': _selectedAuthority!.countryName ?? 'Unknown',
                    'country_code': _selectedAuthority!.countryCode ?? '',
                    'authority_id': _selectedAuthority!.id,
                    'authority_name': _selectedAuthority!.name,
                  },
                ),
              ),
            );
          },
        ),
      ],

      // User functions (available to all authenticated users)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.person, color: Colors.blue.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              'My Account',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      ),

      ListTile(
        leading: const Icon(Icons.receipt_long, color: Colors.blue),
        title: const Text('My Passes'),
        subtitle: const Text('Purchase and manage border passes'),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PassDashboardScreen(),
            ),
          );
        },
      ),
      ListTile(
        leading: const Icon(Icons.directions_car, color: Colors.blue),
        title: const Text('My Vehicles'),
        subtitle: const Text('Register and manage your vehicles'),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const VehicleManagementScreen(),
            ),
          );
        },
      ),
      ListTile(
        leading: const Icon(Icons.lock, color: Colors.blue),
        title: const Text('Account & Security'),
        subtitle: const Text('Change password, enable 2FA'),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AccountSecurityScreen(),
            ),
          );
        },
      ),
      ListTile(
        leading: const Icon(Icons.person_outline, color: Colors.blue),
        title: const Text('Profile Settings'),
        subtitle: const Text('Manage identity, payment & preferences'),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ProfileSettingsScreen(),
            ),
          );
        },
      ),

      // Sign out option at the bottom
      const Divider(),
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text('Sign Out'),
        subtitle: const Text('Sign out of your account'),
        onTap: () => _signOut(context),
      ),
    ])));
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

    // Show profile setup screen if profile is incomplete
    if (!_isLoadingProfile &&
        _currentProfile != null &&
        _currentProfile!.needsSetup) {
      return _buildProfileSetupScreen();
    }

    // Show account disabled screen if account is disabled
    if (_isAccountDisabled && !_isLoadingProfile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Account Disabled'),
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.warning_rounded,
                  size: 80,
                  color: Colors.red.shade600,
                ),
                const SizedBox(height: 24),
                Text(
                  'Account Disabled',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your account has been disabled by an administrator. '
                  'Please contact support for assistance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Border Tax'),
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
      drawer: !_isLoadingRoles ? _buildDrawer() : null,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(children: [
              // Loading progress bar
              if (_isLoadingRoles ||
                  _isLoadingInvitations ||
                  _isLoadingAuthorities) ...[
                _buildLoadingProgress(),
                const SizedBox(height: 24),
              ],

              // Horizontal Invitation Cards
              if (_pendingInvitationsCount > 0 && !_isLoadingInvitations) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.mail,
                            color: Colors.blue.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Role Invitations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_pendingInvitationsCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const InvitationDashboardScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'View All',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 170,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _pendingInvitations.length,
                        itemBuilder: (context, index) {
                          final invitation = _pendingInvitations[index];
                          return Container(
                            width: 280,
                            margin: const EdgeInsets.only(right: 12),
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.business,
                                              color: Colors.blue.shade800,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              invitation.formattedRoleName,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade800,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        invitation.formattedAuthority,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Invited by ${invitation.inviterName ?? "Unknown"} • ${invitation.timeSinceInvited}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                // Capture messenger BEFORE the async gap to avoid using context after await.
                                                final messenger =
                                                    ScaffoldMessenger.of(
                                                        context);
                                                try {
                                                  await InvitationService
                                                      .acceptInvitation(
                                                          invitation.id);
                                                  if (!mounted) return;
                                                  messenger.showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                          'Invitation accepted successfully!'),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                  _loadPendingInvitations();
                                                } catch (e) {
                                                  if (!mounted) return;
                                                  messenger.showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Error accepting invitation: $e'),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 4),
                                                minimumSize: const Size(0, 32),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text(
                                                'Accept',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () async {
                                                try {
                                                  await InvitationService
                                                      .declineInvitation(
                                                          invitation.id);
                                                  if (!mounted) return;
                                                  if (mounted) {
                                                    final messenger =
                                                        ScaffoldMessenger.of(
                                                            this.context);
                                                    messenger.showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                            'Invitation declined'),
                                                        backgroundColor:
                                                            Colors.orange,
                                                      ),
                                                    );
                                                  }
                                                  _loadPendingInvitations();
                                                } catch (e) {
                                                  if (!mounted) return;
                                                  if (mounted) {
                                                    final messenger =
                                                        ScaffoldMessenger.of(
                                                            this.context);
                                                    messenger.showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            'Error declining invitation: $e'),
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                side: const BorderSide(
                                                    color: Colors.red),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 4),
                                                minimumSize: const Size(0, 32),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text(
                                                'Decline',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ],
              // Main user features (for all users)
              if (!_isLoadingRoles) ...[
                // Pass Dashboard Card
                Card(
                  elevation: 4,
                  margin: const EdgeInsets.all(16),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PassDashboardScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue.shade600,
                            Colors.blue.shade800,
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Icon(
                                  Icons.local_taxi,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Border Passes',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Purchase passes for quick border crossings',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 24,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.shopping_cart,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Purchase',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'New passes',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.receipt_long,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Manage',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Your passes',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Vehicle Management Card
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.directions_car,
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'My Vehicles',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text('Register and manage your vehicles'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const VehicleManagementScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Profile Settings Card
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        color: Colors.blue.shade600,
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'Profile Settings',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle:
                        const Text('Manage identity, payment & preferences'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ProfileSettingsScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  /// Build profile setup screen for first-time users
  Widget _buildProfileSetupScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Prevent back navigation
        actions: [
          IconButton(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Welcome icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_add_rounded,
                  size: 60,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 32),

              // Welcome message
              Text(
                'Welcome to Border Tax!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                'To get started, please complete your profile setup. This information is required for border crossing verification and system access.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Required information card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Required Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildRequirementItem('Full Name',
                        'Your legal name as it appears on documents'),
                    _buildRequirementItem('Identity Documents',
                        'National ID and passport information'),
                    _buildRequirementItem(
                        'Country of Origin', 'Your citizenship country'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context)
                        .push(
                      MaterialPageRoute(
                        builder: (context) => const ProfileSettingsScreen(),
                      ),
                    )
                        .then((_) {
                      // Refresh profile data when returning from settings
                      _loadCurrentProfile();
                    });
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Complete Profile Setup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Skip option (if needed for testing)
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Skip Profile Setup?'),
                      content: const Text(
                        'You can skip this step, but some features may not be available until you complete your profile. You can always complete it later from the drawer menu.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Force refresh to bypass the setup screen
                            setState(() {
                              _isLoadingProfile = true;
                            });
                            Future.delayed(const Duration(milliseconds: 500),
                                () {
                              setState(() {
                                _isLoadingProfile = false;
                              });
                            });
                          },
                          child: const Text('Skip for Now'),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(
                  'Skip for now',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build requirement item for profile setup
  Widget _buildRequirementItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade600,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build loading progress indicator
  Widget _buildLoadingProgress() {
    String loadingText = 'Loading...';
    Color progressColor = Colors.blue;

    if (_isLoadingRoles) {
      loadingText = 'Loading dashboard...';
      progressColor = Colors.blue;
    } else if (_isLoadingInvitations) {
      loadingText = 'Loading invitations...';
      progressColor = Colors.blue.shade600;
    } else if (_isLoadingAuthorities) {
      loadingText = 'Loading authorities...';
      progressColor = Colors.orange.shade600;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loadingText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 4,
          ),
        ],
      ),
    );
  }
}

// Authority Selection Dialog Widget
class _AuthoritySelectionDialog extends StatefulWidget {
  final List<Authority> authorities;
  final Authority? selectedAuthority;
  final Function(Authority) onAuthoritySelected;

  const _AuthoritySelectionDialog({
    required this.authorities,
    required this.selectedAuthority,
    required this.onAuthoritySelected,
  });

  @override
  State<_AuthoritySelectionDialog> createState() =>
      _AuthoritySelectionDialogState();
}

class _AuthoritySelectionDialogState extends State<_AuthoritySelectionDialog> {
  late TextEditingController _searchController;
  List<Authority> _filteredAuthorities = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Filter out global authorities from the start
    _filteredAuthorities = widget.authorities.where((authority) {
      return authority.authorityType != 'global' && authority.code != 'GLOBAL';
    }).toList();
    _searchController.addListener(_filterAuthorities);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterAuthorities() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAuthorities = widget.authorities.where((authority) {
        // Exclude global authorities
        if (authority.authorityType == 'global' || authority.code == 'GLOBAL') {
          return false;
        }

        return authority.name.toLowerCase().contains(query) ||
            (authority.countryName?.toLowerCase().contains(query) ?? false) ||
            authority.code.toLowerCase().contains(query) ||
            (authority.countryCode?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.blue.shade50.withValues(alpha: 0.3),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Authority',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      Text(
                        '${_filteredAuthorities.length} ${_filteredAuthorities.length == 1 ? "authority" : "authorities"} available',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: Colors.grey.shade600,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search authorities or countries...',
                prefixIcon: Icon(Icons.search, color: Colors.blue.shade600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                ),
                filled: true,
                fillColor: Colors.blue.shade50,
              ),
            ),
            const SizedBox(height: 16),

            // Authority List
            Expanded(
              child: _filteredAuthorities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No authorities found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your search terms',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredAuthorities.length,
                      itemBuilder: (context, index) {
                        final authority = _filteredAuthorities[index];
                        final isSelected =
                            widget.selectedAuthority?.id == authority.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color:
                                isSelected ? Colors.blue.shade50 : Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue.shade300
                                  : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue.shade200
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.account_balance,
                                color: isSelected
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade600,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              '${authority.name} - ${authority.countryName ?? "Unknown"}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.blue.shade800 : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        authority.code,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        authority.authorityTypeDisplay,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (authority.countryCode != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Country: ${authority.countryCode}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                            trailing: isSelected
                                ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      color: Colors.green.shade700,
                                      size: 16,
                                    ),
                                  )
                                : Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.grey.shade400,
                                    size: 16,
                                  ),
                            onTap: () {
                              widget.onAuthoritySelected(authority);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredAuthorities.length} ${_filteredAuthorities.length == 1 ? "authority" : "authorities"} found',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
