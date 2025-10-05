import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pass_template.dart';
import '../models/vehicle_tax_rate.dart';
import '../models/vehicle_type.dart';
import '../models/border.dart' as border_model;
import '../models/currency.dart';
import '../models/authority.dart';
import '../services/pass_template_service.dart';
import '../services/authority_service.dart';

class PassTemplateFormScreen extends StatefulWidget {
  final String authorityId;
  final String authorityName;
  final PassTemplate? template;

  const PassTemplateFormScreen({
    super.key,
    required this.authorityId,
    required this.authorityName,
    this.template,
  });

  @override
  State<PassTemplateFormScreen> createState() => _PassTemplateFormScreenState();
}

class _PassTemplateFormScreenState extends State<PassTemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _entryLimitController = TextEditingController();
  final _expirationDaysController = TextEditingController();
  final _passAdvanceDaysController = TextEditingController();
  final _taxAmountController = TextEditingController();

  // Dropdown selections
  String? _selectedTaxRateId;
  String? _selectedVehicleTypeId;
  String? _selectedEntryPointId;
  String? _selectedExitPointId;
  String? _selectedCurrencyCode;

  // Switches
  bool _isActive = true;
  bool _allowUserSelectableEntryPoint = false;
  bool _allowUserSelectableExitPoint = false;

  // Loading states
  bool _isLoading = true;
  bool _isSaving = false;

  // Data lists
  List<VehicleTaxRate> _taxRates = [];
  List<VehicleType> _vehicleTypes = [];
  List<border_model.Border> _borders = [];
  List<Currency> _currencies = [];
  Authority? _authority;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final results = await Future.wait([
        PassTemplateService.getTaxRatesForAuthority(widget.authorityId),
        PassTemplateService.getVehicleTypes(),
        PassTemplateService.getBordersForAuthority(widget.authorityId),
        PassTemplateService.getActiveCurrencies(),
        AuthorityService.getAuthorityById(widget.authorityId),
      ]);

      setState(() {
        _taxRates = results[0] as List<VehicleTaxRate>;
        _vehicleTypes = results[1] as List<VehicleType>;
        _borders = results[2] as List<border_model.Border>;
        _currencies = results[3] as List<Currency>;
        _authority = results[4] as Authority?;
        _isLoading = false;
      });

      _initializeFields();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _initializeFields() {
    if (widget.template != null) {
      final template = widget.template!;
      _descriptionController.text = template.description;
      _entryLimitController.text = template.entryLimit.toString();
      _expirationDaysController.text = template.expirationDays.toString();
      _passAdvanceDaysController.text = template.passAdvanceDays.toString();
      _taxAmountController.text = template.taxAmount.toString();

      // Validate and set dropdown values only if they exist in the available options
      _selectedVehicleTypeId =
          _vehicleTypes.any((vt) => vt.id == template.vehicleTypeId)
              ? template.vehicleTypeId
              : null;

      _selectedEntryPointId = template.entryPointId != null &&
              _borders.any((b) => b.id == template.entryPointId)
          ? template.entryPointId
          : null;

      _selectedExitPointId = template.exitPointId != null &&
              _borders.any((b) => b.id == template.exitPointId)
          ? template.exitPointId
          : null;

      _selectedCurrencyCode =
          _currencies.any((c) => c.code == template.currencyCode)
              ? template.currencyCode
              : null;

      // If currency wasn't found, set a default
      if (_selectedCurrencyCode == null) {
        _setDefaultCurrency();
      }

      // Find matching tax rate if it exists
      _selectedTaxRateId = _taxRates.any((rate) =>
              rate.vehicleType.toLowerCase() ==
                  _getVehicleTypeLabel(_selectedVehicleTypeId).toLowerCase() &&
              rate.taxAmount == template.taxAmount &&
              rate.currency == template.currencyCode)
          ? _taxRates
              .firstWhere((rate) =>
                  rate.vehicleType.toLowerCase() ==
                      _getVehicleTypeLabel(_selectedVehicleTypeId)
                          .toLowerCase() &&
                  rate.taxAmount == template.taxAmount &&
                  rate.currency == template.currencyCode)
              .id
          : null;

      _isActive = template.isActive;
      _allowUserSelectableEntryPoint = template.allowUserSelectableEntryPoint;
      _allowUserSelectableExitPoint = template.allowUserSelectableExitPoint;

      // Debug logging to help identify dropdown issues
      debugPrint('🔍 Template editing - Dropdown values:');
      debugPrint(
          '  - Vehicle Type ID: $_selectedVehicleTypeId (available: ${_vehicleTypes.map((vt) => vt.id).toList()})');
      debugPrint(
          '  - Currency Code: $_selectedCurrencyCode (available: ${_currencies.map((c) => c.code).toList()})');
      debugPrint(
          '  - Entry Point ID: $_selectedEntryPointId (available: ${_borders.map((b) => b.id).toList()})');
      debugPrint('  - Exit Point ID: $_selectedExitPointId');
      debugPrint(
          '  - Tax Rate ID: $_selectedTaxRateId (available: ${_taxRates.map((r) => r.id).toList()})');

      // Validate all dropdown values are either null or exist in their respective lists
      if (_selectedVehicleTypeId != null &&
          !_vehicleTypes.any((vt) => vt.id == _selectedVehicleTypeId)) {
        debugPrint('⚠️ Invalid vehicle type ID: $_selectedVehicleTypeId');
        _selectedVehicleTypeId = null;
      }
      if (_selectedCurrencyCode != null &&
          !_currencies.any((c) => c.code == _selectedCurrencyCode)) {
        debugPrint('⚠️ Invalid currency code: $_selectedCurrencyCode');
        _selectedCurrencyCode = null;
      }
      if (_selectedEntryPointId != null &&
          !_borders.any((b) => b.id == _selectedEntryPointId)) {
        debugPrint('⚠️ Invalid entry point ID: $_selectedEntryPointId');
        _selectedEntryPointId = null;
      }
      if (_selectedExitPointId != null &&
          !_borders.any((b) => b.id == _selectedExitPointId)) {
        debugPrint('⚠️ Invalid exit point ID: $_selectedExitPointId');
        _selectedExitPointId = null;
      }
      if (_selectedTaxRateId != null &&
          !_taxRates.any((r) => r.id == _selectedTaxRateId)) {
        debugPrint('⚠️ Invalid tax rate ID: $_selectedTaxRateId');
        _selectedTaxRateId = null;
      }
    } else {
      // Set defaults for new template
      _entryLimitController.text = '1'; // Default to 1 entry
      _expirationDaysController.text = '30';

      // Get advance days from authority or use default
      final authorityAdvanceDays = _authority?.defaultPassAdvanceDays ?? 7;
      _passAdvanceDaysController.text = authorityAdvanceDays.toString();

      _taxAmountController.text = '0.00';

      // Set default currency from authority
      _setDefaultCurrency();

      // Auto-generate description when vehicle type is selected
      _updateDescription();
    }
  }

  void _setDefaultCurrency() {
    if (_currencies.isEmpty) return;

    // First try to use authority's default currency
    if (_authority?.defaultCurrencyCode != null) {
      try {
        final authorityCurrency = _currencies.firstWhere(
          (currency) => currency.code == _authority!.defaultCurrencyCode,
        );
        _selectedCurrencyCode = authorityCurrency.code;
        debugPrint(
            '✅ Using authority default currency: ${authorityCurrency.code}');
        return;
      } catch (e) {
        debugPrint(
            '⚠️ Authority default currency not found in available currencies: ${_authority!.defaultCurrencyCode}');
      }
    }

    // Fallback to common currencies (USD, EUR, or first available)
    Currency? defaultCurrency;

    // First try USD
    try {
      defaultCurrency =
          _currencies.firstWhere((currency) => currency.code == 'USD');
    } catch (e) {
      // If USD not found, try EUR
      try {
        defaultCurrency =
            _currencies.firstWhere((currency) => currency.code == 'EUR');
      } catch (e) {
        // If neither found, use first available
        defaultCurrency = _currencies.first;
      }
    }

    _selectedCurrencyCode = defaultCurrency.code;
    debugPrint('✅ Using fallback currency: ${defaultCurrency.code}');
  }

  void _updateDescription() {
    // Auto-generate description based on form data
    if (_descriptionController.text.isEmpty || _shouldAutoUpdateDescription()) {
      final parts = <String>[];

      // Add vehicle type
      if (_selectedVehicleTypeId != null) {
        final vehicleType = _vehicleTypes.firstWhere(
          (vt) => vt.id == _selectedVehicleTypeId,
          orElse: () => VehicleType(
            id: '',
            label: 'Vehicle',
            description: '',
            isActive: true,
          ),
        );
        parts.add(vehicleType.label);
      }

      // Add entry limit info
      final entryLimit = int.tryParse(_entryLimitController.text) ?? 1;
      if (entryLimit == 1) {
        parts.add('Single Entry');
      } else if (entryLimit > 1) {
        parts.add('$entryLimit Entries');
      } else {
        parts.add('Unlimited Entry');
      }

      // Add route info (entry/exit points)
      String routeInfo = '';
      if (!_allowUserSelectableEntryPoint && !_allowUserSelectableExitPoint) {
        final entryPoint = _selectedEntryPointId != null
            ? _borders
                .firstWhere(
                  (b) => b.id == _selectedEntryPointId,
                  orElse: () => border_model.Border(
                    id: '',
                    name: 'Unknown',
                    authorityId: '',
                    borderTypeId: '',
                    isActive: true,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                )
                .name
            : null;

        final exitPoint = _selectedExitPointId != null
            ? _borders
                .firstWhere(
                  (b) => b.id == _selectedExitPointId,
                  orElse: () => border_model.Border(
                    id: '',
                    name: 'Unknown',
                    authorityId: '',
                    borderTypeId: '',
                    isActive: true,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                )
                .name
            : null;

        if (entryPoint != null && exitPoint != null) {
          routeInfo = '$entryPoint to $exitPoint';
        } else if (entryPoint != null) {
          routeInfo = 'from $entryPoint';
        } else if (exitPoint != null) {
          routeInfo = 'to $exitPoint';
        }
      } else if (_allowUserSelectableEntryPoint &&
          _allowUserSelectableExitPoint) {
        routeInfo = 'User Selected Route';
      } else if (_allowUserSelectableEntryPoint) {
        routeInfo = 'User Selected Entry Point';
      } else if (_allowUserSelectableExitPoint) {
        routeInfo = 'User Selected Exit Point';
      }

      if (routeInfo.isNotEmpty) {
        parts.add(routeInfo);
      }

      // Add authority code
      final authorityCode = _authority?.code ?? widget.authorityName;
      parts.add(authorityCode);

      // Join parts with appropriate separators
      String description = '';
      if (parts.length >= 2) {
        description = '${parts[0]} Pass';
        if (parts.length > 2) {
          description += ' (${parts.sublist(1, parts.length - 1).join(', ')})';
        }
        description += ' - ${parts.last}';
      } else if (parts.isNotEmpty) {
        description = '${parts[0]} Pass';
      } else {
        description = 'Pass Template';
      }

      _descriptionController.text = description;
      debugPrint('✅ Auto-generated description: $description');
    }
  }

  bool _shouldAutoUpdateDescription() {
    // Check if current description looks auto-generated
    final currentDesc = _descriptionController.text;
    return currentDesc.contains('Pass') &&
        (currentDesc.contains(_authority?.code ?? widget.authorityName) ||
            currentDesc.contains(widget.authorityName));
  }

  String _getVehicleTypeLabel(String? vehicleTypeId) {
    if (vehicleTypeId == null) return '';
    return _vehicleTypes
        .firstWhere(
          (vt) => vt.id == vehicleTypeId,
          orElse: () => VehicleType(
            id: '',
            label: '',
            description: '',
            isActive: true,
          ),
        )
        .label;
  }

  void _onTaxRateSelected(String? taxRateId) {
    if (taxRateId == null) return;

    final selectedRate = _taxRates.firstWhere((rate) => rate.id == taxRateId);

    // Find matching vehicle type
    final matchingVehicleType = _vehicleTypes.firstWhere(
      (vt) => vt.label.toLowerCase() == selectedRate.vehicleType.toLowerCase(),
      orElse: () => VehicleType(
        id: '',
        label: '',
        description: '',
        isActive: true,
      ),
    );

    setState(() {
      _selectedTaxRateId = taxRateId;
      _taxAmountController.text = selectedRate.taxAmount.toString();
      _selectedCurrencyCode = selectedRate.currency;
      if (matchingVehicleType.id.isNotEmpty) {
        _selectedVehicleTypeId = matchingVehicleType.id;
      }

      // Auto-update description when tax rate is selected
      _updateDescription();
    });

    debugPrint(
        '✅ Pre-populated from tax rate: ${selectedRate.taxAmount} ${selectedRate.currency} for ${selectedRate.vehicleType}');
  }

  void _onVehicleTypeSelected(String? vehicleTypeId) {
    if (vehicleTypeId == null) return;

    // Find the vehicle type name
    final vehicleType = _vehicleTypes.firstWhere(
      (vt) => vt.id == vehicleTypeId,
      orElse: () => VehicleType(
        id: vehicleTypeId,
        label: '',
        description: '',
        isActive: true,
      ),
    );

    // Find matching tax rate for this vehicle type
    final matchingTaxRate = _taxRates.firstWhere(
      (rate) =>
          rate.vehicleType.toLowerCase() == vehicleType.label.toLowerCase(),
      orElse: () => VehicleTaxRate(
        id: '',
        countryName: '',
        vehicleType: '',
        taxAmount: 0.0,
        currency: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    setState(() {
      _selectedVehicleTypeId = vehicleTypeId;
      // Auto-populate if we found a matching rate and fields are empty/default
      if (matchingTaxRate.id.isNotEmpty &&
          (_taxAmountController.text == '0.00' ||
              _taxAmountController.text.isEmpty)) {
        _taxAmountController.text = matchingTaxRate.taxAmount.toString();
        _selectedCurrencyCode = matchingTaxRate.currency;
        _selectedTaxRateId = matchingTaxRate.id;
      }

      // Auto-update description when vehicle type changes
      _updateDescription();
    });

    if (matchingTaxRate.id.isNotEmpty) {
      debugPrint(
          '✅ Auto-populated tax: ${matchingTaxRate.taxAmount} ${matchingTaxRate.currency} for ${vehicleType.label}');
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _entryLimitController.dispose();
    _expirationDaysController.dispose();
    _passAdvanceDaysController.dispose();
    _taxAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.template != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Template' : 'Create Template'),
        backgroundColor: Colors.orange.shade100,
        foregroundColor: Colors.orange.shade800,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveTemplate,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isEditing ? 'Update' : 'Create',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Authority header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border(
                        bottom: BorderSide(color: Colors.orange.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.receipt,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.authorityName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              Text(
                                isEditing
                                    ? 'Edit Pass Template'
                                    : 'Create New Pass Template',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Form content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFormSection(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vehicle Tax Rates dropdown (at the top)
        if (_taxRates.isNotEmpty) ...[
          Text(
            'Quick Setup from Tax Rates',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedTaxRateId,
            decoration: InputDecoration(
              labelText: 'Pre-populate from Vehicle Tax Rate (Optional)',
              helperText:
                  'Select to auto-fill vehicle type, tax amount, and currency',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Select a tax rate...'),
              ),
              ..._taxRates.map((rate) {
                return DropdownMenuItem(
                  value: rate.id,
                  child: Text(
                    '${rate.vehicleType} - ${rate.taxAmount} ${rate.currency}${rate.borderName != null ? ' (${rate.borderName})' : ' (Country-wide)'}',
                  ),
                );
              }),
            ],
            onChanged: _onTaxRateSelected,
          ),
          const SizedBox(height: 24),
        ],

        // Template Details section
        Text(
          'Template Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade800,
          ),
        ),
        const SizedBox(height: 16),

        // Vehicle Type
        DropdownButtonFormField<String>(
          value: _selectedVehicleTypeId,
          decoration: InputDecoration(
            labelText: 'Vehicle Type *',
            helperText: 'Tax amount and currency may auto-populate',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          items: _vehicleTypes.map((vehicleType) {
            return DropdownMenuItem(
              value: vehicleType.id,
              child: Text(vehicleType.label),
            );
          }).toList(),
          onChanged: _onVehicleTypeSelected,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vehicle type is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Tax Amount and Currency
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _taxAmountController,
                decoration: InputDecoration(
                  labelText: 'Tax Amount *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Tax amount is required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedCurrencyCode,
                decoration: InputDecoration(
                  labelText: 'Currency *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _currencies.map((currency) {
                  return DropdownMenuItem(
                    value: currency.code,
                    child: Text(currency.code),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCurrencyCode = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Currency is required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Entry Limit and Expiration Days
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _entryLimitController,
                decoration: InputDecoration(
                  labelText: 'Entry Limit *',
                  hintText: 'Number of entries allowed',
                  helperText: 'Default: 1 entry per pass',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _updateDescription();
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Entry limit is required';
                  }
                  final limit = int.tryParse(value);
                  if (limit == null || limit < 0) {
                    return 'Enter a valid number >= 0';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _expirationDaysController,
                decoration: InputDecoration(
                  labelText: 'Validity (days) *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Validity days is required';
                  }
                  final days = int.tryParse(value);
                  if (days == null || days <= 0) {
                    return 'Enter a valid number > 0';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Pass Advance Days
        TextFormField(
          controller: _passAdvanceDaysController,
          decoration: InputDecoration(
            labelText: 'Advance Purchase Days *',
            hintText: _authority?.defaultPassAdvanceDays != null
                ? 'Authority default: ${_authority!.defaultPassAdvanceDays} days'
                : 'Suggested: 7 days',
            helperText: 'How many days in advance can this pass be purchased',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Advance purchase days is required';
            }
            final days = int.tryParse(value);
            if (days == null || days < 0) {
              return 'Enter a valid number >= 0';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),

        // Entry/Exit Points section
        Text(
          'Entry & Exit Points',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade800,
          ),
        ),
        const SizedBox(height: 16),

        // Entry Point Configuration
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.login, color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Entry Point',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow User Selection'),
                  subtitle: Text(
                    _allowUserSelectableEntryPoint
                        ? 'Users choose entry point during purchase'
                        : 'Use fixed entry point defined below',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _allowUserSelectableEntryPoint,
                  onChanged: (value) {
                    setState(() {
                      _allowUserSelectableEntryPoint = value;
                      if (value) {
                        _selectedEntryPointId = null;
                      }
                      _updateDescription();
                    });
                  },
                ),
                if (!_allowUserSelectableEntryPoint) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedEntryPointId,
                    decoration: InputDecoration(
                      labelText: 'Select Entry Point',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Any Entry Point'),
                      ),
                      ..._borders.map((border) {
                        return DropdownMenuItem(
                          value: border.id,
                          child: Text(border.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedEntryPointId = value;
                        _updateDescription();
                      });
                    },
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_pin_circle,
                            color: Colors.green.shade600, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Users will select entry point during purchase',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Exit Point Configuration
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Exit Point',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow User Selection'),
                  subtitle: Text(
                    _allowUserSelectableExitPoint
                        ? 'Users choose exit point during purchase'
                        : 'Use fixed exit point defined below',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _allowUserSelectableExitPoint,
                  onChanged: (value) {
                    setState(() {
                      _allowUserSelectableExitPoint = value;
                      if (value) {
                        _selectedExitPointId = null;
                      }
                      _updateDescription();
                    });
                  },
                ),
                if (!_allowUserSelectableExitPoint) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedExitPointId,
                    decoration: InputDecoration(
                      labelText: 'Select Exit Point',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Any Exit Point'),
                      ),
                      ..._borders.map((border) {
                        return DropdownMenuItem(
                          value: border.id,
                          child: Text(border.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedExitPointId = value;
                        _updateDescription();
                      });
                    },
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_pin_circle,
                            color: Colors.red.shade600, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Users will select exit point during purchase',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Description section
        Text(
          'Template Description',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade800,
          ),
        ),
        const SizedBox(height: 16),

        // Description field
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'Description *',
            hintText: 'Auto-generated based on template configuration',
            helperText: 'This will be displayed to users when selecting passes',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Regenerate description',
              onPressed: () {
                _descriptionController.clear();
                _updateDescription();
              },
            ),
          ),
          maxLines: 2,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Description is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),

        // Description preview/info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: Colors.orange.shade600, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Description includes:',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '• Vehicle type • Entry limit • Route information • Authority code',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Active status (only for editing)
        if (widget.template != null) ...[
          Card(
            child: SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text('Template is available for use'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final description = _descriptionController.text.trim();
      final entryLimit = int.tryParse(_entryLimitController.text) ?? 0;
      final expirationDays = int.parse(_expirationDaysController.text);
      final passAdvanceDays =
          int.tryParse(_passAdvanceDaysController.text) ?? 0;
      final taxAmount = double.parse(_taxAmountController.text);

      if (widget.template != null) {
        // Update existing template
        await PassTemplateService.updatePassTemplate(
          templateId: widget.template!.id,
          description: description,
          entryLimit: entryLimit,
          expirationDays: expirationDays,
          passAdvanceDays: passAdvanceDays,
          taxAmount: taxAmount,
          currencyCode: _selectedCurrencyCode!,
          isActive: _isActive,
          vehicleTypeId: _selectedVehicleTypeId,
          entryPointId:
              _allowUserSelectableEntryPoint ? null : _selectedEntryPointId,
          exitPointId:
              _allowUserSelectableExitPoint ? null : _selectedExitPointId,
          allowUserSelectableEntryPoint: _allowUserSelectableEntryPoint,
          allowUserSelectableExitPoint: _allowUserSelectableExitPoint,
        );
      } else {
        // Create new template
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) throw Exception('User not authenticated');

        await PassTemplateService.createPassTemplate(
          authorityId: widget.authorityId,
          creatorProfileId: user.id,
          vehicleTypeId: _selectedVehicleTypeId!,
          description: description,
          entryLimit: entryLimit,
          expirationDays: expirationDays,
          passAdvanceDays: passAdvanceDays,
          taxAmount: taxAmount,
          currencyCode: _selectedCurrencyCode!,
          entryPointId:
              _allowUserSelectableEntryPoint ? null : _selectedEntryPointId,
          exitPointId:
              _allowUserSelectableExitPoint ? null : _selectedExitPointId,
          allowUserSelectableEntryPoint: _allowUserSelectableEntryPoint,
          allowUserSelectableExitPoint: _allowUserSelectableExitPoint,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.template != null
                ? 'Template updated successfully'
                : 'Template created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
