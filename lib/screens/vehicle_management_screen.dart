import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/vehicle.dart';
import '../models/country.dart';
import '../services/vehicle_service.dart';
import '../services/country_service.dart';

class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  State<VehicleManagementScreen> createState() =>
      _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  List<Vehicle> _vehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      setState(() => _isLoading = true);
      final vehicles = await VehicleService.getVehiclesForUser();
      setState(() {
        _vehicles = vehicles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading vehicles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showVehicleDialog({Vehicle? vehicle}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => VehicleDialog(vehicle: vehicle),
    );

    if (result == true) {
      // Force refresh the vehicle list
      await _loadVehicles();
    }
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this vehicle?'),
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
                    vehicle.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Registration: ${vehicle.displayRegistration}'),
                  if (vehicle.vinNumber != null) ...[
                    const SizedBox(height: 4),
                    Text('VIN: ${vehicle.vinNumber}'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await VehicleService.deleteVehicle(vehicle.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadVehicles();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting vehicle: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicles'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _vehicles.isEmpty
                ? _buildEmptyState()
                : _buildVehicleList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showVehicleDialog(),
        backgroundColor: Colors.blue.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No vehicles registered',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first vehicle to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showVehicleDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Vehicle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleList() {
    return RefreshIndicator(
      onRefresh: _loadVehicles,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _vehicles.length,
        itemBuilder: (context, index) {
          final vehicle = _vehicles[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showVehicleDialog(vehicle: vehicle),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with vehicle name and menu
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getVehicleIcon(vehicle.vehicleType),
                            color: Colors.blue.shade600,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicle.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              if (vehicle.color != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color:
                                            _getColorFromName(vehicle.color!),
                                        borderRadius: BorderRadius.circular(2),
                                        border: Border.all(
                                          color: Colors.grey.shade400,
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      vehicle.color!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _showVehicleDialog(vehicle: vehicle);
                                break;
                              case 'delete':
                                _deleteVehicle(vehicle);
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
                                  Icon(Icons.delete,
                                      size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Vehicle details in organized sections
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: _buildVehicleDetails(vehicle),
                    ),

                    const SizedBox(height: 12),

                    // Footer with country and date
                    Row(
                      children: [
                        if (vehicle.countryOfRegistrationName != null) ...[
                          Icon(
                            Icons.flag,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            vehicle.countryOfRegistrationName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const Spacer(),
                        ],
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Added ${_formatDate(vehicle.createdAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
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

  Widget _buildVehicleDetails(Vehicle vehicle) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use single column layout on mobile (width < 600)
        final isMobile = constraints.maxWidth < 600;

        return Column(
          children: [
            // Registration and VIN
            if (isMobile) ...[
              _buildDetailItem(
                Icons.confirmation_num,
                'Registration',
                vehicle.displayRegistration,
              ),
              const SizedBox(height: 12),
              _buildDetailItem(
                Icons.fingerprint,
                'VIN',
                vehicle.vinNumber ?? 'Not provided',
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      Icons.confirmation_num,
                      'Registration',
                      vehicle.displayRegistration,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailItem(
                      Icons.fingerprint,
                      'VIN',
                      vehicle.vinNumber ?? 'Not provided',
                    ),
                  ),
                ],
              ),
            ],

            // Body Type and Fuel Type
            if (vehicle.bodyType != null || vehicle.fuelType != null) ...[
              const SizedBox(height: 12),
              if (isMobile) ...[
                if (vehicle.bodyType != null) ...[
                  _buildDetailItem(
                    Icons.directions_car_filled,
                    'Body Type',
                    vehicle.bodyType!,
                  ),
                  if (vehicle.fuelType != null) const SizedBox(height: 12),
                ],
                if (vehicle.fuelType != null)
                  _buildDetailItem(
                    Icons.local_gas_station,
                    'Fuel',
                    vehicle.fuelType!,
                  ),
              ] else ...[
                Row(
                  children: [
                    if (vehicle.bodyType != null)
                      Expanded(
                        child: _buildDetailItem(
                          Icons.directions_car_filled,
                          'Body Type',
                          vehicle.bodyType!,
                        ),
                      ),
                    if (vehicle.bodyType != null && vehicle.fuelType != null)
                      const SizedBox(width: 16),
                    if (vehicle.fuelType != null)
                      Expanded(
                        child: _buildDetailItem(
                          Icons.local_gas_station,
                          'Fuel',
                          vehicle.fuelType!,
                        ),
                      ),
                  ],
                ),
              ],
            ],

            // Transmission and Engine
            if (vehicle.transmission != null ||
                vehicle.engineCapacity != null) ...[
              const SizedBox(height: 12),
              if (isMobile) ...[
                if (vehicle.transmission != null) ...[
                  _buildDetailItem(
                    Icons.settings,
                    'Transmission',
                    vehicle.transmission!,
                  ),
                  if (vehicle.engineCapacity != null)
                    const SizedBox(height: 12),
                ],
                if (vehicle.engineCapacity != null)
                  _buildDetailItem(
                    Icons.speed,
                    'Engine',
                    '${vehicle.engineCapacity}L',
                  ),
              ] else ...[
                Row(
                  children: [
                    if (vehicle.transmission != null)
                      Expanded(
                        child: _buildDetailItem(
                          Icons.settings,
                          'Transmission',
                          vehicle.transmission!,
                        ),
                      ),
                    if (vehicle.transmission != null &&
                        vehicle.engineCapacity != null)
                      const SizedBox(width: 16),
                    if (vehicle.engineCapacity != null)
                      Expanded(
                        child: _buildDetailItem(
                          Icons.speed,
                          'Engine',
                          '${vehicle.engineCapacity}L',
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getVehicleIcon(String? vehicleType) {
    switch (vehicleType?.toLowerCase()) {
      case 'suv':
        return Icons.directions_car;
      case 'truck':
        return Icons.local_shipping;
      case 'van':
        return Icons.airport_shuttle;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'bus':
        return Icons.directions_bus;
      case 'pickup':
        return Icons.local_shipping;
      default:
        return Icons.directions_car;
    }
  }

  Color _getColorFromName(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'white':
        return Colors.white;
      case 'black':
        return Colors.black;
      case 'silver':
        return Colors.grey.shade300;
      case 'gray':
      case 'grey':
        return Colors.grey;
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'orange':
        return Colors.orange;
      case 'brown':
        return Colors.brown;
      case 'purple':
        return Colors.purple;
      case 'pink':
        return Colors.pink;
      case 'gold':
        return Colors.amber.shade600;
      case 'beige':
        return Colors.brown.shade100;
      case 'maroon':
        return Colors.red.shade900;
      case 'navy':
        return Colors.blue.shade900;
      default:
        return Colors.grey.shade400;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final difference = today.difference(dateOnly).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
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

class VehicleDialog extends StatefulWidget {
  final Vehicle? vehicle;

  const VehicleDialog({super.key, this.vehicle});

  @override
  State<VehicleDialog> createState() => _VehicleDialogState();
}

class _VehicleDialogState extends State<VehicleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _registrationController = TextEditingController();
  final _vinController = TextEditingController();
  final _engineCapacityController = TextEditingController();

  String? _selectedColor;
  String? _selectedVehicleType;
  String? _selectedBodyType;
  String? _selectedFuelType;
  String? _selectedTransmission;
  String? _selectedCountryId;

  List<Country> _countries = [];
  bool _isLoading = false;
  bool _isLoadingCountries = true;

  @override
  void initState() {
    super.initState();
    _loadCountries();
    if (widget.vehicle != null) {
      _populateFields();
    }
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await CountryService.getActiveCountries();
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

  void _populateFields() {
    final vehicle = widget.vehicle!;
    _makeController.text = vehicle.make ?? '';
    _modelController.text = vehicle.model ?? '';
    _yearController.text = vehicle.year?.toString() ?? '';
    _registrationController.text =
        vehicle.registrationNumber ?? vehicle.numberPlate ?? '';
    _vinController.text = vehicle.vinNumber ?? '';
    _engineCapacityController.text = vehicle.engineCapacity?.toString() ?? '';

    _selectedColor = vehicle.color;
    _selectedVehicleType = vehicle.vehicleType;
    _selectedBodyType = vehicle.bodyType;
    _selectedFuelType = vehicle.fuelType;
    _selectedTransmission = vehicle.transmission;
    _selectedCountryId = vehicle.countryOfRegistrationId;
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _registrationController.dispose();
    _vinController.dispose();
    _engineCapacityController.dispose();
    super.dispose();
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final make = _makeController.text.trim();
      final model = _modelController.text.trim();
      final year = int.parse(_yearController.text.trim());
      final color = _selectedColor!;
      final registrationNumber = _registrationController.text.trim().isEmpty
          ? null
          : _registrationController.text.trim();
      final vinNumber = _vinController.text.trim();
      final engineCapacity = _engineCapacityController.text.trim().isEmpty
          ? null
          : double.tryParse(_engineCapacityController.text.trim());

      if (widget.vehicle == null) {
        // Create new vehicle
        await VehicleService.createVehicle(
          make: make,
          model: model,
          year: year,
          color: color,
          vinNumber: vinNumber,
          bodyType: _selectedBodyType,
          fuelType: _selectedFuelType,
          transmission: _selectedTransmission,
          engineCapacity: engineCapacity,
          registrationNumber: registrationNumber,
          countryOfRegistrationId: _selectedCountryId,
          vehicleType: _selectedVehicleType ?? 'Car',
        );
      } else {
        // Update existing vehicle
        await VehicleService.updateVehicle(
          vehicleId: widget.vehicle!.id,
          make: make,
          model: model,
          year: year,
          color: color,
          vinNumber: vinNumber,
          bodyType: _selectedBodyType,
          fuelType: _selectedFuelType,
          transmission: _selectedTransmission,
          engineCapacity: engineCapacity,
          registrationNumber: registrationNumber,
          countryOfRegistrationId: _selectedCountryId,
        );
      }

      if (mounted) {
        // Add a small delay to ensure database update completes
        await Future.delayed(const Duration(milliseconds: 500));

        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.vehicle == null
                  ? 'Vehicle added successfully'
                  : 'Vehicle updated successfully',
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
            content: Text('Error saving vehicle: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: _isLoadingCountries
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Basic Information Section
                      _buildSectionHeader('Basic Information'),
                      const SizedBox(height: 12),

                      _buildResponsiveFormRow([
                        TextFormField(
                          controller: _makeController,
                          decoration: const InputDecoration(
                            labelText: 'Make *',
                            hintText: 'e.g., Toyota',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Make is required';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: _modelController,
                          decoration: const InputDecoration(
                            labelText: 'Model *',
                            hintText: 'e.g., Camry',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Model is required';
                            }
                            return null;
                          },
                        ),
                      ]),
                      const SizedBox(height: 16),

                      _buildResponsiveFormRow([
                        TextFormField(
                          controller: _yearController,
                          decoration: const InputDecoration(
                            labelText: 'Year *',
                            hintText: 'e.g., 2020',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Year is required';
                            }
                            final year = int.tryParse(value);
                            if (year == null ||
                                year < 1900 ||
                                year > DateTime.now().year + 1) {
                              return 'Enter a valid year';
                            }
                            return null;
                          },
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedColor,
                          decoration: const InputDecoration(
                            labelText: 'Color *',
                            border: OutlineInputBorder(),
                          ),
                          items: VehicleConstants.colors.map((color) {
                            return DropdownMenuItem(
                              value: color,
                              child: Text(color),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedColor = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Color is required';
                            }
                            return null;
                          },
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // Registration Section
                      _buildSectionHeader('Registration'),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _registrationController,
                        decoration: const InputDecoration(
                          labelText: 'Registration Number',
                          hintText: 'e.g., ABC-123',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _selectedCountryId,
                        decoration: const InputDecoration(
                          labelText: 'Country of Registration',
                          border: OutlineInputBorder(),
                        ),
                        items: _countries.map((country) {
                          return DropdownMenuItem(
                            value: country.id,
                            child: Text(country.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCountryId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Vehicle Details Section
                      _buildSectionHeader('Vehicle Details'),
                      const SizedBox(height: 12),

                      _buildResponsiveFormRow([
                        DropdownButtonFormField<String>(
                          value: _selectedVehicleType,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Type',
                            border: OutlineInputBorder(),
                          ),
                          items: VehicleConstants.vehicleTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedVehicleType = value;
                            });
                          },
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedBodyType,
                          decoration: const InputDecoration(
                            labelText: 'Body Type',
                            border: OutlineInputBorder(),
                          ),
                          items: VehicleConstants.bodyTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBodyType = value;
                            });
                          },
                        ),
                      ]),
                      const SizedBox(height: 16),

                      _buildResponsiveFormRow([
                        DropdownButtonFormField<String>(
                          value: _selectedFuelType,
                          decoration: const InputDecoration(
                            labelText: 'Fuel Type',
                            border: OutlineInputBorder(),
                          ),
                          items: VehicleConstants.fuelTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedFuelType = value;
                            });
                          },
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedTransmission,
                          decoration: const InputDecoration(
                            labelText: 'Transmission',
                            border: OutlineInputBorder(),
                          ),
                          items: VehicleConstants.transmissionTypes.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTransmission = value;
                            });
                          },
                        ),
                      ]),
                      const SizedBox(height: 16),

                      _buildResponsiveFormRow([
                        TextFormField(
                          controller: _engineCapacityController,
                          decoration: const InputDecoration(
                            labelText: 'Engine Capacity (L)',
                            hintText: 'e.g., 2.0',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*')),
                          ],
                        ),
                        TextFormField(
                          controller: _vinController,
                          decoration: const InputDecoration(
                            labelText: 'VIN Number *',
                            hintText: 'Vehicle Identification Number',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'VIN number is required';
                            }
                            if (value.trim().length < 17) {
                              return 'VIN must be 17 characters';
                            }
                            return null;
                          },
                        ),
                      ]),
                      const SizedBox(height: 16),

                      Text(
                        '* Required fields',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
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
          onPressed: _isLoading ? null : _saveVehicle,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
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
              : Text(widget.vehicle == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }

  Widget _buildResponsiveFormRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use single column layout on mobile (width < 600)
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Column(
            children: children
                .map((child) => Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: child,
                    ))
                .toList(),
          );
        } else {
          return Row(
            children: children
                .map((child) => Expanded(child: child))
                .expand((widget) => [widget, const SizedBox(width: 12)])
                .take(children.length * 2 - 1)
                .toList(),
          );
        }
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            color: Colors.blue.shade200,
            thickness: 1,
          ),
        ),
      ],
    );
  }
}
