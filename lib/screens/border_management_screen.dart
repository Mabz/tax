import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/border.dart' as border_model;
import '../models/border_type.dart';
import '../services/border_service.dart';
import '../services/border_type_service.dart';
import '../services/country_service.dart';
import '../services/role_service.dart';

class BorderManagementScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedCountry;

  const BorderManagementScreen({super.key, this.selectedCountry});

  @override
  State<BorderManagementScreen> createState() => _BorderManagementScreenState();
}

class _BorderManagementScreenState extends State<BorderManagementScreen> {
  List<Map<String, dynamic>> _countries = [];
  Map<String, dynamic>? _selectedCountry;
  List<border_model.Border> _borders = [];
  List<BorderType> _borderTypes = [];
  bool _isLoading = true;
  bool _isLoadingBorders = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadData();
  }

  Future<void> _checkPermissionsAndLoadData() async {
    try {
      // Check if user is superuser or has country admin role
      final isSuperuser = await RoleService.isSuperuser();
      final hasAdminRole = await RoleService.hasAdminRole();

      if (!isSuperuser && !hasAdminRole) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Access denied. Superuser or country admin role required.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      await _loadCountries();
      await _loadBorderTypes();
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
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

  Future<void> _loadCountries() async {
    try {
      final isSuperuser = await RoleService.isSuperuser();
      List<Map<String, dynamic>> countries;

      if (isSuperuser) {
        // Superusers can see all active countries
        final allCountries = await CountryService.getActiveCountries();
        countries = allCountries
            .map<Map<String, dynamic>>((country) => {
                  AppConstants.fieldId: country.id,
                  AppConstants.fieldCountryName: country.name,
                  AppConstants.fieldCountryCode: country.countryCode,
                  AppConstants.fieldCountryIsActive: country.isActive,
                  AppConstants.fieldCountryIsGlobal: country.isGlobal,
                  AppConstants.fieldCountryRevenueServiceName:
                      country.revenueServiceName,
                  AppConstants.fieldCreatedAt:
                      country.createdAt.toIso8601String(),
                  AppConstants.fieldUpdatedAt:
                      country.updatedAt.toIso8601String(),
                })
            .toList();
      } else {
        // Country admins can only see their assigned countries
        countries = await RoleService.getCountryAdminCountries();
      }

      if (mounted) {
        setState(() {
          _countries = countries;
          if (_countries.isNotEmpty) {
            // Use passed country if available and valid, otherwise use first
            if (widget.selectedCountry != null) {
              // Find the matching country object from the loaded countries list
              final matchingCountry = _countries.firstWhere(
                (c) =>
                    c[AppConstants.fieldId] ==
                    widget.selectedCountry![AppConstants.fieldId],
                orElse: () => _countries.first,
              );
              _selectedCountry = matchingCountry;
            } else {
              _selectedCountry = _countries.first;
            }
            _loadBorders();
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading countries: $e');
      rethrow;
    }
  }

  Future<void> _loadBorderTypes() async {
    try {
      final borderTypes = await BorderTypeService.getAllBorderTypes();
      if (mounted) {
        setState(() {
          _borderTypes = borderTypes;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading border types: $e');
      rethrow;
    }
  }

  Future<void> _loadBorders() async {
    if (_selectedCountry == null) return;

    setState(() {
      _isLoadingBorders = true;
    });

    try {
      final borders = await BorderService.getBordersByCountry(
          _selectedCountry![AppConstants.fieldId]);
      if (mounted) {
        setState(() {
          _borders = borders;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading borders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading borders: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBorders = false;
        });
      }
    }
  }

  void _showAddBorderDialog() {
    if (_selectedCountry == null || _borderTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please select a country and ensure border types are loaded'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _AddEditBorderDialog(
        borderTypes: _borderTypes,
        countryId: _selectedCountry![AppConstants.fieldId],
        onSaved: () {
          _loadBorders();
        },
      ),
    );
  }

  void _showEditBorderDialog(border_model.Border border) {
    showDialog(
      context: context,
      builder: (context) => _AddEditBorderDialog(
        border: border,
        borderTypes: _borderTypes,
        countryId: _selectedCountry![AppConstants.fieldId],
        onSaved: () {
          _loadBorders();
        },
      ),
    );
  }

  void _deleteBorder(border_model.Border border) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Border'),
        content: Text('Are you sure you want to delete "${border.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await BorderService.deleteBorder(border.id);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                        content: Text('Border deleted successfully')),
                  );
                  _loadBorders();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Error deleting border: $e')),
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

  void _toggleBorderStatus(border_model.Border border) async {
    try {
      await BorderService.toggleBorderStatus(border.id, !border.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Border ${border.isActive ? 'deactivated' : 'activated'} successfully',
            ),
          ),
        );
        _loadBorders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating border status: $e')),
        );
      }
    }
  }

  String _getBorderTypeName(String borderTypeId) {
    final borderType = _borderTypes.firstWhere(
      (bt) => bt.id == borderTypeId,
      orElse: () => BorderType(
        id: '',
        code: 'unknown',
        label: 'Unknown',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return borderType.label;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Border Management'),
          backgroundColor: Colors.orange.shade100,
          foregroundColor: Colors.orange.shade800,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_countries.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Border Management'),
          backgroundColor: Colors.orange.shade100,
          foregroundColor: Colors.orange.shade800,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_off,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No Countries Assigned',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You are not assigned as a country administrator for any countries.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Border Management'),
        backgroundColor: Colors.orange.shade100,
        foregroundColor: Colors.orange.shade800,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Show selected country info (read-only)
            if (_selectedCountry != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                color: Colors.orange.shade50,
                child: Row(
                  children: [
                    Icon(Icons.public, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Text(
                      '${_selectedCountry![AppConstants.fieldCountryName]} (${_selectedCountry![AppConstants.fieldCountryCode]})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            // Borders List
            Expanded(
              child: _isLoadingBorders
                  ? const Center(child: CircularProgressIndicator())
                  : _borders.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.border_all,
                                  size: 64,
                                  color: Colors.orange.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Borders Found',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedCountry != null
                                      ? 'No borders have been created for ${_selectedCountry![AppConstants.fieldCountryName]} yet.'
                                      : 'Select a country to view its borders.',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(color: Colors.orange.shade600),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadBorders,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _borders.length,
                            itemBuilder: (context, index) {
                              final border = _borders[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8.0),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: border.isActive
                                        ? Colors.orange.shade100
                                        : Colors.grey.shade100,
                                    child: Icon(
                                      Icons.location_on,
                                      color: border.isActive
                                          ? Colors.orange.shade700
                                          : Colors.grey,
                                    ),
                                  ),
                                  title: Text(
                                    border.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          border.isActive ? null : Colors.grey,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Type: ${_getBorderTypeName(border.borderTypeId)}'),
                                      if (border.description != null)
                                        Text(border.description!),
                                      Text(
                                        'Status: ${border.isActive ? 'Active' : 'Inactive'}',
                                        style: TextStyle(
                                          color: border.isActive
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            _toggleBorderStatus(border),
                                        icon: Icon(
                                          border.isActive
                                              ? Icons.toggle_on
                                              : Icons.toggle_off,
                                          color: border.isActive
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        tooltip: border.isActive
                                            ? 'Deactivate border'
                                            : 'Activate border',
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            _showEditBorderDialog(border),
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue),
                                        tooltip: 'Edit border',
                                      ),
                                      IconButton(
                                        onPressed: () => _deleteBorder(border),
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        tooltip: 'Delete border',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedCountry != null
          ? FloatingActionButton(
              onPressed: _showAddBorderDialog,
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              tooltip: 'Add Border',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _AddEditBorderDialog extends StatefulWidget {
  final border_model.Border? border;
  final List<BorderType> borderTypes;
  final String countryId;
  final VoidCallback onSaved;

  const _AddEditBorderDialog({
    this.border,
    required this.borderTypes,
    required this.countryId,
    required this.onSaved,
  });

  @override
  State<_AddEditBorderDialog> createState() => _AddEditBorderDialogState();
}

class _AddEditBorderDialogState extends State<_AddEditBorderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  BorderType? _selectedBorderType;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.border != null) {
      _nameController.text = widget.border!.name;
      _descriptionController.text = widget.border!.description ?? '';
      _latitudeController.text = widget.border!.latitude?.toString() ?? '';
      _longitudeController.text = widget.border!.longitude?.toString() ?? '';
      _isActive = widget.border!.isActive;

      // Find the selected border type
      _selectedBorderType = widget.borderTypes.firstWhere(
        (bt) => bt.id == widget.border!.borderTypeId,
        orElse: () => widget.borderTypes.first,
      );
    } else {
      _selectedBorderType =
          widget.borderTypes.isNotEmpty ? widget.borderTypes.first : null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _saveBorder() async {
    if (!_formKey.currentState!.validate() || _selectedBorderType == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final latitude = _latitudeController.text.trim().isEmpty
          ? null
          : double.tryParse(_latitudeController.text.trim());
      final longitude = _longitudeController.text.trim().isEmpty
          ? null
          : double.tryParse(_longitudeController.text.trim());

      if (widget.border != null) {
        // Update existing border
        await BorderService.updateBorder(
          id: widget.border!.id,
          name: name,
          borderTypeId: _selectedBorderType!.id,
          isActive: _isActive,
          latitude: latitude,
          longitude: longitude,
          description: description,
        );
      } else {
        // Create new border
        await BorderService.createBorder(
          countryId: widget.countryId,
          name: name,
          borderTypeId: _selectedBorderType!.id,
          isActive: _isActive,
          latitude: latitude,
          longitude: longitude,
          description: description,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.border != null
                  ? 'Border updated successfully'
                  : 'Border created successfully',
            ),
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving border: $e')),
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
      title: Text(widget.border != null ? 'Edit Border' : 'Add Border'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Border Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Border name is required';
                  }
                  if (!BorderService.isValidBorderName(value.trim())) {
                    return 'Border name must be 2-100 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<BorderType>(
                value: _selectedBorderType,
                decoration: const InputDecoration(
                  labelText: 'Border Type *',
                  border: OutlineInputBorder(),
                ),
                items: widget.borderTypes.map((borderType) {
                  return DropdownMenuItem<BorderType>(
                    value: borderType,
                    child: Text(borderType.label),
                  );
                }).toList(),
                onChanged: (BorderType? value) {
                  setState(() {
                    _selectedBorderType = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Border type is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final lat = double.tryParse(value.trim());
                          if (lat == null || lat < -90 || lat > 90) {
                            return 'Invalid latitude (-90 to 90)';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final lng = double.tryParse(value.trim());
                          if (lng == null || lng < -180 || lng > 180) {
                            return 'Invalid longitude (-180 to 180)';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text('Border is available for operations'),
                value: _isActive,
                onChanged: (bool value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveBorder,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(widget.border != null ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
