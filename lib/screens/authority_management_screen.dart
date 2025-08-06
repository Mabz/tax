/// Simplified Authority Management Screen
/// Allows country administrators to edit the selected authority's details
library;

import 'package:flutter/material.dart';
import '../models/authority.dart';
import '../services/authority_service.dart';

class AuthorityManagementScreen extends StatefulWidget {
  final Authority selectedAuthority;

  const AuthorityManagementScreen({
    super.key,
    required this.selectedAuthority,
  });

  @override
  State<AuthorityManagementScreen> createState() =>
      _AuthorityManagementScreenState();
}

class _AuthorityManagementScreenState extends State<AuthorityManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _advanceDaysController = TextEditingController();

  String _selectedAuthorityType = 'revenue_service';
  String _selectedCurrency = 'USD';
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _wasUpdated = false; // Track if authority was updated

  // Keep track of the current authority state for change detection
  late Authority _currentAuthority;

  final List<String> _currencies = [
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'AUD',
    'CAD',
    'CHF',
    'CNY',
    'SEK',
    'NZD',
    'ZAR',
    'KES',
    'UGX',
    'TZS',
    'RWF',
    'ETB',
    'NGN',
    'GHS',
    'XOF',
    'XAF',
    'MAD',
    'EGP',
    'TND',
    'DZD',
    'BWP',
    'NAD',
    'ZMW',
    'MUR',
    'SCR',
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
    _advanceDaysController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    _currentAuthority = widget.selectedAuthority;

    _nameController.text = _currentAuthority.name;
    _codeController.text = _currentAuthority.code;
    _descriptionController.text = _currentAuthority.description ?? '';
    _advanceDaysController.text =
        (_currentAuthority.defaultPassAdvanceDays ?? 30).toString();
    _selectedAuthorityType = _currentAuthority.authorityType;
    _selectedCurrency = _currentAuthority.defaultCurrencyCode ?? 'USD';

    // Add listeners to detect changes
    _nameController.addListener(_onFieldChanged);
    _codeController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _advanceDaysController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    final hasChanges = _nameController.text != _currentAuthority.name ||
        _codeController.text != _currentAuthority.code ||
        _descriptionController.text != (_currentAuthority.description ?? '') ||
        _advanceDaysController.text !=
            (_currentAuthority.defaultPassAdvanceDays ?? 30).toString() ||
        _selectedAuthorityType != _currentAuthority.authorityType ||
        _selectedCurrency != (_currentAuthority.defaultCurrencyCode ?? 'USD');

    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  Future<void> _showSaveConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Changes'),
        content: const Text(
            'Are you sure you want to save these changes to the authority?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _saveChanges();
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthorityService.updateAuthority(
        authorityId: widget.selectedAuthority.id,
        name: _nameController.text.trim(),
        code: _codeController.text.trim().toUpperCase(),
        authorityType: _selectedAuthorityType,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        defaultPassAdvanceDays: int.parse(_advanceDaysController.text),
        defaultCurrencyCode: _selectedCurrency,
        isActive:
            widget.selectedAuthority.isActive, // Keep current active status
      );

      if (mounted) {
        // Update the current authority state with the new values
        _currentAuthority = _currentAuthority.copyWith(
          name: _nameController.text.trim(),
          code: _codeController.text.trim().toUpperCase(),
          authorityType: _selectedAuthorityType,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          passAdvanceDays: int.parse(_advanceDaysController.text),
          defaultCurrencyCode: _selectedCurrency,
          updatedAt: DateTime.now(),
        );

        setState(() {
          _hasChanges = false;
          _isLoading = false;
          _wasUpdated = true; // Mark as updated
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authority updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating authority: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Authority'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(_wasUpdated);
          },
        ),
        actions: [
          if (_hasChanges && !_isLoading)
            TextButton(
              onPressed: _showSaveConfirmation,
              child: const Text(
                'SAVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildForm(),
          ),
        ],
      ),
      floatingActionButton: _hasChanges && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _showSaveConfirmation,
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.orange.shade700,
            Colors.orange.shade600,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Authority Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Edit details for ${_currentAuthority.name}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Authority Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Authority Name *',
                hintText: 'e.g., Kenya Revenue Authority',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Authority name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Authority Code
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Authority Code *',
                hintText: 'e.g., KRA',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.code),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Authority code is required';
                }
                if (value.trim().length < 2) {
                  return 'Code must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Authority Type
            DropdownButtonFormField<String>(
              value: _selectedAuthorityType,
              decoration: const InputDecoration(
                labelText: 'Authority Type *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: AuthorityService.getAuthorityTypes().map((type) {
                return DropdownMenuItem(
                  value: type['value'],
                  child: Text(type['label']!),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedAuthorityType = value!;
                });
                _onFieldChanged();
              },
            ),
            const SizedBox(height: 20),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Brief description of the authority',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Default Currency and Advance Days Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Default Currency *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monetization_on),
                    ),
                    items: _currencies.map((currency) {
                      return DropdownMenuItem(
                        value: currency,
                        child: Text(currency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCurrency = value!;
                      });
                      _onFieldChanged();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _advanceDaysController,
                    decoration: const InputDecoration(
                      labelText: 'Advance Days *',
                      hintText: '30',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      final days = int.tryParse(value);
                      if (days == null || days < 1 || days > 365) {
                        return 'Must be 1-365 days';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Current Status Info (Read-only)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Authority Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                        'Country', _currentAuthority.countryName ?? 'Unknown'),
                    _buildInfoRow('Status', _currentAuthority.statusDisplay),
                    _buildInfoRow(
                        'Created', _formatDate(_currentAuthority.createdAt)),
                    _buildInfoRow('Last Updated',
                        _formatDate(_currentAuthority.updatedAt)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
              style: const TextStyle(
                fontWeight: FontWeight.w400,
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
