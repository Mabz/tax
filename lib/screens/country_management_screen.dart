import 'package:flutter/material.dart';
import '../models/country.dart';
import '../services/country_service.dart';
import '../services/role_service.dart';

class CountryManagementScreen extends StatefulWidget {
  const CountryManagementScreen({super.key});

  @override
  State<CountryManagementScreen> createState() =>
      _CountryManagementScreenState();
}

class _CountryManagementScreenState extends State<CountryManagementScreen> {
  List<Country> _countries = [];
  bool _isLoading = true;
  bool _isSuperuser = false;

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

      setState(() {
        _isSuperuser = true;
      });

      await _loadCountries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking permissions: $e')),
        );
      }
    }
  }

  Future<void> _loadCountries() async {
    try {
      setState(() => _isLoading = true);
      final countries = await CountryService.getAllCountries();
      setState(() {
        _countries = countries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading countries: $e')),
        );
      }
    }
  }

  void _showAddCountryDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => _CountryFormDialog(
        onSave: (name, countryCode, revenueServiceName, isActive) async {
          // Capture the ScaffoldMessenger before async operations
          final scaffoldMessenger = ScaffoldMessenger.of(context);

          try {
            await CountryService.createCountry(
              name: name,
              countryCode: countryCode,
              revenueServiceName: revenueServiceName,
              isActive: isActive,
            );
            await _loadCountries();
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Country added successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text('Error adding country: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditCountryDialog(Country country) {
    // Check if this is the Global country - cannot be edited
    if (country.isGlobal) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cannot Edit Global Country'),
          content: Text(
            'The "${country.name}" country cannot be edited as it is a global entry that applies to all countries.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => _CountryFormDialog(
        country: country,
        onSave: (name, countryCode, revenueServiceName, isActive) async {
          // Capture the ScaffoldMessenger before async operations
          final scaffoldMessenger = ScaffoldMessenger.of(context);

          try {
            await CountryService.updateCountry(
              id: country.id,
              name: name,
              countryCode: countryCode,
              revenueServiceName: revenueServiceName,
              isActive: isActive,
            );
            await _loadCountries();
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Country updated successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text('Error updating country: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _toggleCountryStatus(Country country) async {
    // Check if this is the Global country - cannot change status
    if (country.isGlobal) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cannot Change Global Country Status'),
          content: Text(
            'The status of "${country.name}" cannot be changed as it is a global entry that applies to all countries.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Capture the ScaffoldMessenger before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await CountryService.toggleCountryStatus(country.id);
      await _loadCountries();
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Country ${country.isActive ? 'deactivated' : 'activated'} successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error toggling country status: $e')),
        );
      }
    }
  }

  void _deleteCountry(Country country) {
    // Check if this is the Global country - cannot be deleted
    if (country.isGlobal) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cannot Delete Global Country'),
          content: Text(
            'The "${country.name}" country cannot be deleted as it is a global entry that applies to all countries.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Country'),
        content: Text(
            'Are you sure you want to delete ${country.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Capture necessary objects before async operations
              final navigator = Navigator.of(dialogContext);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              navigator.pop(); // Close dialog first

              try {
                await CountryService.deleteCountry(country.id);
                await _loadCountries();
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                        content: Text('Country deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Error deleting country: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSuperuser) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Country Management'),
        backgroundColor: Colors.red.shade100,
        foregroundColor: Colors.red.shade800,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadCountries,
                child: _countries.isEmpty
                    ? const Center(
                        child:
                            Text('No countries found. Add one to get started.'),
                      )
                    : ListView.builder(
                        itemCount: _countries.length,
                        itemBuilder: (context, index) {
                          final country = _countries[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: ListTile(
                              title: Row(
                                children: [
                                  Expanded(child: Text(country.name)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: country.isActive
                                          ? Colors.green.shade100
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: country.isActive
                                            ? Colors.green.shade300
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      country.isActive ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        color: country.isActive
                                            ? Colors.green.shade700
                                            : Colors.grey.shade600,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Code: ${country.countryCode}'),
                                  Text(
                                      'Revenue Service: ${country.revenueServiceName}'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Status toggle button
                                  country.isGlobal
                                      ? Tooltip(
                                          message:
                                              'Global country status is protected',
                                          child: Icon(
                                            Icons.lock,
                                            color: Colors.grey.shade400,
                                          ),
                                        )
                                      : IconButton(
                                          icon: Icon(
                                            country.isActive
                                                ? Icons.toggle_on
                                                : Icons.toggle_off,
                                            color: country.isActive
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                          onPressed: () =>
                                              _toggleCountryStatus(country),
                                          tooltip: country.isActive
                                              ? 'Deactivate'
                                              : 'Activate',
                                        ),
                                  // Edit button
                                  country.isGlobal
                                      ? Tooltip(
                                          message:
                                              'Global country editing is protected',
                                          child: Icon(
                                            Icons.edit_off,
                                            color: Colors.grey.shade400,
                                          ),
                                        )
                                      : IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () =>
                                              _showEditCountryDialog(country),
                                          tooltip: 'Edit',
                                        ),
                                  // Delete button
                                  country.isGlobal
                                      ? Tooltip(
                                          message:
                                              'Global country deletion is protected',
                                          child: Icon(
                                            Icons.delete_forever_outlined,
                                            color: Colors.grey.shade400,
                                          ),
                                        )
                                      : IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _deleteCountry(country),
                                          tooltip: 'Delete',
                                        ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCountryDialog,
        tooltip: 'Add Country',
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CountryFormDialog extends StatefulWidget {
  final Country? country;
  final Future<void> Function(String name, String countryCode,
      String revenueServiceName, bool isActive) onSave;

  const _CountryFormDialog({
    this.country,
    required this.onSave,
  });

  @override
  State<_CountryFormDialog> createState() => _CountryFormDialogState();
}

class _CountryFormDialogState extends State<_CountryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countryCodeController = TextEditingController();
  final _revenueServiceController = TextEditingController();
  bool _isLoading = false;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    if (widget.country != null) {
      _nameController.text = widget.country!.name;
      _countryCodeController.text = widget.country!.countryCode;
      _revenueServiceController.text = widget.country!.revenueServiceName;
      _isActive = widget.country!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryCodeController.dispose();
    _revenueServiceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await widget.onSave(
        _nameController.text.trim(),
        _countryCodeController.text.trim().toUpperCase(),
        _revenueServiceController.text.trim(),
        _isActive,
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.country != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Country' : 'Add Country'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Country Name',
                hintText: 'e.g., South Africa',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Country name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _countryCodeController,
              decoration: const InputDecoration(
                labelText: 'Country Code (ISO 3166-1 alpha-3)',
                hintText: 'e.g., ZAF',
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Country code is required';
                }
                if (!CountryService.isValidCountryCode(
                    value.trim().toUpperCase())) {
                  return 'Must be 3 uppercase letters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _revenueServiceController,
              decoration: const InputDecoration(
                labelText: 'Revenue Service Name',
                hintText: 'e.g., South African Revenue Service',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Revenue service name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text('Enable this country for operations'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
              contentPadding: EdgeInsets.zero,
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
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
