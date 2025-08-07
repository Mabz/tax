import 'package:flutter/material.dart';
import 'package:flutter_supabase_auth/models/identity_documents.dart';
import 'package:flutter_supabase_auth/models/payment_details.dart';
import 'package:flutter_supabase_auth/services/profile_management_service.dart';
import 'package:flutter_supabase_auth/enums/pass_verification_method.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers
  final _fullNameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _passportController = TextEditingController();

  // State
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _profileData;
  IdentityDocuments? _identityDocuments;
  PaymentDetails? _paymentDetails;
  bool _requirePassConfirmation = false;

  // Countries data
  List<Map<String, dynamic>> _countries = [];
  String? _selectedCountryId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullNameController.dispose();
    _nationalIdController.dispose();
    _passportController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      setState(() => _isLoading = true);

      // Load all data in parallel
      final results = await Future.wait([
        ProfileManagementService.getMyProfile(),
        ProfileManagementService.getMyIdentityDocuments(),
        ProfileManagementService.getAllCountriesForSelection(),
      ]);

      final profileData = results[0] as Map<String, dynamic>?;
      final identityDocs = results[1] as IdentityDocuments;
      final countries = results[2] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _profileData = profileData;
          _identityDocuments = identityDocs;
          // Filter out GLOBAL country code from country selection
          _countries = countries
              .where((country) =>
                  country['country_code']?.toString().toUpperCase() != 'GLOBAL')
              .toList();

          // Populate controllers
          _fullNameController.text =
              profileData?['full_name']?.toString() ?? '';
          _selectedCountryId = identityDocs.countryOfOriginId;
          _nationalIdController.text = identityDocs.nationalIdNumber ?? '';
          _passportController.text = identityDocs.passportNumber ?? '';

          // Load payment details and preferences
          _paymentDetails = PaymentDetails.fromJson(profileData ?? {});
          _requirePassConfirmation =
              profileData?['require_manual_pass_confirmation'] ?? false;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveFullName() async {
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() => _isSaving = true);

      await ProfileManagementService.updateFullName(
        _fullNameController.text.trim(),
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Full name updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadProfileData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating full name: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveIdentityDocuments() async {
    if (_selectedCountryId == null ||
        _nationalIdController.text.trim().isEmpty ||
        _passportController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all identity document fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() => _isSaving = true);

      await ProfileManagementService.updateIdentityDocuments(
        countryOfOriginId: _selectedCountryId!,
        nationalIdNumber: _nationalIdController.text.trim(),
        passportNumber: _passportController.text.trim(),
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identity documents updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadProfileData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating identity documents: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updatePassConfirmationPreference(bool value) async {
    try {
      await ProfileManagementService.updatePassConfirmationPreference(
        value ? PassVerificationMethod.pin : PassVerificationMethod.none,
        null, // PIN is not collected by this UI
      );
      setState(() => _requirePassConfirmation = value);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value
                ? 'Manual pass confirmation enabled'
                : 'Manual pass confirmation disabled'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating preference: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearPaymentDetails() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Payment Details'),
        content: const Text(
          'Are you sure you want to remove all saved payment information? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ProfileManagementService.clearPaymentDetails();
        await _loadProfileData(); // Refresh data

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment details cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing payment details: $e'),
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
        title: const Text('Profile Settings'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Identity'),
            Tab(icon: Icon(Icons.payment), text: 'Payment'),
            Tab(icon: Icon(Icons.settings), text: 'Preferences'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildIdentityTab(),
                _buildPaymentTab(),
                _buildPreferencesTab(),
              ],
            ),
    );
  }

  Widget _buildIdentityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Information Card
          if (_profileData != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade600,
                    child: Text(
                      (_profileData!['full_name']?.toString() ?? 'U')[0]
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profileData!['full_name']?.toString() ??
                              'Unknown User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _profileData!['email']?.toString() ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Focus on the full name field for editing
                      FocusScope.of(context).requestFocus(FocusNode());
                    },
                    icon: Icon(
                      Icons.edit,
                      color: Colors.blue.shade600,
                    ),
                    tooltip: 'Edit full name',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Full Name Section
          const Text(
            'Personal Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Update your personal details as they appear on official documents.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              hintText: 'Enter your full name as it appears on documents',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveFullName,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Update Full Name'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 32),

          const Text(
            'Identity Documents',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your identity information is used for border crossing verification.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Country of Origin Dropdown
          DropdownButtonFormField<String>(
            value: _selectedCountryId,
            decoration: const InputDecoration(
              labelText: 'Country of Origin',
              hintText: 'Select your country of origin',
              prefixIcon: Icon(Icons.flag),
              border: OutlineInputBorder(),
            ),
            items: _countries.map((country) {
              return DropdownMenuItem<String>(
                value: country['id'].toString(),
                child: Text('${country['name']} (${country['country_code']})'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedCountryId = value);
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select your country of origin';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _nationalIdController,
            decoration: const InputDecoration(
              labelText: 'National ID Number',
              hintText: 'e.g., 8001015009087',
              prefixIcon: Icon(Icons.credit_card),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passportController,
            decoration: const InputDecoration(
              labelText: 'Passport Number',
              hintText: 'e.g., A12345678',
              prefixIcon: Icon(Icons.book),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveIdentityDocuments,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label:
                  Text(_isSaving ? 'Saving...' : 'Update Identity Documents'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          // Show last updated info if available
          if (_identityDocuments?.updatedAt != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last updated: ${_identityDocuments!.updatedAt!.toLocal().toString().split('.')[0]}',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage your saved payment methods for quick pass purchases.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (_paymentDetails?.hasPaymentMethod == true) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.credit_card, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Saved Payment Method',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Card Holder: ${_paymentDetails!.cardHolderName}'),
                  Text('Card: •••• •••• •••• ${_paymentDetails!.cardLast4}'),
                  Text('Expires: ${_paymentDetails!.displayExpiry}'),
                  if (_paymentDetails!.paymentProvider != null)
                    Text('Provider: ${_paymentDetails!.paymentProvider}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _clearPaymentDetails,
                icon: const Icon(Icons.delete),
                label: const Text('Clear Payment Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.credit_card_off,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'No Payment Method Saved',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Payment details will be saved automatically when you make your first pass purchase.',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    const Text(
                      'Security Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Only card metadata is stored (holder name, last 4 digits, expiry)',
                ),
                const Text(
                  '• Full card numbers and CVV codes are never saved',
                ),
                const Text(
                  '• All data is encrypted and stored securely',
                ),
                const Text(
                  '• You can remove payment details at any time',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pass Preferences',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Configure how your passes are handled.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manual Pass Confirmation',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Require manual confirmation before pass activation',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _requirePassConfirmation,
                      onChanged: _updatePassConfirmationPreference,
                      activeColor: Colors.blue.shade600,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _requirePassConfirmation
                        ? Colors.orange.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _requirePassConfirmation
                        ? 'When enabled, you will need to manually confirm each pass before it becomes active. This gives you more control but requires additional steps.'
                        : 'When disabled, passes will be automatically activated upon purchase. This provides a seamless experience.',
                    style: TextStyle(
                      color: _requirePassConfirmation
                          ? Colors.orange.shade800
                          : Colors.green.shade800,
                      fontSize: 12,
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
}
