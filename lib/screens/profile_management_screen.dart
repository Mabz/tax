import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../models/country.dart';
import '../services/profile_service.dart';
import '../services/role_service.dart';
import 'profile_detail_screen.dart';

class ProfileManagementScreen extends StatefulWidget {
  final Country? selectedCountry;

  const ProfileManagementScreen({super.key, this.selectedCountry});

  @override
  State<ProfileManagementScreen> createState() =>
      _ProfileManagementScreenState();
}

class _ProfileManagementScreenState extends State<ProfileManagementScreen> {
  List<Profile> _profiles = [];
  List<Map<String, dynamic>> _countryProfiles = [];
  bool _isLoading = true;
  bool _isSuperuser = false;
  bool _isCountryAdmin = false;
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionsAndLoadData() async {
    try {
      final isSuperuser = await RoleService.isSuperuser();
      final hasAdmin = await RoleService.hasAdminRole();

      if (!hasAdmin) {
        if (mounted) {
          final navigator = Navigator.of(context);
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          navigator.pop();
          scaffoldMessenger.showSnackBar(
            const SnackBar(
                content: Text('Access denied: Administrator role required')),
          );
        }
        return;
      }

      setState(() {
        _isSuperuser = isSuperuser;
        _isCountryAdmin = !isSuperuser &&
            hasAdmin; // Country admin if has admin role but not superuser
      });

      await _loadProfiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking permissions: $e')),
        );
      }
    }
  }

  Future<void> _loadProfiles() async {
    try {
      setState(() => _isLoading = true);

      if (_isSuperuser) {
        // Superusers can see all profiles
        final profiles = await ProfileService.getAllProfiles();
        setState(() {
          _profiles = profiles;
          _countryProfiles = [];
          _isLoading = false;
        });
      } else if (_isCountryAdmin && widget.selectedCountry != null) {
        // Country admins see profiles in their selected country
        final countryProfiles = await ProfileService.getProfilesByCountry(
            widget.selectedCountry!.id);
        setState(() {
          _profiles = [];
          _countryProfiles = countryProfiles;
          _isLoading = false;
        });
      } else {
        // No country selected for country admin
        setState(() {
          _profiles = [];
          _countryProfiles = [];
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please select a country from the drawer')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profiles: $e')),
        );
      }
    }
  }

  Future<void> _searchByEmail() async {
    final email = _searchController.text.trim();
    if (email.isEmpty) {
      await _loadProfiles();
      return;
    }

    try {
      setState(() => _isSearching = true);
      final profile = await ProfileService.getProfileByEmail(email);
      setState(() {
        _profiles = profile != null ? [profile] : [];
        _isSearching = false;
      });

      if (profile == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No user found with email: $email')),
        );
      }
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching for user: $e')),
        );
      }
    }
  }

  Future<void> _searchProfiles() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      await _loadProfiles();
      return;
    }

    try {
      setState(() => _isSearching = true);
      final profiles = await ProfileService.searchProfiles(query);
      setState(() {
        _profiles = profiles;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching profiles: $e')),
        );
      }
    }
  }

  void _navigateToProfileDetail(Profile profile) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => ProfileDetailScreen(profile: profile),
      ),
    )
        .then((_) {
      // Refresh the list when returning from profile detail
      _loadProfiles();
    });
  }

  Future<void> _toggleProfileStatus(Profile profile) async {
    try {
      await ProfileService.updateProfileStatus(
        id: profile.id,
        isActive: !profile.isActive,
      );
      await _loadProfiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Profile ${profile.isActive ? 'deactivated' : 'activated'} successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile status: $e')),
        );
      }
    }
  }

  Widget _buildProfileCard(Map<String, dynamic> profileData) {
    final profileId = profileData['profile_id'] as String;
    final fullName = profileData['full_name'] as String?;
    final email = profileData['email'] as String?;
    final roleName = profileData['role_name'] as String?;
    final assignedAt = profileData['assigned_at'] as String?;
    final isActive = profileData['is_active'] as bool? ?? true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            (fullName?.isNotEmpty == true ? fullName![0] : email?[0] ?? 'U')
                .toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          fullName?.isNotEmpty == true ? fullName! : 'No Name',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${email ?? 'No Email'}'),
            Text('Role: ${roleName ?? 'Unknown'}'),
            if (assignedAt != null)
              Text(
                  'Assigned: ${DateTime.parse(assignedAt).toLocal().toString().split('.')[0]}'),
            Text('Status: ${isActive ? 'Active' : 'Inactive'}'),
          ],
        ),
        trailing: Icon(
          isActive ? Icons.check_circle : Icons.cancel,
          color: isActive ? Colors.green : Colors.red,
        ),
        onTap: () {
          // For country profiles, we need to create a Profile object to navigate
          final profile = Profile(
            id: profileId,
            fullName: fullName,
            email: email,
            isActive: isActive,
            createdAt: assignedAt != null
                ? DateTime.parse(assignedAt)
                : DateTime.now(),
            updatedAt: DateTime.now(),
          );
          _navigateToProfileDetail(profile);
        },
        isThreeLine: true,
      ),
    );
  }

  Widget _buildResultsList() {
    if (_isSuperuser) {
      // Show all profiles for superusers
      if (_profiles.isEmpty) {
        return const Center(
          child: Text('No users found.'),
        );
      }
      return ListView.builder(
        itemCount: _profiles.length,
        itemBuilder: (context, index) {
          final profile = _profiles[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  (profile.fullName?.isNotEmpty == true
                          ? profile.fullName![0]
                          : profile.email?[0] ?? 'U')
                      .toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                profile.fullName?.isNotEmpty == true
                    ? profile.fullName!
                    : 'No Name',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email: ${profile.email ?? 'No Email'}'),
                  Text('ID: ${profile.id}'),
                  Text(
                      'Created: ${profile.createdAt.toLocal().toString().split('.')[0]}'),
                ],
              ),
              trailing: Switch(
                value: profile.isActive,
                onChanged: (value) => _toggleProfileStatus(profile),
                activeColor: Colors.green,
              ),
              onTap: () => _navigateToProfileDetail(profile),
              isThreeLine: true,
            ),
          );
        },
      );
    } else {
      // Show country-specific profiles for country admins
      if (_countryProfiles.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                widget.selectedCountry != null
                    ? 'No users found in ${widget.selectedCountry!.name}'
                    : 'Please select a country from the drawer',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        itemCount: _countryProfiles.length,
        itemBuilder: (context, index) {
          return _buildProfileCard(_countryProfiles[index]);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSuperuser && !_isCountryAdmin) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Determine theme colors based on user role
    final backgroundColor =
        _isSuperuser ? Colors.red.shade100 : Colors.orange.shade100;
    final foregroundColor =
        _isSuperuser ? Colors.red.shade800 : Colors.orange.shade800;
    final titleText = _isSuperuser ? 'Profile Management' : 'User Management';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by email or name',
                      hintText: 'Enter email address or name',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _loadProfiles();
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _searchProfiles(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSearching ? null : _searchByEmail,
                          icon: _isSearching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.email),
                          label: const Text('Search by Email'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSearching ? null : _searchProfiles,
                          icon: const Icon(Icons.search),
                          label: const Text('Search All'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _loadProfiles,
                        child: const Text('Show All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            // Results Section
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadProfiles,
                      child: _buildResultsList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
