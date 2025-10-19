import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/authority.dart';
import '../services/authority_service.dart';

/// Simple screen for editing the current selected authority
class EditAuthorityScreen extends StatefulWidget {
  final Authority authority;

  const EditAuthorityScreen({
    super.key,
    required this.authority,
  });

  @override
  State<EditAuthorityScreen> createState() => _EditAuthorityScreenState();
}

class _EditAuthorityScreenState extends State<EditAuthorityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _defaultPassAdvanceDaysController = TextEditingController();

  String _selectedAuthorityType = 'revenue_service';
  String _selectedCurrency = 'USD';
  bool _isSaving = false;

  final List<String> _authorityTypes = [
    'revenue_service',
    'customs',
    'immigration',
    'global',
    'other',
  ];

  final List<String> _currencies = [
    'USD',
    'EUR',
    'GBP',
    'ZAR',
    'SZL',
    'BWP',
    'NAD',
    'MZN',
    'ZMW',
    'ZWL',
    'TZS',
    'LSL',
    'AOA',
    'KES',
    'NGN',
    'XAF',
    'XOF',
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _defaultPassAdvanceDaysController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    _nameController.text = widget.authority.name;
    _codeController.text = widget.authority.code;
    _descriptionController.text = widget.authority.description ?? '';
    _defaultPassAdvanceDaysController.text =
        widget.authority.defaultPassAdvanceDays?.toString() ?? '';

    // Ensure the authority type exists in our predefined list
    if (_authorityTypes.contains(widget.authority.authorityType)) {
      _selectedAuthorityType = widget.authority.authorityType;
    } else {
      // If the authority type doesn't exist in our list, default to 'other'
      _selectedAuthorityType = 'other';
      debugPrint(
          '⚠️ Authority type "${widget.authority.authorityType}" not found in predefined list, defaulting to "other"');
    }

    // Ensure the currency exists in our predefined list
    if (_currencies.contains(widget.authority.defaultCurrencyCode)) {
      _selectedCurrency = widget.authority.defaultCurrencyCode!;
    } else {
      _selectedCurrency = 'USD';
      debugPrint(
          '⚠️ Currency "${widget.authority.defaultCurrencyCode}" not found in predefined list, defaulting to "USD"');
    }
  }

  String _getAuthorityTypeDisplayName(String type) {
    switch (type) {
      case 'revenue_service':
        return 'Revenue Service';
      case 'customs':
        return 'Customs Authority';
      case 'immigration':
        return 'Immigration Authority';
      case 'global':
        return 'Global Authority';
      case 'other':
        return 'Other';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  Future<void> _saveChanges() async {
    debugPrint('🔍 EditAuthority: _saveChanges called');

    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ EditAuthority: Form validation failed');
      return;
    }

    debugPrint('✅ EditAuthority: Form validation passed');
    setState(() => _isSaving = true);

    try {
      final advanceDaysText = _defaultPassAdvanceDaysController.text.trim();
      final advanceDays =
          advanceDaysText.isEmpty ? null : int.tryParse(advanceDaysText);

      debugPrint('🔍 EditAuthority: Preparing to save authority');
      debugPrint('🔍 EditAuthority: Authority ID: ${widget.authority.id}');
      debugPrint('🔍 EditAuthority: Name: ${_nameController.text.trim()}');
      debugPrint(
          '🔍 EditAuthority: Code: ${_codeController.text.trim().toUpperCase()}');
      debugPrint('🔍 EditAuthority: Authority Type: $_selectedAuthorityType');
      debugPrint(
          '🔍 EditAuthority: Description: ${_descriptionController.text.trim()}');
      debugPrint('🔍 EditAuthority: Currency: $_selectedCurrency');
      debugPrint('🔍 EditAuthority: Advance Days: $advanceDays');

      await AuthorityService.updateAuthority(
        authorityId: widget.authority.id,
        name: _nameController.text.trim(),
        code: _codeController.text.trim().toUpperCase(),
        authorityType: _selectedAuthorityType,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        defaultCurrencyCode: _selectedCurrency,
        defaultPassAdvanceDays: advanceDays,
      );

      debugPrint('✅ EditAuthority: Authority updated successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authority updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        debugPrint('✅ EditAuthority: Returning true and popping screen');
        Navigator.of(context)
            .pop(true); // Return true to indicate changes were made
      }
    } catch (e, stackTrace) {
      debugPrint('❌ EditAuthority: Error updating authority: $e');
      debugPrint('❌ EditAuthority: Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating authority: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Authority'),
        backgroundColor: Colors.orange.shade100,
        foregroundColor: Colors.orange.shade800,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveChanges,
              child: const Text(
                'SAVE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Authority Info Header
              Container(
                padding: const EdgeInsets.all(16),
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
                          Icons.account_balance,
                          color: Colors.orange.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.authority.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              if (widget.authority.countryName != null)
                                Text(
                                  widget.authority.countryName!,
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
                    const SizedBox(height: 8),
                    Text(
                      'Edit the details below to update this authority',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Editable Fields
              _buildTextField(
                controller: _nameController,
                label: 'Authority Name',
                icon: Icons.business,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Authority name is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _codeController,
                label: 'Authority Code',
                icon: Icons.code,
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Authority code is required';
                  }
                  if (value.trim().length < 2) {
                    return 'Authority code must be at least 2 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              _buildDropdownField(
                value: _selectedAuthorityType,
                label: 'Authority Type',
                icon: Icons.category,
                items: _authorityTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(_getAuthorityTypeDisplayName(type)),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedAuthorityType = value!);
                },
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _descriptionController,
                label: 'Description (Optional)',
                icon: Icons.description,
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              _buildDropdownField(
                value: _selectedCurrency,
                label: 'Default Currency',
                icon: Icons.attach_money,
                items: _currencies
                    .map((currency) => DropdownMenuItem(
                          value: currency,
                          child: Text(currency),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedCurrency = value!);
                },
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _defaultPassAdvanceDaysController,
                label: 'Default Pass Advance Days (Optional)',
                icon: Icons.calendar_today,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final days = int.tryParse(value.trim());
                    if (days == null || days < 0) {
                      return 'Please enter a valid number of days (0 or greater)';
                    }
                    if (days > 365) {
                      return 'Advance days cannot exceed 365';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // Read-only Information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Read-Only Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildReadOnlyField('Authority ID', widget.authority.id),
                    _buildReadOnlyField(
                        'Country', widget.authority.countryName ?? 'Unknown'),
                    _buildReadOnlyField('Status',
                        widget.authority.isActive ? 'Active' : 'Inactive'),
                    _buildReadOnlyField(
                        'Created', _formatDate(widget.authority.createdAt)),
                    _buildReadOnlyField('Last Updated',
                        _formatDate(widget.authority.updatedAt)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
    );
  }

  Widget _buildDropdownField<T>({
    required T value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
