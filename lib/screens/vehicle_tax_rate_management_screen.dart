import 'package:flutter/material.dart';
import '../models/vehicle_tax_rate.dart';
import '../models/vehicle_type.dart';
import '../models/border.dart' as border_model;
import '../models/currency.dart';
import '../services/vehicle_tax_rate_service.dart';

class VehicleTaxRateManagementScreen extends StatefulWidget {
  final Map<String, dynamic> selectedCountry;

  const VehicleTaxRateManagementScreen({
    super.key,
    required this.selectedCountry,
  });

  @override
  State<VehicleTaxRateManagementScreen> createState() =>
      _VehicleTaxRateManagementScreenState();
}

class _VehicleTaxRateManagementScreenState
    extends State<VehicleTaxRateManagementScreen> {
  bool _isLoading = true;
  String? _error;
  List<VehicleTaxRate> _taxRates = [];
  List<VehicleType> _vehicleTypes = [];
  List<border_model.Border> _borders = [];
  List<Currency> _currencies = [];

  String get _countryId => widget.selectedCountry['id'] as String;
  String get _countryName => widget.selectedCountry['name'] as String;
  String get _authorityName =>
      widget.selectedCountry['authority_name'] as String;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final futures = await Future.wait([
        VehicleTaxRateService.getTaxRatesForCountry(_countryId),
        VehicleTaxRateService.getVehicleTypes(),
        VehicleTaxRateService.getBordersForCountry(_countryId),
        VehicleTaxRateService.getActiveCurrencies(),
      ]);

      setState(() {
        _taxRates = futures[0] as List<VehicleTaxRate>;
        _vehicleTypes = futures[1] as List<VehicleType>;
        _borders = futures[2] as List<border_model.Border>;
        _currencies = futures[3] as List<Currency>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  void _showTaxRateDialog({VehicleTaxRate? taxRate}) {
    showDialog(
      context: context,
      builder: (context) => _TaxRateDialog(
        taxRate: taxRate,
        countryId: _countryId,
        vehicleTypes: _vehicleTypes,
        borders: _borders,
        currencies: _currencies,
        defaultCurrencyCode:
            widget.selectedCountry['default_currency_code'] as String?,
        onSaved: _loadData,
      ),
    );
  }

  void _deleteTaxRate(VehicleTaxRate taxRate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete the tax rate for ${taxRate.vehicleType}?',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Scope: ${taxRate.displayScope}',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              'Amount: ${taxRate.taxAmount.toStringAsFixed(2)} ${taxRate.currency}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_outlined,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone and will be audited for compliance purposes.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
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
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Extract vehicle type ID and border ID from the tax rate
        final vehicleType = _vehicleTypes.firstWhere(
          (vt) => vt.label == taxRate.vehicleType,
        );
        final border = taxRate.borderName != null
            ? _borders.firstWhere((b) => b.name == taxRate.borderName)
            : null;

        await VehicleTaxRateService.deleteTaxRate(
          countryId: _countryId,
          vehicleTypeId: vehicleType.id,
          borderId: border?.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tax rate deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete tax rate: $e'),
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
        title: const Text('Vehicle Tax Rate'),
        backgroundColor: Colors.orange.shade100,
        foregroundColor: Colors.orange.shade800,
      ),
      body: SafeArea(child: _buildBody()),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaxRateDialog(),
        backgroundColor: Colors.orange.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text('Loading tax rates...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildCountryHeader(),
        Expanded(child: _buildTaxRatesList()),
      ],
    );
  }

  Widget _buildCountryHeader() {
    return Container(
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
                  _authorityName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_taxRates.length} tax rate(s) configured',
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
    );
  }

  Widget _buildTaxRatesList() {
    if (_taxRates.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_taxi_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No tax rates configured yet.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the + button to add your first tax rate.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _taxRates.length,
      itemBuilder: (context, index) {
        final taxRate = _taxRates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        taxRate.vehicleType,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showTaxRateDialog(taxRate: taxRate);
                            break;
                          case 'delete':
                            _deleteTaxRate(taxRate);
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
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _buildTaxInfoChip('Scope', taxRate.displayScope),
                    _buildTaxInfoChip('Amount',
                        '${taxRate.taxAmount.toStringAsFixed(2)} ${taxRate.currency}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaxInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: Colors.orange.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _TaxRateDialog extends StatefulWidget {
  final VehicleTaxRate? taxRate;
  final String countryId;
  final List<VehicleType> vehicleTypes;
  final List<border_model.Border> borders;
  final List<Currency> currencies;
  final String? defaultCurrencyCode;
  final VoidCallback onSaved;

  const _TaxRateDialog({
    this.taxRate,
    required this.countryId,
    required this.vehicleTypes,
    required this.borders,
    required this.currencies,
    this.defaultCurrencyCode,
    required this.onSaved,
  });

  @override
  State<_TaxRateDialog> createState() => _TaxRateDialogState();
}

class _TaxRateDialogState extends State<_TaxRateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _taxAmountController = TextEditingController();

  VehicleType? _selectedVehicleType;
  border_model.Border? _selectedBorder;
  Currency? _selectedCurrency;
  bool _isCountryWide = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.taxRate != null) {
      final taxRate = widget.taxRate!;
      _taxAmountController.text = taxRate.taxAmount.toString();
      _isCountryWide = taxRate.isCountryWide;

      // Find the vehicle type
      _selectedVehicleType = widget.vehicleTypes.firstWhere(
        (vt) => vt.label == taxRate.vehicleType,
        orElse: () => widget.vehicleTypes.first,
      );

      // Find the currency
      try {
        _selectedCurrency = widget.currencies.firstWhere(
          (c) => c.code == taxRate.currency,
        );
      } catch (e) {
        _selectedCurrency =
            widget.currencies.isNotEmpty ? widget.currencies.first : null;
      }

      // Find the border if it's border-specific
      if (!_isCountryWide && taxRate.borderName != null) {
        _selectedBorder = widget.borders.firstWhere(
          (b) => b.name == taxRate.borderName,
          orElse: () => widget.borders.first,
        );
      }
    } else {
      // Set default currency based on authority's default currency code
      if (widget.defaultCurrencyCode != null) {
        try {
          _selectedCurrency = widget.currencies.firstWhere(
            (c) => c.code == widget.defaultCurrencyCode,
          );
        } catch (e) {
          // If authority's default currency is not found, fall back to USD
          try {
            _selectedCurrency = widget.currencies.firstWhere(
              (c) => c.code == 'USD',
            );
          } catch (e) {
            _selectedCurrency =
                widget.currencies.isNotEmpty ? widget.currencies.first : null;
          }
        }
      } else {
        // If no default currency code from authority, fall back to USD
        try {
          _selectedCurrency = widget.currencies.firstWhere(
            (c) => c.code == 'USD',
          );
        } catch (e) {
          _selectedCurrency =
              widget.currencies.isNotEmpty ? widget.currencies.first : null;
        }
      }
      _selectedVehicleType =
          widget.vehicleTypes.isNotEmpty ? widget.vehicleTypes.first : null;
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final BuildContext dialogContext = context;
    return await showDialog<bool>(
          context: dialogContext,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Tax Rate Change'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Are you sure you want to proceed with this tax rate change?',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This action will be audited and logged for compliance purposes.',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
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
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _saveTaxRate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleType == null) return;
    if (_selectedCurrency == null) return;

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final taxAmount = double.parse(_taxAmountController.text);
      final currency = _selectedCurrency!.code;
      final borderId = _isCountryWide ? null : _selectedBorder?.id;

      if (widget.taxRate != null) {
        // Update existing tax rate
        await VehicleTaxRateService.updateTaxRate(
          countryId: widget.countryId,
          vehicleTypeId: _selectedVehicleType!.id,
          taxAmount: taxAmount,
          currency: currency,
          borderId: borderId,
        );
      } else {
        // Create new tax rate
        await VehicleTaxRateService.createTaxRate(
          countryId: widget.countryId,
          vehicleTypeId: _selectedVehicleType!.id,
          taxAmount: taxAmount,
          currency: currency,
          borderId: borderId,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.taxRate != null
                  ? 'Tax rate updated successfully'
                  : 'Tax rate created successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save tax rate: $e'),
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
      title: Text(widget.taxRate != null ? 'Edit Tax Rate' : 'Add Tax Rate'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Vehicle Type Dropdown
                DropdownButtonFormField<VehicleType>(
                  value: _selectedVehicleType,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Type',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.vehicleTypes.map((vehicleType) {
                    return DropdownMenuItem<VehicleType>(
                      value: vehicleType,
                      child: Text(vehicleType.label),
                    );
                  }).toList(),
                  onChanged: (VehicleType? value) {
                    setState(() {
                      _selectedVehicleType = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a vehicle type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Scope Selection
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tax Rate Scope:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    RadioListTile<bool>(
                      title: const Text('Country-wide'),
                      subtitle:
                          const Text('Apply to all borders in the country'),
                      value: true,
                      groupValue: _isCountryWide,
                      onChanged: (bool? value) {
                        setState(() {
                          _isCountryWide = value ?? true;
                          if (_isCountryWide) {
                            _selectedBorder = null;
                          }
                        });
                      },
                      activeColor: Colors.orange,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<bool>(
                      title: const Text('Border-specific'),
                      subtitle: const Text('Apply to a specific border only'),
                      value: false,
                      groupValue: _isCountryWide,
                      onChanged: (bool? value) {
                        setState(() {
                          _isCountryWide = value ?? true;
                        });
                      },
                      activeColor: Colors.orange,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),

                // Border Selection (if border-specific)
                if (!_isCountryWide) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<border_model.Border>(
                    value: _selectedBorder,
                    decoration: const InputDecoration(
                      labelText: 'Border',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.borders.map((border) {
                      return DropdownMenuItem<border_model.Border>(
                        value: border,
                        child: Text(border.name),
                      );
                    }).toList(),
                    onChanged: (border_model.Border? value) {
                      setState(() {
                        _selectedBorder = value;
                      });
                    },
                    validator: (value) {
                      if (!_isCountryWide && value == null) {
                        return 'Please select a border';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 16),

                // Currency Dropdown
                DropdownButtonFormField<Currency>(
                  value: _selectedCurrency,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.currencies.map((currency) {
                    return DropdownMenuItem<Currency>(
                      value: currency,
                      child: Text(
                        '${currency.code} - ${currency.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (Currency? value) {
                    setState(() {
                      _selectedCurrency = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a currency';
                    }
                    return null;
                  },
                  isExpanded: true,
                ),
                const SizedBox(height: 16),

                // Tax Amount
                TextFormField(
                  controller: _taxAmountController,
                  decoration: InputDecoration(
                    labelText: 'Tax Amount',
                    border: const OutlineInputBorder(),
                    prefixText: _selectedCurrency?.symbol != null
                        ? '${_selectedCurrency!.symbol} '
                        : '',
                    prefixStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a tax amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    if (double.parse(value) < 0) {
                      return 'Tax amount cannot be negative';
                    }
                    return null;
                  },
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
          onPressed: _isLoading ? null : _saveTaxRate,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.taxRate != null ? 'Update' : 'Create',
                  style: const TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _taxAmountController.dispose();
    super.dispose();
  }
}
