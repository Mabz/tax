import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pass_template.dart';
import '../models/vehicle_tax_rate.dart';
import '../models/vehicle_type.dart';
import '../models/border.dart' as border_model;
import '../models/currency.dart';
import '../services/pass_template_service.dart';
import '../services/role_service.dart';

class PassTemplateManagementScreen extends StatefulWidget {
  final Map<String, dynamic> country;

  const PassTemplateManagementScreen({
    super.key,
    required this.country,
  });

  @override
  State<PassTemplateManagementScreen> createState() =>
      _PassTemplateManagementScreenState();
}

class _PassTemplateManagementScreenState
    extends State<PassTemplateManagementScreen> {
  List<PassTemplate> _passTemplates = [];
  List<VehicleTaxRate> _taxRates = [];
  List<VehicleType> _vehicleTypes = [];
  List<border_model.Border> _borders = [];
  List<Currency> _currencies = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadData();
  }

  Future<void> _checkPermissionsAndLoadData() async {
    try {
      // Check if user has permission (superuser or country admin)
      final isSuperuser = await RoleService.isSuperuser();
      final hasAdminRole = await RoleService.hasAdminRole();

      if (!isSuperuser && !hasAdminRole) {
        setState(() {
          _error =
              'You do not have permission to manage pass templates. Superuser or country administrator role required.';
          _isLoading = false;
        });
        return;
      }

      await _loadData();
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final countryId = widget.country['id'] as String;

      // Load all required data
      final results = await Future.wait([
        PassTemplateService.getPassTemplatesForCountry(countryId),
        PassTemplateService.getTaxRatesForCountry(countryId),
        PassTemplateService.getVehicleTypes(),
        PassTemplateService.getBordersForCountry(countryId),
        PassTemplateService.getActiveCurrencies(),
      ]);

      setState(() {
        _passTemplates = results[0] as List<PassTemplate>;
        _taxRates = results[1] as List<VehicleTaxRate>;
        _vehicleTypes = results[2] as List<VehicleType>;
        _borders = results[3] as List<border_model.Border>;
        _currencies = results[4] as List<Currency>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  void _showPassTemplateDialog({PassTemplate? template}) {
    showDialog(
      context: context,
      builder: (context) => _PassTemplateDialog(
        template: template,
        countryId: widget.country['id'] as String,
        countryName: widget.country['name'] as String,
        taxRates: _taxRates,
        vehicleTypes: _vehicleTypes,
        borders: _borders,
        currencies: _currencies,
        onSaved: _loadData,
      ),
    );
  }

  void _deleteTemplate(PassTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pass Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this pass template?'),
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
                  Text('Description: ${template.description}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Vehicle Type: ${template.vehicleType ?? 'Unknown'}'),
                  Text('Border: ${template.borderName ?? 'All borders'}'),
                  Text(
                      'Tax Amount: ${template.taxAmount} ${template.currencyCode}'),
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
        await PassTemplateService.deletePassTemplate(template.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pass template deleted successfully')),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete pass template: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pass Templates'),
        backgroundColor: Colors.orange.shade100,
        foregroundColor: Colors.orange.shade800,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _checkPermissionsAndLoadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Country header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.country['name'] as String,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_passTemplates.length} pass template(s) configured',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Header with add button
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: Colors.grey.shade50,
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Templates',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showPassTemplateDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Template'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Templates list
                    Expanded(
                      child: _passTemplates.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long,
                                      size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('No pass templates found'),
                                  Text(
                                      'Create your first pass template to get started'),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _passTemplates.length,
                              itemBuilder: (context, index) {
                                final template = _passTemplates[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: template.isActive
                                          ? Colors.green
                                          : Colors.grey,
                                      child: const Icon(
                                        Icons.receipt_long,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      template.description,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            'Vehicle: ${template.vehicleType ?? 'Unknown'}'),
                                        Text(
                                            'Border: ${template.borderName ?? 'All borders'}'),
                                        Text(
                                            'Tax: ${template.taxAmount} ${template.currencyCode}'),
                                        Text(
                                            'Entries: ${template.entryLimit} | Expires: ${template.expirationDays} days'),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () =>
                                              _showPassTemplateDialog(
                                                  template: template),
                                          icon: const Icon(Icons.edit),
                                          color: Colors.orange,
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _deleteTemplate(template),
                                          icon: const Icon(Icons.delete),
                                          color: Colors.red,
                                        ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: _passTemplates.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showPassTemplateDialog(),
              backgroundColor: Colors.orange,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}

class _PassTemplateDialog extends StatefulWidget {
  final PassTemplate? template;
  final String countryId;
  final String countryName;
  final List<VehicleTaxRate> taxRates;
  final List<VehicleType> vehicleTypes;
  final List<border_model.Border> borders;
  final List<Currency> currencies;
  final VoidCallback onSaved;

  const _PassTemplateDialog({
    this.template,
    required this.countryId,
    required this.countryName,
    required this.taxRates,
    required this.vehicleTypes,
    required this.borders,
    required this.currencies,
    required this.onSaved,
  });

  @override
  State<_PassTemplateDialog> createState() => _PassTemplateDialogState();
}

class _PassTemplateDialogState extends State<_PassTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _entryLimitController = TextEditingController();
  final _expirationDaysController = TextEditingController();
  final _taxAmountController = TextEditingController();

  VehicleTaxRate? _selectedTaxRate;
  VehicleType? _selectedVehicleType;
  border_model.Border? _selectedBorder;
  Currency? _selectedCurrency;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();

    // Add listeners to auto-generate description
    _entryLimitController.addListener(_generateDescription);
    _expirationDaysController.addListener(_generateDescription);
    _taxAmountController.addListener(_generateDescription);
  }

  void _initializeFields() {
    if (widget.template != null) {
      final template = widget.template!;
      _descriptionController.text = template.description;
      _entryLimitController.text = template.entryLimit.toString();
      _expirationDaysController.text = template.expirationDays.toString();
      _taxAmountController.text = template.taxAmount.toString();
      _isActive = template.isActive;

      // Find matching vehicle type
      _selectedVehicleType = widget.vehicleTypes.firstWhere(
        (vt) => vt.label == template.vehicleType,
        orElse: () => widget.vehicleTypes.first,
      );

      // Find matching border
      if (template.borderName != null) {
        _selectedBorder = widget.borders.firstWhere(
          (b) => b.name == template.borderName,
          orElse: () => widget.borders.first,
        );
      }

      // Find matching currency
      _selectedCurrency = widget.currencies.firstWhere(
        (c) => c.code == template.currencyCode,
        orElse: () => widget.currencies.first,
      );
    } else {
      // Default values for new template
      _entryLimitController.text = '1';
      _expirationDaysController.text = '30';
      _taxAmountController.text = '0.00';

      if (widget.vehicleTypes.isNotEmpty) {
        _selectedVehicleType = widget.vehicleTypes.first;
      }
      if (widget.currencies.isNotEmpty) {
        _selectedCurrency = widget.currencies.first;
      }

      // Generate initial description for new templates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateDescription();
      });
    }
  }

  void _onTaxRateSelected(VehicleTaxRate? taxRate) {
    if (taxRate == null) return;

    setState(() {
      _selectedTaxRate = taxRate;
      _taxAmountController.text = taxRate.taxAmount.toString();

      // Find matching vehicle type
      _selectedVehicleType = widget.vehicleTypes.firstWhere(
        (vt) => vt.label == taxRate.vehicleType,
        orElse: () => widget.vehicleTypes.first,
      );

      // Find matching border
      if (taxRate.borderName != null) {
        _selectedBorder = widget.borders.firstWhere(
          (b) => b.name == taxRate.borderName,
          orElse: () => widget.borders.first,
        );
      } else {
        _selectedBorder = null;
      }

      // Find matching currency
      _selectedCurrency = widget.currencies.firstWhere(
        (c) => c.code == taxRate.currency,
        orElse: () => widget.currencies.first,
      );

      // Auto-generate description
      _generateDescription();
    });
  }

  String _generateDescription() {
    if (_selectedVehicleType == null || _selectedCurrency == null) {
      return '';
    }

    final vehicleType = _selectedVehicleType!.label;
    final border = _selectedBorder?.name ?? 'All borders';
    final taxAmount = _taxAmountController.text.isNotEmpty
        ? _taxAmountController.text
        : '0.00';
    final currency = _selectedCurrency!.code;
    final entryLimit = _entryLimitController.text.isNotEmpty
        ? _entryLimitController.text
        : '1';
    final expirationDays = _expirationDaysController.text.isNotEmpty
        ? _expirationDaysController.text
        : '30';

    final description =
        '$vehicleType pass for $border - $currency $taxAmount per entry, $entryLimit entries allowed, valid for $expirationDays days';

    // Update the description field
    _descriptionController.text = description;

    return description;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedVehicleType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle type')),
      );
      return;
    }

    if (_selectedCurrency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a currency')),
      );
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      if (widget.template == null) {
        // Create new template
        final currentUser = Supabase.instance.client.auth.currentUser!;
        await PassTemplateService.createPassTemplate(
          countryId: widget.countryId,
          creatorProfileId: currentUser.id,
          vehicleTypeId: _selectedVehicleType!.id,
          description: _descriptionController.text.trim(),
          entryLimit: int.parse(_entryLimitController.text),
          expirationDays: int.parse(_expirationDaysController.text),
          taxAmount: double.parse(_taxAmountController.text),
          currencyCode: _selectedCurrency!.code,
          borderId: _selectedBorder?.id,
        );
      } else {
        // Update existing template
        await PassTemplateService.updatePassTemplate(
          templateId: widget.template!.id,
          description: _descriptionController.text.trim(),
          entryLimit: int.parse(_entryLimitController.text),
          expirationDays: int.parse(_expirationDaysController.text),
          taxAmount: double.parse(_taxAmountController.text),
          currencyCode: _selectedCurrency!.code,
          isActive: _isActive,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.template == null
                ? 'Pass template created successfully'
                : 'Pass template updated successfully'),
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save pass template: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog() async {
    // Generate the final description before showing confirmation
    final finalDescription = _generateDescription();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.template == null
            ? 'Confirm Pass Template Creation'
            : 'Confirm Pass Template Update'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.template == null
                      ? 'Please review the pass template details before creating:'
                      : 'Please review the updated pass template details:',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Description:', finalDescription),
                      const SizedBox(height: 8),
                      _buildDetailRow('Vehicle Type:',
                          _selectedVehicleType?.label ?? 'Not selected'),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                          'Border:', _selectedBorder?.name ?? 'All borders'),
                      const SizedBox(height: 8),
                      _buildDetailRow('Tax Amount:',
                          '${_taxAmountController.text} ${_selectedCurrency?.code ?? ''}'),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                          'Entry Limit:', _entryLimitController.text),
                      const SizedBox(height: 8),
                      _buildDetailRow('Valid for:',
                          '${_expirationDaysController.text} days'),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                          'Status:', _isActive ? 'Active' : 'Inactive'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This action will be audited and logged for compliance purposes.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(widget.template == null
                ? 'Create Template'
                : 'Update Template'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _entryLimitController.dispose();
    _expirationDaysController.dispose();
    _taxAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.template == null
          ? 'Create Pass Template'
          : 'Edit Pass Template'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tax Rate Template Dropdown - Always visible at top
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
                      const Row(
                        children: [
                          Icon(Icons.content_copy,
                              color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Use Existing Tax Rate',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<VehicleTaxRate>(
                        value: _selectedTaxRate,
                        decoration: const InputDecoration(
                          labelText: 'Select Template (Optional)',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon:
                              Icon(Icons.list_alt, color: Colors.orange),
                        ),
                        items: [
                          const DropdownMenuItem<VehicleTaxRate>(
                            value: null,
                            child: Text('None - Create from scratch'),
                          ),
                          if (widget.taxRates.isNotEmpty)
                            ...widget.taxRates.map((taxRate) =>
                                DropdownMenuItem<VehicleTaxRate>(
                                  value: taxRate,
                                  child: Container(
                                    width: double.maxFinite,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6, horizontal: 4),
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${taxRate.vehicleType}\n',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              height: 1.2,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                '${taxRate.borderName ?? 'All borders'} • ${taxRate.taxAmount} ${taxRate.currency}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )),
                        ],
                        onChanged: _onTaxRateSelected,
                      ),
                      if (widget.taxRates.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'No existing tax rates found for this country.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description, color: Colors.orange),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Vehicle Type
                DropdownButtonFormField<VehicleType>(
                  value: _selectedVehicleType,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Type *',
                    border: OutlineInputBorder(),
                    prefixIcon:
                        Icon(Icons.directions_car, color: Colors.orange),
                  ),
                  items: widget.vehicleTypes
                      .map((vehicleType) => DropdownMenuItem<VehicleType>(
                            value: vehicleType,
                            child: Text(
                              vehicleType.label,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedVehicleType = value;
                    });
                    _generateDescription();
                  },
                  validator: (value) =>
                      value == null ? 'Please select a vehicle type' : null,
                ),
                const SizedBox(height: 16),

                // Border
                DropdownButtonFormField<border_model.Border>(
                  value: _selectedBorder,
                  decoration: const InputDecoration(
                    labelText: 'Border (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.border_all, color: Colors.orange),
                  ),
                  items: [
                    const DropdownMenuItem<border_model.Border>(
                      value: null,
                      child: Text('All borders'),
                    ),
                    ...widget.borders
                        .map((border) => DropdownMenuItem<border_model.Border>(
                              value: border,
                              child: Text(
                                border.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedBorder = value;
                    });
                    _generateDescription();
                  },
                ),
                const SizedBox(height: 16),

                // Entry Limit
                TextFormField(
                  controller: _entryLimitController,
                  decoration: const InputDecoration(
                    labelText: 'Entry Limit *',
                    border: OutlineInputBorder(),
                    prefixIcon:
                        Icon(Icons.confirmation_number, color: Colors.orange),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter entry limit';
                    }
                    final number = int.tryParse(value);
                    if (number == null || number <= 0) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Expiration Days
                TextFormField(
                  controller: _expirationDaysController,
                  decoration: const InputDecoration(
                    labelText: 'Expiration Days *',
                    border: OutlineInputBorder(),
                    prefixIcon:
                        Icon(Icons.calendar_today, color: Colors.orange),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter expiration days';
                    }
                    final number = int.tryParse(value);
                    if (number == null || number <= 0) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Currency
                DropdownButtonFormField<Currency>(
                  value: _selectedCurrency,
                  decoration: const InputDecoration(
                    labelText: 'Currency *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money, color: Colors.orange),
                  ),
                  items: widget.currencies
                      .map((currency) => DropdownMenuItem<Currency>(
                            value: currency,
                            child: Text(
                              '${currency.symbol} ${currency.code}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCurrency = value;
                    });
                    _generateDescription();
                  },
                  validator: (value) =>
                      value == null ? 'Please select a currency' : null,
                ),
                const SizedBox(height: 16),

                // Tax Amount
                TextFormField(
                  controller: _taxAmountController,
                  decoration: InputDecoration(
                    labelText: 'Tax Amount *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.money, color: Colors.orange),
                    prefixText: _selectedCurrency?.symbol ?? '',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter tax amount';
                    }
                    final number = double.tryParse(value);
                    if (number == null || number < 0) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Active status (only for editing)
                if (widget.template != null) ...[
                  SwitchListTile(
                    title: const Text('Active'),
                    subtitle: const Text(
                        'Whether this template is available for use'),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                    activeColor: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                ],
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
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.template == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}
