import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/app_constants.dart';
import '../models/authority.dart';
import '../models/border.dart' as border_model;
import '../models/border_type.dart';
import '../services/authority_service.dart';
import '../services/border_service.dart';
import '../services/border_type_service.dart';
import '../services/role_service.dart';
import '../widgets/platform_location_picker.dart';

class BorderManagementScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedCountry; // For backward compatibility

  const BorderManagementScreen({super.key, this.selectedCountry});

  @override
  State<BorderManagementScreen> createState() => _BorderManagementScreenState();
}

class _BorderManagementScreenState extends State<BorderManagementScreen> {
  List<Authority> _authorities = [];
  Authority? _selectedAuthority;
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

      await _loadAuthorities();
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

  Future<void> _loadAuthorities() async {
    try {
      final isSuperuser = await RoleService.isSuperuser();
      List<Authority> authorities;

      if (isSuperuser) {
        // Superusers can see all authorities
        authorities = await AuthorityService.getAllAuthorities();
      } else {
        // Country admins can only see their assigned authorities
        authorities = await AuthorityService.getAdminAuthorities();
      }

      if (mounted) {
        setState(() {
          _authorities = authorities;
          if (_authorities.isNotEmpty) {
            // Use passed country to find matching authority if available
            if (widget.selectedCountry != null) {
              final countryId = widget.selectedCountry![AppConstants.fieldId];
              // Find authority for the selected country
              final matchingAuthority = _authorities.firstWhere(
                (a) => a.countryId == countryId,
                orElse: () => _authorities.first,
              );
              _selectedAuthority = matchingAuthority;
            } else {
              _selectedAuthority = _authorities.first;
            }
            _loadBorders();
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading authorities: $e');
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
    if (_selectedAuthority == null) return;

    setState(() {
      _isLoadingBorders = true;
    });

    try {
      debugPrint(
          '🔍 Loading borders for authority: ${_selectedAuthority!.name}');

      final borders =
          await BorderService.getBordersByAuthority(_selectedAuthority!.id);

      debugPrint('✅ Loaded ${borders.length} borders');

      if (mounted) {
        setState(() {
          _borders = borders;
          _isLoadingBorders = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading borders: $e');
      if (mounted) {
        setState(() {
          _isLoadingBorders = false;
        });
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
    if (_selectedAuthority == null || _borderTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please select an authority and ensure border types are loaded'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _AddEditBorderDialog(
        borderTypes: _borderTypes,
        authorityId: _selectedAuthority!.id,
        onSave: () {
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
        authorityId: _selectedAuthority!.id,
        onSave: () {
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

  Widget _buildBorderMapPreview(border_model.Border border) {
    // Check if border has valid coordinates
    if (border.latitude == null || border.longitude == null) {
      return Container(
        width: 120,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 28, color: Colors.grey.shade400),
            const SizedBox(height: 6),
            Text(
              'No Location',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 120,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(border.latitude!, border.longitude!),
                zoom: 12,
              ),
              onMapCreated: (GoogleMapController controller) async {
                // Hide all Google Maps UI elements
                const String mapStyle = '''
                [
                  {
                    "featureType": "all",
                    "elementType": "labels",
                    "stylers": [
                      {
                        "visibility": "simplified"
                      }
                    ]
                  }
                ]
                ''';
                controller.setMapStyle(mapStyle);
              },
              markers: {
                Marker(
                  markerId: MarkerId('border_${border.id}'),
                  position: LatLng(border.latitude!, border.longitude!),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    border.isActive
                        ? BitmapDescriptor.hueOrange
                        : BitmapDescriptor.hueRed,
                  ),
                ),
              },
              mapType: MapType.normal,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              indoorViewEnabled: false,
              trafficEnabled: false,
              buildingsEnabled: false,
              liteModeEnabled: true,
              fortyFiveDegreeImageryEnabled: false,
            ),

            // Status overlay
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: border.isActive
                      ? Colors.green.withOpacity(0.9)
                      : Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  border.isActive ? 'ON' : 'OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Borders'),
          backgroundColor: Colors.orange.shade100,
          foregroundColor: Colors.orange.shade800,
        ),
        body: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_authorities.isEmpty) {
      return Scaffold(
          appBar: AppBar(
            title: const Text('Borders'),
            backgroundColor: Colors.orange.shade100,
            foregroundColor: Colors.orange.shade800,
          ),
          body: const SafeArea(
            child: Center(
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
                      'No Authorities Assigned',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You are not assigned as an administrator for any authorities.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borders'),
        backgroundColor: Colors.orange.shade100,
        foregroundColor: Colors.orange.shade800,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Show selected authority info (read-only)
            if (_selectedAuthority != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                color: Colors.orange.shade50,
                child: Row(
                  children: [
                    Icon(
                      Icons.business,
                      color: Colors.orange.shade800,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedAuthority!.name,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_selectedAuthority!.countryName != null)
                            Text(
                              '${_selectedAuthority!.countryName} (${_selectedAuthority!.countryCode ?? ''})',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade600,
                              ),
                            ),
                        ],
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
                                  _selectedAuthority != null
                                      ? 'No borders have been created for ${_selectedAuthority!.name} yet.'
                                      : 'Select an authority to view its borders.',
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
                                margin: const EdgeInsets.only(bottom: 12.0),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Map preview
                                      _buildBorderMapPreview(border),
                                      const SizedBox(width: 16),

                                      // Border details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Title and status
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    border.name,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: border.isActive
                                                          ? null
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: border.isActive
                                                        ? Colors.green.shade100
                                                        : Colors.red.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Text(
                                                    border.isActive
                                                        ? 'Active'
                                                        : 'Inactive',
                                                    style: TextStyle(
                                                      color: border.isActive
                                                          ? Colors
                                                              .green.shade700
                                                          : Colors.red.shade700,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),

                                            // Border type
                                            Text(
                                              'Type: ${_getBorderTypeName(border.borderTypeId)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey,
                                              ),
                                            ),

                                            // Description
                                            if (border.description != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                border.description!,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],

                                            const SizedBox(height: 8),

                                            // Schedule info
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.schedule_outlined,
                                                  size: 16,
                                                  color: border
                                                          .allowOutOfScheduleScans
                                                      ? Colors.orange.shade600
                                                      : Colors.grey.shade400,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    border.allowOutOfScheduleScans
                                                        ? 'Out-of-schedule scans allowed'
                                                        : 'Schedule enforcement active',
                                                    style: TextStyle(
                                                      color: border
                                                              .allowOutOfScheduleScans
                                                          ? Colors
                                                              .orange.shade600
                                                          : Colors
                                                              .grey.shade600,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 12),

                                            // Action buttons
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                TextButton.icon(
                                                  onPressed: () =>
                                                      _showEditBorderDialog(
                                                          border),
                                                  icon: const Icon(Icons.edit,
                                                      size: 16),
                                                  label: const Text('Edit'),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.orange,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                TextButton.icon(
                                                  onPressed: () =>
                                                      _deleteBorder(border),
                                                  icon: const Icon(Icons.delete,
                                                      size: 16),
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
      floatingActionButton: _selectedAuthority != null
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
  final String authorityId;
  final VoidCallback onSave;

  const _AddEditBorderDialog({
    this.border,
    required this.borderTypes,
    required this.authorityId,
    required this.onSave,
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
  bool _allowOutOfScheduleScans = false;
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
      _allowOutOfScheduleScans = widget.border!.allowOutOfScheduleScans;

      // Find the selected border type
      _selectedBorderType = widget.borderTypes.firstWhere(
        (bt) => bt.id == widget.border!.borderTypeId,
        orElse: () => widget.borderTypes.first,
      );
    } else {
      _selectedBorderType =
          widget.borderTypes.isNotEmpty ? widget.borderTypes.first : null;
    }

    // Add listeners to update map preview when coordinates change
    _latitudeController.addListener(_updateMapPreview);
    _longitudeController.addListener(_updateMapPreview);
    _nameController.addListener(_updateMapPreview);
  }

  void _updateMapPreview() {
    // Trigger a rebuild to update the map preview
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _latitudeController.removeListener(_updateMapPreview);
    _longitudeController.removeListener(_updateMapPreview);
    _nameController.removeListener(_updateMapPreview);
    _nameController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _selectLocationOnMap() {
    // Get current location if available
    LatLng? initialLocation;
    if (_latitudeController.text.isNotEmpty &&
        _longitudeController.text.isNotEmpty) {
      final lat = double.tryParse(_latitudeController.text);
      final lng = double.tryParse(_longitudeController.text);
      if (lat != null && lng != null) {
        initialLocation = LatLng(lat, lng);
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlatformLocationPicker(
          initialLocation: initialLocation,
          title: 'Select Border Location',
          onLocationSelected: (LatLng location, String? address) {
            setState(() {
              _latitudeController.text = location.latitude.toStringAsFixed(6);
              _longitudeController.text = location.longitude.toStringAsFixed(6);
            });

            // Show confirmation with address if available
            if (address != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Location selected: $address'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ),
    );
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
          allowOutOfScheduleScans: _allowOutOfScheduleScans,
        );
      } else {
        // Create new border using the authority ID directly
        await BorderService.createBorder(
          authorityId: widget.authorityId,
          name: name,
          borderTypeId: _selectedBorderType!.id,
          isActive: _isActive,
          latitude: latitude,
          longitude: longitude,
          description: description,
          allowOutOfScheduleScans: _allowOutOfScheduleScans,
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
        widget.onSave();
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
              // Location section with map integration
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with icon and title
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Map selection button - full width
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selectLocationOnMap,
                        icon: const Icon(Icons.map, size: 20),
                        label: const Text('Select Location on Map'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Coordinate input fields
                    const Text(
                      'Coordinates (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitudeController,
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                final lat = double.tryParse(value.trim());
                                if (lat == null || lat < -90 || lat > 90) {
                                  return 'Invalid latitude';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _longitudeController,
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                final lng = double.tryParse(value.trim());
                                if (lng == null || lng < -180 || lng > 180) {
                                  return 'Invalid longitude';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    // Map preview
                    const SizedBox(height: 16),
                    _buildLocationPreview(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Allow Out-of-Schedule Scans'),
                subtitle: const Text(
                    'Allow border officials to scan passes outside their scheduled time slots'),
                value: _allowOutOfScheduleScans,
                onChanged: (bool value) {
                  setState(() {
                    _allowOutOfScheduleScans = value;
                  });
                },
                secondary: Icon(
                  Icons.schedule_outlined,
                  color: _allowOutOfScheduleScans
                      ? Colors.orange.shade600
                      : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 8),
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

  Widget _buildLocationPreview() {
    final latText = _latitudeController.text.trim();
    final lngText = _longitudeController.text.trim();

    if (latText.isEmpty || lngText.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 32, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'Location Preview',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select location to see preview',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);

    if (lat == null ||
        lng == null ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 32, color: Colors.red.shade400),
              const SizedBox(height: 8),
              Text(
                'Invalid Coordinates',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Please check latitude and longitude values',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(lat, lng),
                zoom: 14,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('border_location'),
                  position: LatLng(lat, lng),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange),
                  infoWindow: InfoWindow(
                    title: _nameController.text.isNotEmpty
                        ? _nameController.text
                        : 'Border Location',
                    snippet:
                        'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}',
                  ),
                ),
              },
              mapType: MapType.normal,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
            ),

            // Tap overlay to open full location picker
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _selectLocationOnMap,
                  child: Container(),
                ),
              ),
            ),

            // Overlay with location info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _nameController.text.isNotEmpty
                                ? _nameController.text
                                : 'Border Location',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              const Text(
                                'Tap to Edit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
