import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/profile_management_service.dart';

class OwnerDetailsPopup extends StatefulWidget {
  final String ownerId;
  final String? ownerName;

  const OwnerDetailsPopup({
    super.key,
    required this.ownerId,
    this.ownerName,
  });

  @override
  State<OwnerDetailsPopup> createState() => _OwnerDetailsPopupState();
}

class _OwnerDetailsPopupState extends State<OwnerDetailsPopup> {
  Map<String, dynamic>? _ownerData;
  Map<String, dynamic>? _identityData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOwnerDetails();
  }

  Future<void> _loadOwnerDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Validate UUID format
      if (!_isValidUUID(widget.ownerId)) {
        throw Exception('Invalid owner ID format');
      }

      // Load owner profile data and identity documents
      final results = await Future.wait([
        _getOwnerProfile(widget.ownerId),
        ProfileManagementService.getIdentityDocumentsForProfile(widget.ownerId),
      ]);

      if (mounted) {
        setState(() {
          _ownerData = results[0];
          _identityData = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool _isValidUUID(String uuid) {
    if (uuid.isEmpty) return false;

    // UUID regex pattern
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

    return uuidRegex.hasMatch(uuid);
  }

  Future<Map<String, dynamic>?> _getOwnerProfile(String profileId) async {
    try {
      final response = await ProfileManagementService.getProfileById(profileId);
      return response;
    } catch (e) {
      throw Exception('Failed to get owner profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Owner Details',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorState()
                      : _buildOwnerDetails(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Owner Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOwnerDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerDetails() {
    if (_ownerData == null) {
      return const Center(
        child: Text('No owner information available'),
      );
    }

    // Debug: Print owner data keys (without sensitive URLs)
    debugPrint('🔍 Owner Data Keys: ${_ownerData!.keys.toList()}');

    // Check if passport document URL exists and is not empty
    final passportUrl = _ownerData!['passport_document_url']?.toString();
    final hasPassportUrl =
        passportUrl != null && passportUrl.isNotEmpty && passportUrl != 'null';

    debugPrint('🔍 Has Passport URL: $hasPassportUrl');
    debugPrint('🔍 Passport URL Value: $passportUrl');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Image and Basic Info
          _buildProfileSection(),
          const SizedBox(height: 24),

          // Passport Image (if available)
          if (hasPassportUrl) ...[
            _buildPassportImageSection(),
            const SizedBox(height: 24),
          ],

          // Personal Information
          _buildPersonalInfoSection(),
          const SizedBox(height: 24),

          // Identity Documents
          if (_identityData != null) ...[
            _buildIdentitySection(),
            const SizedBox(height: 24),
          ],

          // Contact Information
          _buildContactSection(),
          const SizedBox(height: 24),

          // Passport Page (duplicate section - let's keep only one)
          if (hasPassportUrl) ...[
            _buildPassportSection(),
            const SizedBox(height: 24),
          ],

          // Additional Information
          _buildAdditionalInfoSection(),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          // Profile Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue.shade300, width: 2),
            ),
            child: ClipOval(
              child: _ownerData!['profile_image_url'] != null
                  ? Image.network(
                      _ownerData!['profile_image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey.shade400,
                        );
                      },
                    )
                  : Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // Basic Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ownerData!['full_name']?.toString() ?? 'Unknown Owner',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (_ownerData!['email'] != null)
                  Text(
                    _ownerData!['email'].toString(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Vehicle Owner',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  Widget _buildPersonalInfoSection() {
    return _buildSection(
      title: 'Personal Information',
      icon: Icons.person_outline,
      children: [
        _buildInfoRow('Full Name', _ownerData!['full_name']?.toString()),
        _buildInfoRow('Email', _ownerData!['email']?.toString()),
        _buildInfoRow('Phone Number', _ownerData!['phone_number']?.toString()),
        _buildInfoRow('Address', _ownerData!['address']?.toString()),
      ],
    );
  }

  Widget _buildIdentitySection() {
    return _buildSection(
      title: 'Identity Documents',
      icon: Icons.badge_outlined,
      children: [
        _buildInfoRow('Country', _identityData!['country_name']?.toString()),
        _buildInfoRow(
            'Country Code', _identityData!['country_code']?.toString()),
        _buildInfoRow(
            'National ID', _identityData!['national_id_number']?.toString()),
        _buildInfoRow(
            'Passport Number', _identityData!['passport_number']?.toString()),
      ],
    );
  }

  Widget _buildContactSection() {
    return _buildSection(
      title: 'Contact Information',
      icon: Icons.contact_phone_outlined,
      children: [
        _buildInfoRow('Primary Email', _ownerData!['email']?.toString()),
        _buildInfoRow('Phone Number', _ownerData!['phone_number']?.toString()),
        _buildInfoRow(
            'Residential Address', _ownerData!['address']?.toString()),
      ],
    );
  }

  Widget _buildPassportImageSection() {
    final passportUrl = _ownerData!['passport_document_url']?.toString() ?? '';

    debugPrint('🖼️ Building passport image section');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.document_scanner_outlined,
                    size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Passport Page',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Passport image with proper aspect ratio
                AspectRatio(
                  aspectRatio: 4.9 / 3.4, // Passport page dimensions
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        passportUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey.shade100,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 8),
                                Text('Loading passport page...'),
                              ],
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('❌ Error loading passport image: $error');
                          return Container(
                            color: Colors.grey.shade100,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error,
                                    size: 32, color: Colors.red),
                                const SizedBox(height: 8),
                                const Text('Error loading passport page'),
                                const SizedBox(height: 4),
                                Text(
                                  'URL: $passportUrl',
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // View full size button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _viewFullPassport(),
                    icon: const Icon(Icons.fullscreen),
                    label: const Text('View Full Size'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
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

  Widget _buildPassportSection() {
    final passportUrl = _ownerData!['passport_document_url']?.toString();
    final hasPassportUrl =
        passportUrl != null && passportUrl.isNotEmpty && passportUrl != 'null';

    return _buildSection(
      title: 'Passport Information',
      icon: Icons.badge_outlined,
      children: [
        _buildInfoRow(
            'Passport Number', _ownerData!['passport_number']?.toString()),
        _buildInfoRow(
            'Document Status', hasPassportUrl ? 'Uploaded' : 'Not uploaded'),
      ],
    );
  }

  Widget _buildAdditionalInfoSection() {
    return _buildSection(
      title: 'Additional Information',
      icon: Icons.info_outline,
      children: [
        _buildInfoRow(
            'Profile Created', _formatDate(_ownerData!['created_at'])),
        _buildInfoRow('Last Updated', _formatDate(_ownerData!['updated_at'])),
        _buildInfoRow('Profile ID', widget.ownerId),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Not provided',
              style: TextStyle(
                color: value != null ? Colors.black87 : Colors.grey.shade500,
                fontStyle: value != null ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Not available';
    try {
      final date = DateTime.parse(dateValue.toString());
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _viewFullPassport() {
    final passportUrl = _ownerData!['passport_document_url']?.toString();

    if (passportUrl != null &&
        passportUrl.isNotEmpty &&
        passportUrl != 'null') {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Passport Page',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: InteractiveViewer(
                    child: Image.network(
                      passportUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, size: 64, color: Colors.red),
                              SizedBox(height: 16),
                              Text('Error loading passport image'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}
