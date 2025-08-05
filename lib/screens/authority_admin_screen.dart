import 'package:flutter/material.dart';
import '../models/authority.dart';
import '../services/authority_service.dart';

class AuthorityAdminScreen extends StatefulWidget {
  final Map<String, dynamic> selectedCountry;
  final bool isSuperuser;

  const AuthorityAdminScreen({
    super.key,
    required this.selectedCountry,
    this.isSuperuser = false,
  });

  @override
  State<AuthorityAdminScreen> createState() => _AuthorityAdminScreenState();
}

class _AuthorityAdminScreenState extends State<AuthorityAdminScreen> {
  List<Authority> _authorities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAuthorities();
  }

  String get _countryId => widget.selectedCountry['id'] as String;
  String get _countryName => widget.selectedCountry['name'] as String;

  Future<void> _loadAuthorities() async {
    try {
      setState(() => _isLoading = true);
      
      debugPrint('🔍 AuthorityAdminScreen - Loading authorities...');
      debugPrint('  - Country ID: $_countryId');
      debugPrint('  - Country Name: $_countryName');
      debugPrint('  - Is Superuser: ${widget.isSuperuser}');
      debugPrint('  - Selected Country Data: ${widget.selectedCountry}');
      
      List<Authority> authorities;
      if (widget.isSuperuser) {
        // Superusers can see all authorities for the country
        debugPrint('🔍 Loading all authorities for country: $_countryId');
        authorities = await AuthorityService.getAuthoritiesForCountry(_countryId);
        debugPrint('🔍 Loaded ${authorities.length} authorities for country');
      } else {
        // Country admins can only see their own authority
        final authorityId = widget.selectedCountry['authority_id'] as String?;
        debugPrint('🔍 Loading single authority with ID: $authorityId');
        
        if (authorityId != null) {
          final authority = await AuthorityService.getAuthorityById(authorityId);
          debugPrint('🔍 Authority loaded: $authority');
          authorities = authority != null ? [authority] : [];
        } else {
          debugPrint('⚠️ No authority_id found in selectedCountry data!');
          authorities = [];
        }
      }
      
      debugPrint('🔍 Final authorities list: ${authorities.length} items');
      for (var auth in authorities) {
        debugPrint('  - ${auth.name} (${auth.code}) - Active: ${auth.isActive}');
      }
      
      setState(() {
        _authorities = authorities;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading authorities: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading authorities: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditAuthorityDialog([Authority? authority]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EditAuthorityDialog(
        authority: authority,
        countryId: _countryId,
        isSuperuser: widget.isSuperuser,
      ),
    );

    if (result == true) {
      _loadAuthorities();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String screenTitle = widget.isSuperuser 
        ? 'Manage Authorities - ${widget.selectedCountry['name']}'
        : 'Edit Authority - ${widget.selectedCountry['authority_name'] ?? 'Unknown'}';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildAuthoritiesList(),
          ),
        ],
      ),
      floatingActionButton: widget.isSuperuser ? FloatingActionButton.extended(
        onPressed: () => _showEditAuthorityDialog(),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Authority'),
      ) : null,
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
                  color: Colors.white.withOpacity(0.2),
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
                    Text(
                      'Authority Management',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage authorities for $_countryName',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Authorities represent government bodies like revenue services, customs, etc.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthoritiesList() {
    if (_authorities.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadAuthorities,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _authorities.length,
        itemBuilder: (context, index) {
          final authority = _authorities[index];
          return _buildAuthorityCard(authority);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.business_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Authorities Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isSuperuser 
                ? 'Create your first authority to get started'
                : 'No authority found for your account',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          if (widget.isSuperuser)
            ElevatedButton.icon(
              onPressed: () => _showEditAuthorityDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Authority'),
            ),
        ],
      ),
    );
  }

  Widget _buildAuthorityCard(Authority authority) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showEditAuthorityDialog(authority),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: authority.isActive 
                          ? Colors.green.shade100 
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.business,
                      color: authority.isActive 
                          ? Colors.green.shade700 
                          : Colors.grey.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authority.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${authority.code} • ${authority.authorityTypeDisplay}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: authority.isActive 
                          ? Colors.green.shade100 
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      authority.statusDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: authority.isActive 
                            ? Colors.green.shade700 
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              if (authority.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  authority.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.schedule,
                    'Pass Advance: ${authority.passAdvanceDays ?? 30} days',
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.monetization_on,
                    'Currency: ${authority.defaultCurrencyCode ?? 'USD'}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditAuthorityDialog extends StatefulWidget {
  final Authority? authority;
  final String countryId;
  final bool isSuperuser;

  const _EditAuthorityDialog({
    this.authority,
    required this.countryId,
    this.isSuperuser = false,
  });

  @override
  State<_EditAuthorityDialog> createState() => _EditAuthorityDialogState();
}

class _EditAuthorityDialogState extends State<_EditAuthorityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _passAdvanceDaysController = TextEditingController();
  
  String _selectedAuthorityType = 'revenue_service';
  String _selectedCurrency = 'USD';
  String? _selectedCountryId;
  bool _isActive = true;
  bool _isLoading = false;
  List<Map<String, dynamic>> _countries = [];

  final List<String> _authorityTypes = [
    'revenue_service',
    'customs',
    'immigration',
    'global',
  ];

  final List<String> _currencies = [
    // Major international currencies
    'USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'CNY', 'SEK', 'NZD',
    'MXN', 'SGD', 'HKD', 'NOK', 'TRY', 'BRL', 'INR', 'KRW', 'RUB',
    // African currencies
    'ZAR', 'KES', 'UGX', 'TZS', 'RWF', 'ETB', 'NGN', 'GHS', 'XOF', 'XAF', 
    'MAD', 'EGP', 'TND', 'DZD', 'LYD', 'SDG', 'SOS', 'DJF', 'ERN', 'MGA', 
    'MUR', 'SCR', 'SZL', 'LSL', 'BWP', 'NAD', 'ZMW', 'AOA', 'MZN', 'MWK', 'ZWL',
    // Other currencies
    'PLN', 'THB', 'IDR', 'HUF', 'CZK', 'ILS', 'CLP', 'PHP', 'AED', 'COP',
    'SAR', 'MYR', 'RON', 'BGN', 'HRK', 'ISK', 'DKK', 'QAR', 'KWD'
  ];

  @override
  void initState() {
    super.initState();
    _selectedCountryId = widget.countryId; // Default to current country
    
    // DEBUG: Log authority data
    debugPrint('🔍 EditAuthorityDialog - Authority: ${widget.authority}');
    debugPrint('🔍 EditAuthorityDialog - Country ID: ${widget.countryId}');
    debugPrint('🔍 EditAuthorityDialog - Is Superuser: ${widget.isSuperuser}');
    
    if (widget.authority != null) {
      debugPrint('🔍 EditAuthorityDialog - Populating form with authority data:');
      debugPrint('  - Name: ${widget.authority!.name}');
      debugPrint('  - Code: ${widget.authority!.code}');
      debugPrint('  - Description: ${widget.authority!.description}');
      debugPrint('  - Pass Advance Days: ${widget.authority!.passAdvanceDays}');
      debugPrint('  - Authority Type: ${widget.authority!.authorityType}');
      debugPrint('  - Default Currency: ${widget.authority!.defaultCurrencyCode}');
      debugPrint('  - Is Active: ${widget.authority!.isActive}');
      
      _nameController.text = widget.authority!.name;
      _codeController.text = widget.authority!.code;
      _descriptionController.text = widget.authority!.description ?? '';
      _passAdvanceDaysController.text = (widget.authority!.passAdvanceDays ?? 30).toString();
      _selectedAuthorityType = widget.authority!.authorityType;
      _selectedCurrency = widget.authority!.defaultCurrencyCode ?? 'USD';
      _selectedCountryId = widget.authority!.countryId;
      _isActive = widget.authority!.isActive;
      
      debugPrint('🔍 EditAuthorityDialog - Form populated successfully');
    } else {
      debugPrint('🔍 EditAuthorityDialog - No authority provided, creating new');
      _passAdvanceDaysController.text = '30';
    }
    
    // Load countries for superusers
    if (widget.isSuperuser) {
      _loadCountries();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _passAdvanceDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await AuthorityService.getAllCountries();
      setState(() {
        _countries = countries;
        // Ensure current country is selected if not already set
        if (_selectedCountryId == null && countries.isNotEmpty) {
          _selectedCountryId = countries.first['id'] as String;
        }
      });
    } catch (e) {
      debugPrint('Error loading countries: $e');
      // Fallback to current country only
      setState(() {
        _countries = [
          {'id': widget.countryId, 'name': 'Current Country', 'country_code': 'XX'},
        ];
      });
    }
  }

  String _getAuthorityTypeDisplay(String type) {
    switch (type) {
      case 'revenue_service':
        return 'Revenue Service';
      case 'customs':
        return 'Customs Authority';
      case 'immigration':
        return 'Immigration Authority';
      case 'global':
        return 'Global Authority';
      default:
        return type.replaceAll('_', ' ').split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  Future<void> _saveAuthority() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.authority != null) {
        await AuthorityService.updateAuthority(
          authorityId: widget.authority!.id,
          name: _nameController.text.trim(),
          code: _codeController.text.trim().toUpperCase(),
          authorityType: _selectedAuthorityType,
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          isActive: _isActive,
          passAdvanceDays: int.parse(_passAdvanceDaysController.text),
          defaultCurrencyCode: _selectedCurrency,
        );
      } else {
        await AuthorityService.createAuthority(
          countryId: _selectedCountryId ?? widget.countryId,
          name: _nameController.text.trim(),
          code: _codeController.text.trim().toUpperCase(),
          authorityType: _selectedAuthorityType,
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          isActive: _isActive,
          passAdvanceDays: int.parse(_passAdvanceDaysController.text),
          defaultCurrencyCode: _selectedCurrency,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.authority != null 
                ? 'Authority updated successfully!' 
                : 'Authority created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving authority: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.authority != null ? 'Edit Authority' : 'Add Authority'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Authority Name *',
                    hintText: 'e.g., Kenya Revenue Authority',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Authority name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Country selection for superusers
                if (widget.isSuperuser && widget.authority == null) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedCountryId,
                    decoration: const InputDecoration(
                      labelText: 'Country *',
                      border: OutlineInputBorder(),
                    ),
                    items: _countries.map((country) {
                      return DropdownMenuItem(
                        value: country['id'] as String,
                        child: Text('${country['name']} (${country['country_code']})')
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCountryId = value!);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a country';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Authority Code *',
                    hintText: 'e.g., KRA',
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedAuthorityType,
                  decoration: const InputDecoration(
                    labelText: 'Authority Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: _authorityTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getAuthorityTypeDisplay(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedAuthorityType = value!);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Brief description of the authority',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _passAdvanceDaysController,
                        decoration: const InputDecoration(
                          labelText: 'Pass Advance Days *',
                          hintText: '30',
                          border: OutlineInputBorder(),
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCurrency,
                        decoration: const InputDecoration(
                          labelText: 'Default Currency *',
                          border: OutlineInputBorder(),
                        ),
                        items: _currencies.map((currency) {
                          return DropdownMenuItem(
                            value: currency,
                            child: Text(currency),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedCurrency = value!);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  subtitle: Text(
                    widget.isSuperuser 
                        ? (_isActive ? 'Authority is active' : 'Authority is inactive')
                        : 'Only superusers can change active status'
                  ),
                  value: _isActive,
                  onChanged: widget.isSuperuser ? (value) {
                    setState(() => _isActive = value);
                  } : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        // DEBUG: Add debug button to show current form values
        TextButton(
          onPressed: () {
            debugPrint('🔍 DEBUG - Current form values:');
            debugPrint('  - Name: "${_nameController.text}"');
            debugPrint('  - Code: "${_codeController.text}"');
            debugPrint('  - Description: "${_descriptionController.text}"');
            debugPrint('  - Pass Advance Days: "${_passAdvanceDaysController.text}"');
            debugPrint('  - Authority Type: $_selectedAuthorityType');
            debugPrint('  - Currency: $_selectedCurrency');
            debugPrint('  - Is Active: $_isActive');
            debugPrint('  - Selected Country ID: $_selectedCountryId');
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Form values logged to console'),
                backgroundColor: Colors.blue,
              ),
            );
          },
          child: const Text('DEBUG'),
        ),
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveAuthority,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
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
              : Text(widget.authority != null ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
