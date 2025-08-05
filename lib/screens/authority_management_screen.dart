/// Authority Management Screen for superusers
/// Allows creation, editing, and management of revenue services and other authorities
library;

import 'package:flutter/material.dart';
import '../models/authority.dart';
import '../models/country.dart';
import '../services/authority_service.dart';
import '../services/country_service.dart';
import '../services/role_service.dart';

class AuthorityManagementScreen extends StatefulWidget {
  const AuthorityManagementScreen({super.key});

  @override
  State<AuthorityManagementScreen> createState() =>
      _AuthorityManagementScreenState();
}

class _AuthorityManagementScreenState extends State<AuthorityManagementScreen> {
  List<Authority> _authorities = [];
  List<Country> _countries = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadData();
  }

  Future<void> _checkPermissionsAndLoadData() async {
    try {
      final isSuperuser = await RoleService.isSuperuser();
      if (!isSuperuser) {
        setState(() {
          _errorMessage = 'Access denied. Superuser role required.';
          _isLoading = false;
        });
        return;
      }

      await _loadData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking permissions: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authorities = await AuthorityService.getAllAuthorities();
      final countries = await CountryService.getAllCountries();

      setState(() {
        _authorities = authorities;
        _countries = countries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  void _showCreateAuthorityDialog() {
    showDialog(
      context: context,
      builder: (context) => _AuthorityDialog(
        countries: _countries,
        onSaved: () {
          Navigator.of(context).pop();
          _loadData();
        },
      ),
    );
  }

  void _showEditAuthorityDialog(Authority authority) {
    showDialog(
      context: context,
      builder: (context) => _AuthorityDialog(
        authority: authority,
        countries: _countries,
        onSaved: () {
          Navigator.of(context).pop();
          _loadData();
        },
      ),
    );
  }

  void _showDeleteConfirmation(Authority authority) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Authority'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this authority?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Authority: ${authority.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Code: ${authority.code}'),
                  Text('Type: ${authority.authorityTypeDisplay}'),
                  Text('Country: ${authority.countryName ?? 'Unknown'}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone and will be audited for compliance purposes.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await AuthorityService.deleteAuthority(authority.id);
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Authority deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting authority: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Authorities'),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _errorMessage == null
          ? FloatingActionButton(
              onPressed: _showCreateAuthorityDialog,
              backgroundColor: Colors.red.shade600,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade600, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkPermissionsAndLoadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_authorities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No authorities found',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first authority to get started',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _authorities.length,
        itemBuilder: (context, index) {
          final authority = _authorities[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    authority.isActive ? Colors.green : Colors.grey,
                child: const Icon(
                  Icons.business,
                  color: Colors.white,
                ),
              ),
              title: Text(
                authority.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Code: ${authority.code}'),
                  Text('Type: ${authority.authorityTypeDisplay}'),
                  Text('Country: ${authority.countryName ?? 'Unknown'}'),
                  Text(
                    'Status: ${authority.statusDisplay}',
                    style: TextStyle(
                      color: authority.isActive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showEditAuthorityDialog(authority);
                      break;
                    case 'delete':
                      _showDeleteConfirmation(authority);
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
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AuthorityDialog extends StatefulWidget {
  final Authority? authority;
  final List<Country> countries;
  final VoidCallback onSaved;

  const _AuthorityDialog({
    this.authority,
    required this.countries,
    required this.onSaved,
  });

  @override
  State<_AuthorityDialog> createState() => _AuthorityDialogState();
}

class _AuthorityDialogState extends State<_AuthorityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _passAdvanceDaysController = TextEditingController();
  final _defaultCurrencyController = TextEditingController();

  Country? _selectedCountry;
  String _selectedAuthorityType = 'revenue_service';
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.authority != null) {
      final authority = widget.authority!;
      _nameController.text = authority.name;
      _codeController.text = authority.code;
      _descriptionController.text = authority.description ?? '';
      _selectedAuthorityType = authority.authorityType;
      _isActive = authority.isActive;
      _passAdvanceDaysController.text = '30'; // Default value
      _defaultCurrencyController.text = ''; // Default empty

      // Find the selected country
      _selectedCountry = widget.countries.firstWhere(
        (country) => country.id == authority.countryId,
        orElse: () => widget.countries.first,
      );
    } else {
      _passAdvanceDaysController.text = '30';
      _selectedCountry =
          widget.countries.isNotEmpty ? widget.countries.first : null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _passAdvanceDaysController.dispose();
    _defaultCurrencyController.dispose();
    super.dispose();
  }

  Future<void> _saveAuthority() async {
    if (!_formKey.currentState!.validate() || _selectedCountry == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final passAdvanceDays =
          int.tryParse(_passAdvanceDaysController.text) ?? 30;
      final defaultCurrency = _defaultCurrencyController.text.trim().isEmpty
          ? null
          : _defaultCurrencyController.text.trim();

      if (widget.authority != null) {
        // Update existing authority
        await AuthorityService.updateAuthority(
          authorityId: widget.authority!.id,
          name: _nameController.text.trim(),
          code: _codeController.text.trim().toUpperCase(),
          authorityType: _selectedAuthorityType,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          passAdvanceDays: passAdvanceDays,
          defaultCurrencyCode: defaultCurrency,
          isActive: _isActive,
        );
      } else {
        // Create new authority
        await AuthorityService.createAuthority(
          countryId: _selectedCountry!.id,
          name: _nameController.text.trim(),
          code: _codeController.text.trim().toUpperCase(),
          authorityType: _selectedAuthorityType,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          passAdvanceDays: passAdvanceDays,
          defaultCurrencyCode: defaultCurrency,
          isActive: _isActive,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.authority != null
                ? 'Authority updated successfully'
                : 'Authority created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving authority: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.authority != null ? 'Edit Authority' : 'Create Authority'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Country Dropdown
                DropdownButtonFormField<Country>(
                  value: _selectedCountry,
                  decoration: const InputDecoration(
                    labelText: 'Country *',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.countries.map((country) {
                    return DropdownMenuItem(
                      value: country,
                      child: Text('${country.name} (${country.countryCode})'),
                    );
                  }).toList(),
                  onChanged: widget.authority == null
                      ? (country) => setState(() => _selectedCountry = country)
                      : null, // Disable for editing
                  validator: (value) =>
                      value == null ? 'Please select a country' : null,
                ),
                const SizedBox(height: 16),

                // Authority Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Authority Name *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., South African Revenue Service',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter authority name';
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
                    border: OutlineInputBorder(),
                    hintText: 'e.g., SARS',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter authority code';
                    }
                    if (value.trim().length < 2) {
                      return 'Code must be at least 2 characters';
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
                  ),
                  items: AuthorityService.getAuthorityTypes().map((type) {
                    return DropdownMenuItem(
                      value: type['value'],
                      child: Text(type['label']!),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => _selectedAuthorityType = value!),
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    hintText: 'Optional description of the authority',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Pass Advance Days
                TextFormField(
                  controller: _passAdvanceDaysController,
                  decoration: const InputDecoration(
                    labelText: 'Pass Advance Days',
                    border: OutlineInputBorder(),
                    hintText: '30',
                  ),
                  keyboardType: TextInputType.number,
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

                // Default Currency
                TextFormField(
                  controller: _defaultCurrencyController,
                  decoration: const InputDecoration(
                    labelText: 'Default Currency Code',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., ZAR, USD',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        value.length != 3) {
                      return 'Currency code must be 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Active Status
                if (widget.authority != null)
                  SwitchListTile(
                    title: const Text('Active Status'),
                    subtitle: Text(_isActive
                        ? 'Authority is active'
                        : 'Authority is inactive'),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                    activeColor: Colors.green,
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveAuthority,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.authority != null ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
