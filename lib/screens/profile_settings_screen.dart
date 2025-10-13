import 'package:flutter/material.dart';
import '../models/identity_documents.dart';
import '../models/payment_details.dart';
import '../services/profile_management_service.dart';
import '../enums/pass_verification_method.dart';
import '../widgets/profile_image_widget.dart';
import '../widgets/passport_image_widget.dart';

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
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _passportController = TextEditingController();
  final _staticPinController =
      TextEditingController(); // New controller for static PIN

  // Individual PIN digit controllers
  final _pinDigit1Controller = TextEditingController();
  final _pinDigit2Controller = TextEditingController();
  final _pinDigit3Controller = TextEditingController();

  // Focus nodes for PIN digits
  final _pinDigit1Focus = FocusNode();
  final _pinDigit2Focus = FocusNode();
  final _pinDigit3Focus = FocusNode();

  // State
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _profileData;
  IdentityDocuments? _identityDocuments;
  PaymentDetails? _paymentDetails;
  PassVerificationMethod _selectedVerificationMethod =
      PassVerificationMethod.none; // Changed from bool

  // Countries data
  List<Map<String, dynamic>> _countries = [];
  String? _selectedCountryId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    _nationalIdController.dispose();
    _passportController.dispose();
    _staticPinController.dispose(); // Dispose new controller

    // Dispose PIN digit controllers and focus nodes
    _pinDigit1Controller.dispose();
    _pinDigit2Controller.dispose();
    _pinDigit3Controller.dispose();
    _pinDigit1Focus.dispose();
    _pinDigit2Focus.dispose();
    _pinDigit3Focus.dispose();

    super.dispose();
  }

  /// Validate phone number format
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone number is optional
    }

    final phoneNumber = value.trim();

    // Check if it starts with +
    if (!phoneNumber.startsWith('+')) {
      return 'Phone number must start with country code (e.g., +263)';
    }

    // Check if it contains only digits after the +
    final digitsOnly = phoneNumber.substring(1);
    if (!RegExp(r'^\d+$').hasMatch(digitsOnly)) {
      return 'Phone number can only contain digits after the country code';
    }

    // Check length (minimum 8, maximum 15 digits after +)
    if (digitsOnly.length < 7 || digitsOnly.length > 15) {
      return 'Phone number must be between 8-16 characters total';
    }

    // Check for common country codes (basic validation)
    final countryCode =
        digitsOnly.substring(0, digitsOnly.length >= 3 ? 3 : digitsOnly.length);
    final validCountryCodes = [
      '263', '27', '260', '265', '268', '254', '256', '255', '234',
      '233', // African countries (added 268 for Eswatini)
      '1', '44', '33', '49', '39', '34', '31', '32', '41',
      '43', // Western countries
      '86', '91', '81', '82', '65', '60', '66', '84', '62',
      '63', // Asian countries
    ];

    bool hasValidCountryCode = false;
    for (final code in validCountryCodes) {
      if (digitsOnly.startsWith(code)) {
        hasValidCountryCode = true;
        break;
      }
    }

    if (!hasValidCountryCode) {
      return 'Please enter a valid country code (e.g., +263 for Zimbabwe)';
    }

    return null; // Valid phone number
  }

  /// Validate email address format
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }

    final email = value.trim();

    // Basic email validation regex
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    return null; // Valid email
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
          // Filter out 'Global' country
          _countries = countries.where((c) => c['name'] != 'Global').toList();

          // Populate controllers
          _fullNameController.text =
              profileData?['full_name']?.toString() ?? '';
          _emailController.text = profileData?['email']?.toString() ?? '';
          _phoneNumberController.text =
              profileData?['phone_number']?.toString() ?? '';
          _addressController.text = profileData?['address']?.toString() ?? '';
          _selectedCountryId = identityDocs.countryOfOriginId;
          _nationalIdController.text = identityDocs.nationalIdNumber ?? '';
          _passportController.text = identityDocs.passportNumber ?? '';

          // Load payment details and preferences
          _paymentDetails = PaymentDetails.fromJson(profileData ?? {});

          // Update for new pass confirmation preferences
          final String? confirmationTypeString =
              profileData?['pass_confirmation_type']?.toString();
          switch (confirmationTypeString) {
            case 'staticPin':
              _selectedVerificationMethod = PassVerificationMethod.pin;
              break;
            case 'dynamicCode':
              _selectedVerificationMethod = PassVerificationMethod.secureCode;
              break;
            case 'none':
            default:
              _selectedVerificationMethod = PassVerificationMethod.none;
          }

          // Load existing PIN into individual digit controllers
          final String existingPin =
              profileData?['static_confirmation_code']?.toString() ?? '';
          _staticPinController.text = existingPin;
          if (existingPin.length == 3) {
            _pinDigit1Controller.text = existingPin[0];
            _pinDigit2Controller.text = existingPin[1];
            _pinDigit3Controller.text = existingPin[2];
          } else {
            _pinDigit1Controller.clear();
            _pinDigit2Controller.clear();
            _pinDigit3Controller.clear();
          }

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

  Future<void> _savePersonalInformation() async {
    // Validate all fields
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phoneNumber = _phoneNumberController.text.trim();
    final address = _addressController.text.trim();

    // Validate required fields
    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate email
    final emailError = _validateEmail(email);
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(emailError),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate phone number if provided
    if (phoneNumber.isNotEmpty) {
      final phoneError = _validatePhoneNumber(phoneNumber);
      if (phoneError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(phoneError),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    try {
      setState(() => _isSaving = true);

      await ProfileManagementService.updatePersonalInformation(
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber.isEmpty ? null : phoneNumber,
        address: address.isEmpty ? null : address,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personal information updated successfully'),
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
            content: Text('Error updating personal information: $e'),
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

  Future<void> _updatePassConfirmationPreference(
      PassVerificationMethod method) async {
    debugPrint('Selected PassVerificationMethod: ${method.name}');

    // For pin, first update the UI to show the text box
    if (method == PassVerificationMethod.pin) {
      setState(() {
        _selectedVerificationMethod = method;
      });
      // Show a message that they need to enter a PIN
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your 3-digit PIN below'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return; // Don't save yet, wait for PIN input
    }

    // For other methods, proceed with saving immediately
    try {
      setState(() => _isSaving = true);
      await ProfileManagementService.updatePassConfirmationPreference(
          method, null);
      if (mounted) {
        setState(() {
          _selectedVerificationMethod = method;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${method.label} enabled'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating preference: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _savePinPreference() async {
    // Combine the three digit controllers
    String staticPin = _pinDigit1Controller.text +
        _pinDigit2Controller.text +
        _pinDigit3Controller.text;

    if (staticPin.length != 3 || !RegExp(r'^[0-9]+$').hasMatch(staticPin)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter all 3 digits of your PIN.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      setState(() => _isSaving = true);
      await ProfileManagementService.updatePassConfirmationPreference(
          PassVerificationMethod.pin, staticPin);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personal PIN saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving PIN: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onPassportDocumentUpdated(String? documentUrl) async {
    try {
      setState(() => _isSaving = true);

      if (documentUrl != null) {
        await ProfileManagementService.updatePassportDocumentUrl(documentUrl);
      } else {
        await ProfileManagementService.removePassportDocument();
      }

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(documentUrl != null
                ? 'Passport document updated successfully'
                : 'Passport document removed successfully'),
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
            content: Text('Error updating passport document: $e'),
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
            Tab(icon: Icon(Icons.history), text: 'Audit'),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildIdentityTab(),
                  _buildPaymentTab(),
                  _buildPreferencesTab(),
                  _buildAuditTab(),
                ],
              ),
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
                  ProfileImageWidget(
                    currentImageUrl:
                        _profileData!['profile_image_url']?.toString(),
                    size: 60,
                    isEditable: true,
                    onImageUpdated: () {
                      // Refresh profile data when image is updated
                      _loadProfileData();
                    },
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

          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'Enter your email address',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _phoneNumberController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: 'Enter your phone number (e.g., +268 for Eswatini)',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
              helperText: 'Include country code (e.g., +268 Eswatini)',
            ),
            keyboardType: TextInputType.phone,
            validator: _validatePhoneNumber,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              hintText: 'Enter your residential address',
              prefixIcon: Icon(Icons.home),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _savePersonalInformation,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label:
                  Text(_isSaving ? 'Saving...' : 'Update Personal Information'),
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
            // Filter out 'Global' country
            items:
                _countries.where((c) => c['name'] != 'Global').map((country) {
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
          const SizedBox(height: 16),

          // Passport Page Upload
          const Text(
            'Passport Page',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Capture a clear photo of your entire passport page (4.9" × 3.4") for verification.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          PassportImageWidget(
            currentImageUrl: _profileData?['passport_document_url']?.toString(),
            onImageUpdated: _onPassportDocumentUpdated,
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

  Widget _buildPinDigitBox(int digitIndex) {
    TextEditingController controller;
    FocusNode focusNode;
    FocusNode? nextFocusNode;

    switch (digitIndex) {
      case 0:
        controller = _pinDigit1Controller;
        focusNode = _pinDigit1Focus;
        nextFocusNode = _pinDigit2Focus;
        break;
      case 1:
        controller = _pinDigit2Controller;
        focusNode = _pinDigit2Focus;
        nextFocusNode = _pinDigit3Focus;
        break;
      case 2:
        controller = _pinDigit3Controller;
        focusNode = _pinDigit3Focus;
        nextFocusNode = null;
        break;
      default:
        throw ArgumentError('Invalid digit index: $digitIndex');
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: Colors.blue.shade50,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
        keyboardType: TextInputType.number,
        maxLength: 1,
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
        ),
        onChanged: (value) {
          if (value.isNotEmpty && RegExp(r'^[0-9]$').hasMatch(value)) {
            // Move to next field if this isn't the last one
            if (nextFocusNode != null) {
              nextFocusNode.requestFocus();
            } else {
              // Last digit entered, check if all 3 are filled
              _checkAndAutoSave();
            }
          } else if (value.isEmpty) {
            // If user deletes, move to previous field
            if (digitIndex > 0) {
              switch (digitIndex) {
                case 1:
                  _pinDigit1Focus.requestFocus();
                  break;
                case 2:
                  _pinDigit2Focus.requestFocus();
                  break;
              }
            }
          }
        },
      ),
    );
  }

  void _checkAndAutoSave() {
    if (_pinDigit1Controller.text.isNotEmpty &&
        _pinDigit2Controller.text.isNotEmpty &&
        _pinDigit3Controller.text.isNotEmpty) {
      // All digits filled, auto-save
      _savePinPreference();
    }
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
                // No Verification option
                RadioListTile<PassVerificationMethod>(
                  title: Text(PassVerificationMethod.none.label),
                  subtitle: Text(PassVerificationMethod.none.description),
                  value: PassVerificationMethod.none,
                  groupValue: _selectedVerificationMethod,
                  onChanged: (PassVerificationMethod? newValue) async {
                    if (newValue != null) {
                      await _updatePassConfirmationPreference(newValue);
                    }
                  },
                ),

                // Personal PIN option
                RadioListTile<PassVerificationMethod>(
                  title: Text(PassVerificationMethod.pin.label),
                  subtitle: Text(PassVerificationMethod.pin.description),
                  value: PassVerificationMethod.pin,
                  groupValue: _selectedVerificationMethod,
                  onChanged: (PassVerificationMethod? newValue) async {
                    if (newValue != null) {
                      await _updatePassConfirmationPreference(newValue);
                    }
                  },
                ),

                // PIN input boxes (appears right after Personal PIN)
                if (_selectedVerificationMethod == PassVerificationMethod.pin)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    child: Column(
                      children: [
                        const Text(
                          'Enter your 3-digit PIN:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildPinDigitBox(0),
                            _buildPinDigitBox(1),
                            _buildPinDigitBox(2),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _savePinPreference,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Text('Save PIN',
                                    style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Secure Code option
                RadioListTile<PassVerificationMethod>(
                  title: Text(PassVerificationMethod.secureCode.label),
                  subtitle: Text(PassVerificationMethod.secureCode.description),
                  value: PassVerificationMethod.secureCode,
                  groupValue: _selectedVerificationMethod,
                  onChanged: (PassVerificationMethod? newValue) async {
                    if (newValue != null) {
                      await _updatePassConfirmationPreference(newValue);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedVerificationMethod ==
                            PassVerificationMethod.none
                        ? Colors.green.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _selectedVerificationMethod.description,
                    style: TextStyle(
                      color: _selectedVerificationMethod ==
                              PassVerificationMethod.none
                          ? Colors.green.shade800
                          : Colors.blue.shade800,
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

  Widget _buildAuditTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile Audit History',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track all changes made to your profile settings.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ProfileManagementService.getProfileAuditHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade600, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Error loading audit history',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        snapshot.error.toString(),
                        style:
                            TextStyle(color: Colors.red.shade600, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final auditHistory = snapshot.data ?? [];

              if (auditHistory.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.history,
                          color: Colors.grey.shade400, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'No Changes Yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your profile changes will appear here once you start making updates.',
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: auditHistory.map((audit) {
                  final changeType =
                      audit['change_type']?.toString() ?? 'update';
                  final fieldName =
                      audit['field_name']?.toString() ?? 'Unknown';
                  final oldValue = audit['old_value']?.toString();
                  final newValue = audit['new_value']?.toString();
                  final changedAt = audit['changed_at'] != null
                      ? DateTime.parse(audit['changed_at'].toString())
                      : DateTime.now();
                  final changedBy =
                      audit['changed_by_name']?.toString() ?? 'System';
                  final notes = audit['notes']?.toString();

                  Color changeColor;
                  IconData changeIcon;

                  switch (changeType) {
                    case 'create':
                      changeColor = Colors.green;
                      changeIcon = Icons.add_circle;
                      break;
                    case 'delete':
                      changeColor = Colors.red;
                      changeIcon = Icons.remove_circle;
                      break;
                    default:
                      changeColor = Colors.blue;
                      changeIcon = Icons.edit;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade100,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(changeIcon, color: changeColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatFieldName(fieldName),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: changeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                changeType.toUpperCase(),
                                style: TextStyle(
                                  color: changeColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (changeType != 'create') ...[
                          if (oldValue != null && oldValue.isNotEmpty) ...[
                            const Text(
                              'From:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _formatFieldValue(fieldName, oldValue),
                              style: const TextStyle(
                                fontSize: 14,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ],
                        if (changeType != 'delete' && newValue != null) ...[
                          const Text(
                            'To:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatFieldValue(fieldName, newValue),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '${changedAt.toLocal().toString().split('.')[0]} by $changedBy',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        if (notes != null && notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.note,
                                    size: 14, color: Colors.blue.shade600),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    notes,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade800,
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
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatFieldName(String fieldName) {
    switch (fieldName) {
      case 'full_name':
        return 'Full Name';
      case 'email':
        return 'Email Address';
      case 'phone_number':
        return 'Phone Number';
      case 'address':
        return 'Address';
      case 'country_of_origin_id':
        return 'Country of Origin';
      case 'national_id_number':
        return 'National ID Number';
      case 'passport_number':
        return 'Passport Number';
      case 'passport_document_url':
        return 'Passport Document';
      case 'profile_image_url':
        return 'Profile Image';
      case 'pass_confirmation_type':
        return 'Pass Verification Method';
      case 'static_confirmation_code':
        return 'Personal PIN';
      default:
        return fieldName
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isNotEmpty
                ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                : word)
            .join(' ');
    }
  }

  String _formatFieldValue(String fieldName, String value) {
    if (value.isEmpty) return '(empty)';

    switch (fieldName) {
      case 'passport_document_url':
      case 'profile_image_url':
        return value.contains('/') ? 'Document uploaded' : value;
      case 'static_confirmation_code':
        return '***';
      case 'pass_confirmation_type':
        switch (value) {
          case 'none':
            return 'No verification required';
          case 'staticPin':
            return 'Personal PIN';
          case 'dynamicCode':
            return 'Secure code via SMS/Email';
          default:
            return value;
        }
      default:
        return value;
    }
  }
}
