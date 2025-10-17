import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import '../models/purchased_pass.dart';
import '../services/pass_service.dart';
import '../services/pass_verification_service.dart';

import '../services/enhanced_border_service.dart';
import '../services/profile_management_service.dart';
import '../services/border_selection_service.dart';
import '../enums/pass_verification_method.dart';
import '../widgets/pass_card_widget.dart';
import '../widgets/owner_details_popup.dart';
import '../widgets/pass_history_widget.dart';
import '../utils/time_utils.dart';
import '../screens/vehicle_search_screen.dart';

enum AuthorityRole { localAuthority, borderOfficial }

enum ValidationPreference { direct, pin, secureCode }

enum ValidationStep {
  scanning,
  passDetails,
  verification,
  processing,
  completed
}

class AuthorityValidationScreen extends StatefulWidget {
  final AuthorityRole role;
  final String? currentAuthorityId;
  final String? currentCountryId;

  const AuthorityValidationScreen({
    super.key,
    required this.role,
    this.currentAuthorityId,
    this.currentCountryId,
  });

  @override
  State<AuthorityValidationScreen> createState() =>
      _AuthorityValidationScreenState();
}

class _AuthorityValidationScreenState extends State<AuthorityValidationScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _backupCodeController = TextEditingController();
  final TextEditingController _secureCodeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Individual PIN digit controllers (3-digit PIN)
  final _pinDigit1Controller = TextEditingController();
  final _pinDigit2Controller = TextEditingController();
  final _pinDigit3Controller = TextEditingController();

  // Focus nodes for PIN digits
  final _pinDigit1Focus = FocusNode();
  final _pinDigit2Focus = FocusNode();
  final _pinDigit3Focus = FocusNode();

  // Individual Secure Code digit controllers (3-digit Secure Code)
  final _secureDigit1Controller = TextEditingController();
  final _secureDigit2Controller = TextEditingController();
  final _secureDigit3Controller = TextEditingController();

  // Focus nodes for Secure Code digits
  final _secureDigit1Focus = FocusNode();
  final _secureDigit2Focus = FocusNode();
  final _secureDigit3Focus = FocusNode();

  // Error state for secure code UI
  bool _secureCodeHasError = false;

  MobileScannerController? controller;
  ValidationStep _currentStep = ValidationStep.scanning;
  PurchasedPass? _scannedPass;
  ValidationPreference? _validationPreference;

  bool _isProcessing = false;
  String? _errorMessage;
  bool _useBackupCode = false;

  // Scan purpose and notes
  String? _selectedScanPurpose; // No default - force user to select
  String? _currentMovementId; // Track the movement ID for updates
  final List<Map<String, String>> _scanPurposes = [
    {'value': 'routine_check', 'label': 'Routine Check'},
    {'value': 'roadblock', 'label': 'Roadblock'},
    {'value': 'investigation', 'label': 'Investigation'},
    {'value': 'compliance_audit', 'label': 'Compliance Audit'},
    // Removed 'border_control' - not relevant for local authority
  ];

  // Location tracking
  double? _currentLatitude;
  double? _currentLongitude;
  bool _locationPermissionGranted = false;

  // Enhanced border control state
  PassActionInfo? _passAction;
  PassMovementResult? _movementResult;
  PassVerificationMethod? _verificationMethod;
  List<PassMovement>? _passHistory;

  // Helper method to get verification method
  Future<PassVerificationMethod> _getVerificationMethod(String passId) async {
    try {
      return await ProfileManagementService.getPassOwnerVerificationPreference(
          passId);
    } catch (e) {
      debugPrint('Error getting verification method: $e');
      return PassVerificationMethod.none;
    }
  }

  // QR Scanner cooldown management
  DateTime? _lastScanAttempt;
  bool _scanningEnabled = true;
  static const Duration _scanCooldownDuration = Duration(seconds: 3);
  Timer? _cooldownTimer;

  @override
  void dispose() {
    controller?.dispose();
    _backupCodeController.dispose();
    _secureCodeController.dispose();
    _notesController.dispose();

    // Dispose PIN digit controllers and focus nodes
    _pinDigit1Controller.dispose();
    _pinDigit2Controller.dispose();
    _pinDigit3Controller.dispose();
    _pinDigit1Focus.dispose();
    _pinDigit2Focus.dispose();
    _pinDigit3Focus.dispose();

    // Dispose Secure Code digit controllers and focus nodes
    _secureDigit1Controller.dispose();
    _secureDigit2Controller.dispose();
    _secureDigit3Controller.dispose();
    _secureDigit1Focus.dispose();
    _secureDigit2Focus.dispose();
    _secureDigit3Focus.dispose();

    // Cancel cooldown timer if active
    _cooldownTimer?.cancel();

    super.dispose();
  }

  // 3-box secure code input similar to PIN UI
  Widget _buildSecureDigitBox(int digitIndex) {
    TextEditingController controller;
    FocusNode focusNode;
    FocusNode? nextFocusNode;

    switch (digitIndex) {
      case 0:
        controller = _secureDigit1Controller;
        focusNode = _secureDigit1Focus;
        nextFocusNode = _secureDigit2Focus;
        break;
      case 1:
        controller = _secureDigit2Controller;
        focusNode = _secureDigit2Focus;
        nextFocusNode = _secureDigit3Focus;
        break;
      case 2:
        controller = _secureDigit3Controller;
        focusNode = _secureDigit3Focus;
        nextFocusNode = null;
        break;
      default:
        controller = _secureDigit1Controller;
        focusNode = _secureDigit1Focus;
        nextFocusNode = _secureDigit2Focus;
    }

    return SizedBox(
      width: 64,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _secureCodeHasError
                  ? Colors.red.shade400
                  : Colors.grey.shade400,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _secureCodeHasError ? Colors.red.shade600 : Colors.orange,
              width: 2,
            ),
          ),
        ),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        onChanged: (value) {
          if (value.length == 1) {
            if (nextFocusNode != null) {
              nextFocusNode.requestFocus();
            } else {
              // Last digit entered, unfocus
              focusNode.unfocus();
            }
          } else if (value.isEmpty) {
            // If user deletes, move to previous field
            if (digitIndex > 0) {
              switch (digitIndex) {
                case 1:
                  _secureDigit1Focus.requestFocus();
                  break;
                case 2:
                  _secureDigit2Focus.requestFocus();
                  break;
              }
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.role == AuthorityRole.localAuthority
            ? 'Authority Validation'
            : 'Border Control'),
        backgroundColor: widget.role == AuthorityRole.localAuthority
            ? Colors.blue.shade600
            : Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentStep == ValidationStep.scanning) ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _showVehicleSearch,
              tooltip: 'Search by Vehicle',
            ),
            IconButton(
              icon: Icon(_useBackupCode ? Icons.qr_code : Icons.keyboard),
              onPressed: () {
                setState(() {
                  _useBackupCode = !_useBackupCode;
                  _errorMessage = null;
                });
              },
              tooltip:
                  _useBackupCode ? 'Switch to QR Scanner' : 'Enter Backup Code',
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case ValidationStep.scanning:
        return _buildScanningStep();
      case ValidationStep.passDetails:
        return _buildPassDetailsStep();
      case ValidationStep.verification:
        return _buildVerificationStep();
      case ValidationStep.processing:
        return _buildProcessingStep();
      case ValidationStep.completed:
        return _buildCompletedStep();
    }
  }

  Widget _buildScanningStep() {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.role == AuthorityRole.localAuthority
                ? Colors.blue.shade600
                : Colors.green.shade600,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Icon(
                widget.role == AuthorityRole.localAuthority
                    ? Icons.verified_user
                    : Icons.border_clear,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                widget.role == AuthorityRole.localAuthority
                    ? 'Scan Pass for Validation'
                    : 'Scan Pass for Entry Deduction',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _useBackupCode
                    ? 'Enter the 8-character backup code (XXXX-XXXX)'
                    : _getScanningStatusText(),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Scanner or Backup Code Input
        Expanded(
          child: _useBackupCode ? _buildBackupCodeInput() : _buildQRScanner(),
        ),

        // Error Message
        if (_errorMessage != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQRScanner() {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: MobileScanner(
          controller: controller,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null && _canProcessScan()) {
                _validateQRCode(barcode.rawValue!);
                break;
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildBackupCodeInput() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.keyboard,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Enter Backup Code',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _backupCodeController,
            decoration: InputDecoration(
              hintText: 'XXXX-XXXX',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.confirmation_number),
              counterText: '',
            ),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900, // Extra bold for clarity
              letterSpacing: 3, // Increased spacing
              fontFamily: 'Courier', // More distinctive monospace font
              height: 1.2, // Better line height
            ),
            textCapitalization:
                TextCapitalization.characters, // Force uppercase
            textAlign: TextAlign.center,
            maxLength: 9, // 8 + 1 hyphen
            inputFormatters: [
              UpperCaseTextFormatter(), // Force uppercase
              FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9-]')),
              _BackupCodeFormatter(),
            ],
            onChanged: (value) {
              // Validate when exact pattern is reached
              if (RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(value)) {
                _validateBackupCode(value);
              } else {
                setState(() {}); // update button enabled state
              }
            },
            onSubmitted: (value) {
              if (RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(value)) {
                _validateBackupCode(value);
              }
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: Builder(builder: (context) {
              final canSubmit = RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$')
                  .hasMatch(_backupCodeController.text);
              return ElevatedButton(
                onPressed: canSubmit
                    ? () => _validateBackupCode(_backupCodeController.text)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.role == AuthorityRole.localAuthority
                      ? Colors.blue.shade600
                      : Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Validate Code',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              );
            }),
          ),
        ],
      ),
    );

    // Always allow scrolling with bottom padding matching keyboard inset to avoid layout thrashing
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
        child: Align(
          alignment: Alignment.topCenter,
          child: content,
        ),
      ),
    );
  }

  Widget _buildPassDetailsStep() {
    if (_scannedPass == null) return const SizedBox();

    final pass = _scannedPass!;
    final isActive = pass.isActive;

    return Column(
      children: [
        // Consolidated Pass Information and Scan Controls
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pass Card Widget
                PassCardWidget(
                  pass: pass,
                  showQrCode: false,
                  showDetails: true,
                  isCompact: true,
                  showSecureCode: false,
                  showPassHistory: false, // Disable pass history button here
                ),

                const SizedBox(height: 16),

                // Owner Details Section
                _buildOwnerDetailsSection(pass),

                const SizedBox(height: 16),

                // Enhanced Border Control Information (for Border Officials)
                if (widget.role == AuthorityRole.borderOfficial &&
                    _passAction != null) ...[
                  Card(
                    color: Colors.orange.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _passAction!.isCheckIn
                                    ? Icons.login
                                    : Icons.logout,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ready to ${_passAction!.actionDescription}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Current Status: ${_passAction!.currentStatus}'),
                          Text('Vehicle Status: ${pass.vehicleStatusDisplay}'),
                          if (_passAction!.willDeductEntry)
                            const Text(
                              'This action will deduct 1 entry',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.orange,
                              ),
                            ),
                          if (_verificationMethod != null)
                            Text(
                                'Verification: ${_verificationMethod!.displayName}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Movement History (if available)
                if (_passHistory != null && _passHistory!.isNotEmpty) ...[
                  SafeArea(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.history, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  'Movement History',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...(_passHistory!.take(3).map((movement) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getMovementIcon(movement.movementType),
                                        size: 16,
                                        color: _getMovementColor(
                                            movement.movementType),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _getMovementTitle(movement),
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                            Text(
                                              _getOfficialName(movement),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            // Show location if available
                                            // Always show location info for debugging
                                            Builder(
                                              builder: (context) {
                                                debugPrint(
                                                    '🌍 Movement coordinates: ${movement.latitude}, ${movement.longitude}');

                                                if (movement.latitude != 0.0 &&
                                                    movement.longitude != 0.0) {
                                                  return FutureBuilder<String>(
                                                    future: _getLocationName(
                                                        movement.latitude,
                                                        movement.longitude),
                                                    builder:
                                                        (context, snapshot) {
                                                      debugPrint(
                                                          '🌍 FutureBuilder state: ${snapshot.connectionState}');
                                                      debugPrint(
                                                          '🌍 Has data: ${snapshot.hasData}');
                                                      debugPrint(
                                                          '🌍 Has error: ${snapshot.hasError}');
                                                      if (snapshot.hasError) {
                                                        debugPrint(
                                                            '🌍 Error: ${snapshot.error}');
                                                      }
                                                      if (snapshot.hasData) {
                                                        debugPrint(
                                                            '🌍 Data: ${snapshot.data}');
                                                        return Text(
                                                          'Location: ${snapshot.data}',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey.shade500,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                        );
                                                      } else if (snapshot
                                                              .connectionState ==
                                                          ConnectionState
                                                              .waiting) {
                                                        return Text(
                                                          'Location: Loading...',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey.shade400,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                        );
                                                      } else if (snapshot
                                                          .hasError) {
                                                        return Text(
                                                          'Location: Error - ${movement.latitude.toStringAsFixed(4)}, ${movement.longitude.toStringAsFixed(4)}',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .red.shade400,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                        );
                                                      }
                                                      return Text(
                                                        'Location: ${movement.latitude.toStringAsFixed(4)}, ${movement.longitude.toStringAsFixed(4)}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .grey.shade500,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                        ),
                                                      );
                                                    },
                                                  );
                                                } else {
                                                  return Text(
                                                    'Location: No GPS data (${movement.latitude}, ${movement.longitude})',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade400,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                            // Only show notes if user has proper access rights
                                            if (_shouldShowNotes(movement))
                                              Text(
                                                'Notes: ${movement.notes}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _formatFriendlyTime(
                                                movement.processedAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          // Only show entry deduction for border movements
                                          if (movement.entriesDeducted > 0 &&
                                              movement.movementType !=
                                                  'local_authority_scan')
                                            Text(
                                              '-${movement.entriesDeducted} entry',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ))),
                            if (_passHistory!.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Center(
                                  child: Text(
                                    '... and ${_passHistory!.length - 3} more entries',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ),
                            // View Pass History button
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton.icon(
                                onPressed: () => _showFullPassHistory(),
                                icon: const Icon(Icons.history, size: 18),
                                label: const Text('View Pass History'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                // Add scan purpose controls for local authority within the scrollable area
                if (widget.role == AuthorityRole.localAuthority) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Scan Purpose',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedScanPurpose,
                            hint: const Text('Select scan purpose...'),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: _scanPurposes.map((purpose) {
                              return DropdownMenuItem<String>(
                                value: purpose['value'],
                                child: Text(purpose['label']!),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedScanPurpose = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a scan purpose';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Notes (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              hintText:
                                  'Add any additional notes about this scan...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 12),

                          // Location indicator with refresh button
                          Row(
                            children: [
                              Icon(
                                _currentLatitude != null &&
                                        _currentLongitude != null
                                    ? Icons.location_on
                                    : Icons.location_off,
                                size: 16,
                                color: _currentLatitude != null &&
                                        _currentLongitude != null
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _currentLatitude != null &&
                                          _currentLongitude != null
                                      ? 'GPS: ${_currentLatitude!.toStringAsFixed(6)}, ${_currentLongitude!.toStringAsFixed(6)}'
                                      : 'GPS: Not available',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _currentLatitude != null &&
                                            _currentLongitude != null
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  debugPrint(
                                      '📍 Manual location refresh requested');
                                  await _getCurrentLocation();
                                },
                                icon: const Icon(Icons.refresh, size: 16),
                                tooltip: 'Refresh GPS location',
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: const EdgeInsets.all(4),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Action Buttons at the bottom
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (widget.role == AuthorityRole.localAuthority) ...[
                // Local Authority - Complete Validation Button (now at bottom)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _selectedScanPurpose != null && !_isProcessing
                        ? () => _completeValidation()
                        : null, // Disabled until scan purpose is selected
                    icon: const Icon(Icons.check),
                    label: Text(_selectedScanPurpose == null
                        ? 'Select Scan Purpose First'
                        : 'Complete Validation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else if (_passAction != null) ...[
                // Border Official - Enhanced Processing
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _proceedToDeduction(),
                    icon: Icon(
                        _passAction!.isCheckIn ? Icons.login : Icons.logout),
                    label: Text(_passAction!.actionDescription),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else if (isActive && pass.hasEntriesRemaining) ...[
                // Fallback for old logic
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _proceedToDeduction(),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Proceed with Entry Deduction'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _resetScanning(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Scan Another Pass'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationStep() {
    return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight -
                  48,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _validationPreference == ValidationPreference.pin
                        ? Icons.lock
                        : Icons.security,
                    size: 64,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _validationPreference == ValidationPreference.pin
                        ? 'PIN Verification Required'
                        : 'Secure Code Verification Required',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _validationPreference == ValidationPreference.pin
                        ? 'Please ask the pass owner to enter their 3-digit PIN'
                        : 'Please ask the pass owner for the verification code sent to their device',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_validationPreference == ValidationPreference.pin) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        '💡 The pass owner set this PIN in their profile settings',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (_validationPreference == ValidationPreference.pin) ...[
                    const Text(
                      'Enter the 3-digit PIN:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange,
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
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.smartphone,
                            size: 48,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Secure Code Sent',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'A 3-digit verification code has been sent to the pass owner\'s mobile device.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please ask them to check their phone and provide the code.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter the 3-digit verification code:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSecureDigitBox(0),
                        _buildSecureDigitBox(1),
                        _buildSecureDigitBox(2),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _verifyCredentials,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Verify & Deduct Entry',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _isProcessing ? null : () => _resetScanning(),
                    child: const Text('Cancel'),
                  ),
                  // Add bottom padding for keyboard
                  SizedBox(
                      height: MediaQuery.of(context).viewInsets.bottom > 0
                          ? 20
                          : 0),
                ],
              ),
            ),
          ),
        ));
  }

  Widget _buildProcessingStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 24),
          Text(
            'Processing Entry Deduction...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedStep() {
    final isSuccess = _errorMessage == null;
    final pass = _scannedPass;

    // Determine validation result
    String validationResult = '';
    String validationDetails = '';
    IconData resultIcon = Icons.error;
    Color resultColor = Colors.red.shade600;

    if (isSuccess && pass != null) {
      if (widget.role == AuthorityRole.localAuthority) {
        // Simple Local Authority validation - check vehicle location first
        if (pass.vehicleStatusDisplay == 'Departed') {
          validationResult = 'Vehicle is ILLEGAL';
          validationDetails =
              'Vehicle shows as departed but found in country - possible illegal re-entry or data error.';
          resultIcon = Icons.cancel;
          resultColor = Colors.red.shade600;
        } else if (pass.isActive) {
          validationResult = 'Vehicle is LEGAL';
          validationDetails =
              'Pass is valid and active. Vehicle is authorized to be in the country.';
          resultIcon = Icons.verified;
          resultColor = Colors.green.shade600;
        } else if (pass.statusDisplay == 'Consumed') {
          // Check if vehicle is currently in country
          if (pass.currentStatus == 'checked_in') {
            validationResult = 'Vehicle is LEGAL';
            validationDetails =
                'Pass entries consumed but vehicle is legally in country until ${DateFormat('MMM d, yyyy').format(pass.expiresAt)}.';
            resultIcon = Icons.verified;
            resultColor = Colors.green.shade600;
          } else {
            validationResult = 'Pass CONSUMED';
            validationDetails =
                'All entries have been used. Vehicle may need a new pass for future travel.';
            resultIcon = Icons.warning;
            resultColor = Colors.orange.shade600;
          }
        } else if (pass.statusDisplay == 'Expired') {
          validationResult = 'Pass EXPIRED';
          validationDetails =
              'Pass has expired. Vehicle is not authorized to be in the country.';
          resultIcon = Icons.cancel;
          resultColor = Colors.red.shade600;
        } else if (pass.statusDisplay == 'Pending Activation') {
          validationResult = 'Pass NOT YET ACTIVE';
          validationDetails =
              'Pass is not yet activated. Vehicle is not currently authorized.';
          resultIcon = Icons.schedule;
          resultColor = Colors.orange.shade600;
        } else {
          validationResult = 'Pass INVALID';
          validationDetails =
              'Pass status is invalid. Vehicle is not authorized to be in the country.';
          resultIcon = Icons.cancel;
          resultColor = Colors.red.shade600;
        }
      } else {
        // Border Official - Enhanced results
        if (_movementResult != null) {
          validationResult = _movementResult!.actionDescription;
          validationDetails =
              'Status: ${_movementResult!.previousStatus} → ${_movementResult!.newStatus}';
          if (_movementResult!.entriesDeducted > 0) {
            validationDetails +=
                '\nEntries deducted: ${_movementResult!.entriesDeducted}';
          }
          validationDetails +=
              '\nEntries remaining: ${_movementResult!.entriesRemaining}';
          validationDetails += '\nVehicle may proceed.';
          resultIcon = _movementResult!.movementType == 'check_in'
              ? Icons.login
              : Icons.logout;
          resultColor = Colors.green.shade600;
        } else {
          // Fallback for old behavior
          validationResult = 'Entry Deducted Successfully';
          validationDetails =
              'Pass entry has been deducted. Vehicle may proceed.';
          resultIcon = Icons.check_circle;
          resultColor = Colors.green.shade600;
        }
      }
    } else {
      validationResult = 'Processing Failed';
      validationDetails =
          'Unable to process this pass. Please see details below.';
      resultIcon = Icons.error;
      resultColor = Colors.red.shade600;
    }

    return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top -
                kToolbarHeight -
                48, // Account for app bar and padding
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                resultIcon,
                size: 80,
                color: resultColor,
              ),
              const SizedBox(height: 24),
              Text(
                validationResult,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: resultColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: resultColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      validationDetails,
                      style: TextStyle(
                        fontSize: 16,
                        color: resultColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isSuccess && pass != null) ...[
                      const SizedBox(height: 12),
                      Divider(color: resultColor.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      _buildValidationSummary(pass, resultColor),
                    ],
                  ],
                ),
              ),
              if (!isSuccess) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _resetScanning(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Scan Another Pass'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.role == AuthorityRole.localAuthority
                        ? Colors.blue.shade600
                        : Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Exit'),
              ),
            ],
          ),
        ));
  }

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
    _requestLocationPermission();
  }

  /// Request location permission and get current location
  Future<void> _requestLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('📍 Location services are disabled');
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('📍 Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('📍 Location permissions are permanently denied');
        return;
      }

      // Get current location
      _locationPermissionGranted = true;
      await _getCurrentLocation();
    } catch (e) {
      debugPrint('📍 Error requesting location permission: $e');
    }
  }

  /// Get current GPS coordinates
  Future<void> _getCurrentLocation() async {
    if (!_locationPermissionGranted) {
      debugPrint('📍 Location permission not granted, skipping GPS');
      return;
    }

    try {
      debugPrint('📍 Attempting to get current location...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15), // Increased timeout
      );

      setState(() {
        _currentLatitude = position.latitude;
        _currentLongitude = position.longitude;
      });

      debugPrint(
          '📍 ✅ Location obtained: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('📍 ❌ Error getting location: $e');

      // Try to get last known location as fallback
      try {
        debugPrint('📍 Trying to get last known location...');
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          setState(() {
            _currentLatitude = lastPosition.latitude;
            _currentLongitude = lastPosition.longitude;
          });
          debugPrint(
              '📍 ✅ Last known location: ${lastPosition.latitude}, ${lastPosition.longitude}');
        } else {
          debugPrint('📍 ❌ No last known location available');
        }
      } catch (fallbackError) {
        debugPrint('📍 ❌ Error getting last known location: $fallbackError');
      }
    }
  }

  /// Check if we can process a new scan (implements cooldown logic)
  bool _canProcessScan() {
    // Don't scan if already processing
    if (_isProcessing) return false;

    // Don't scan if scanning is disabled
    if (!_scanningEnabled) return false;

    // Check cooldown period
    if (_lastScanAttempt != null) {
      final timeSinceLastScan = DateTime.now().difference(_lastScanAttempt!);
      if (timeSinceLastScan < _scanCooldownDuration) {
        debugPrint(
            '🔄 Scan blocked - cooldown active (${_scanCooldownDuration.inSeconds - timeSinceLastScan.inSeconds}s remaining)');
        return false;
      }
    }

    return true;
  }

  /// Get the appropriate scanning status text
  String _getScanningStatusText() {
    if (_isProcessing) {
      return 'Processing QR code...';
    }

    if (!_scanningEnabled) {
      return 'Scanning disabled - use "Scan Another Pass" to continue';
    }

    if (_lastScanAttempt != null) {
      final timeSinceLastScan = DateTime.now().difference(_lastScanAttempt!);
      if (timeSinceLastScan < _scanCooldownDuration) {
        final remainingSeconds =
            _scanCooldownDuration.inSeconds - timeSinceLastScan.inSeconds;
        return 'Please wait ${remainingSeconds}s before scanning again';
      }
    }

    return 'Position QR code within the frame';
  }

  // Start a cooldown to prevent rapid repeated scans
  void _startCooldownTimer() {
    // Record the attempt time and disable scanning during cooldown
    _lastScanAttempt = DateTime.now();

    // Ensure any previous timer is cancelled
    _cooldownTimer?.cancel();

    setState(() {
      _scanningEnabled = false;
    });

    _cooldownTimer = Timer(_scanCooldownDuration, () {
      if (!mounted) return;
      setState(() {
        _scanningEnabled = true;
      });
    });
  }

  Future<void> _validateQRCode(String qrData) async {
    // Record scan attempt for cooldown
    _lastScanAttempt = DateTime.now();

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔍 Starting enhanced QR code validation...');
      debugPrint('📱 QR Data length: ${qrData.length} characters');

      // Step 1: Verify the pass exists and get pass details using PassVerificationService
      debugPrint(
          '🔍 Attempting to validate QR code: ${qrData.length > 50 ? qrData.substring(0, 50) + '...' : qrData}');
      // Create initial scan entry - will be updated when user completes validation
      debugPrint(
          '📍 Scanning with coordinates: lat=${_currentLatitude}, lng=${_currentLongitude}');
      final pass = await PassVerificationService.verifyPass(
        code: qrData,
        isQrCode: true,
        authorityType:
            'local_authority', // Always local_authority from this screen
        scanPurpose: 'scan_initiated', // Initial scan, will be updated
        notes: 'Scan in progress', // Will be updated with user notes
        latitude: _currentLatitude,
        longitude: _currentLongitude,
      );

      if (pass == null) {
        debugPrint('❌ Pass validation failed for QR code');
        setState(() {
          _errorMessage = 'Pass not found or invalid QR code\n'
              'QR data length: ${qrData.length} characters\n'
              'Please verify the QR code is correct or try the backup code.';
          _isProcessing = false;
        });
        _startCooldownTimer();
        return;
      }

      // Step 2: For Border Officials, determine action and check permissions
      if (widget.role == AuthorityRole.borderOfficial) {
        // Determine what action would be performed
        final action =
            await EnhancedBorderService.determinePassAction(pass.passId);

        // Check if current official can perform this action
        // For now, we'll skip the border-specific permission check since we don't have GPS-based border detection
        // TODO: Implement GPS-based border detection or user border selection
        debugPrint(
            '⚠️ Skipping border-specific permission check - GPS border detection not implemented yet');

        // Get verification method
        final verificationMethod = await _getVerificationMethod(pass.passId);

        // Load pass history for display
        final history =
            await EnhancedBorderService.getPassMovementHistory(pass.passId);

        setState(() {
          _scannedPass = pass;
          _passAction = action;
          _verificationMethod = verificationMethod;
          _passHistory = history;
          _currentStep = ValidationStep.passDetails;
          _isProcessing = false;
          _scanningEnabled = false;
        });
      } else {
        // Local Authority - just validation
        setState(() {
          _scannedPass = pass;
          _currentStep = ValidationStep.passDetails;
          _isProcessing = false;
          _scanningEnabled = false;
        });
      }

      controller?.stop();
      debugPrint('✅ Enhanced QR code validation successful');
    } catch (e) {
      debugPrint('❌ Enhanced QR validation error: $e');
      setState(() {
        _errorMessage = 'Error validating pass: ${e.toString()}';
        _isProcessing = false;
      });
      _startCooldownTimer();
    }
  }

  Future<void> _validateBackupCode(String backupCode) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔍 Starting enhanced backup code validation: $backupCode');

      // Verify the pass using backup code with PassVerificationService
      debugPrint('🔍 Attempting to validate backup code: $backupCode');
      // Create initial scan entry - will be updated when user completes validation
      debugPrint(
          '📍 Backup code scan with coordinates: lat=${_currentLatitude}, lng=${_currentLongitude}');
      final pass = await PassVerificationService.verifyPass(
        code: backupCode,
        isQrCode: false,
        authorityType:
            'local_authority', // Always local_authority from this screen
        scanPurpose: 'scan_initiated', // Initial scan, will be updated
        notes: 'Scan in progress', // Will be updated with user notes
        latitude: _currentLatitude,
        longitude: _currentLongitude,
      );

      if (pass == null) {
        debugPrint('❌ Pass validation failed for backup code: $backupCode');

        // Enhanced debugging - check what the cleaned code looks like
        final cleanCode = backupCode
            .trim()
            .toUpperCase()
            .replaceAll('-', '')
            .replaceAll(' ', '');
        debugPrint('🔍 Cleaned backup code: $cleanCode');

        setState(() {
          _errorMessage = 'Pass not found for backup code: $backupCode\n'
              'Cleaned code: $cleanCode\n'
              'Please verify the code is correct or contact support.';
          _isProcessing = false;
        });
        return;
      }

      // Step 2: For Border Officials, determine action and check permissions
      if (widget.role == AuthorityRole.borderOfficial) {
        // Determine what action would be performed
        final action =
            await EnhancedBorderService.determinePassAction(pass.passId);

        // Check if current official can perform this action
        // For now, we'll skip the border-specific permission check since we don't have GPS-based border detection
        // TODO: Implement GPS-based border detection or user border selection
        debugPrint(
            '⚠️ Skipping border-specific permission check - GPS border detection not implemented yet');

        // Get verification method
        final verificationMethod = await _getVerificationMethod(pass.passId);

        // Load pass history for display
        final history =
            await EnhancedBorderService.getPassMovementHistory(pass.passId);

        setState(() {
          _scannedPass = pass;
          _passAction = action;
          _verificationMethod = verificationMethod;
          _passHistory = history;
          _currentStep = ValidationStep.passDetails;
          _isProcessing = false;
        });
      } else {
        // Local Authority - just validation
        setState(() {
          _scannedPass = pass;
          _currentStep = ValidationStep.passDetails;
          _isProcessing = false;
        });
      }

      debugPrint('✅ Enhanced backup code validation successful');
    } catch (e) {
      debugPrint('❌ Enhanced backup code validation error: $e');
      setState(() {
        _errorMessage = 'Error validating backup code: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  void _proceedToDeduction() async {
    if (_scannedPass == null || _passAction == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      debugPrint(
          '🚀 Starting enhanced border processing for pass: ${_scannedPass!.passId}');

      // Map verification method to internal enum for UI compatibility
      switch (_verificationMethod) {
        case PassVerificationMethod.none:
          _validationPreference = ValidationPreference.direct;
          break;
        case PassVerificationMethod.pin:
          _validationPreference = ValidationPreference.pin;
          break;
        case PassVerificationMethod.secureCode:
          _validationPreference = ValidationPreference.secureCode;
          break;
        default:
          _validationPreference = ValidationPreference.direct;
      }

      setState(() {
        _isProcessing = false;
      });

      if (_validationPreference == ValidationPreference.direct) {
        debugPrint('➡️ Proceeding with direct processing (no verification)');
        // Direct processing without verification
        _performEnhancedMovementProcessing();
      } else {
        debugPrint('➡️ Requiring verification: $_validationPreference');
        // Require verification
        if (_validationPreference == ValidationPreference.secureCode) {
          // Generate and send secure code
          final secureCode = _generateSecureCode();
          debugPrint('🔐 Generated secure code: $secureCode');

          // Save secure code to database with expiry (10 minutes)
          final expiryTime = DateTime.now().add(const Duration(minutes: 10));
          await _supabase.from('purchased_passes').update({
            'secure_code': secureCode,
            'secure_code_expires_at': expiryTime.toIso8601String(),
          }).eq('id', _scannedPass!.passId);

          debugPrint(
              '💾 Secure code saved to database, expires at: $expiryTime');
        }
        setState(() {
          _currentStep = ValidationStep.verification;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Failed to prepare border processing: $e';
      });
    }
  }

  void _completeValidation() async {
    // Validate that scan purpose is selected
    if (_selectedScanPurpose == null) {
      setState(() {
        _errorMessage =
            'Please select a scan purpose before completing validation';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Update the existing movement record with scan purpose and notes
      await PassVerificationService.updateLastMovement(
        scanPurpose: _selectedScanPurpose!,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      debugPrint('✅ Movement updated with purpose: $_selectedScanPurpose');
      if (_notesController.text.trim().isNotEmpty) {
        debugPrint('📝 Notes: ${_notesController.text.trim()}');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to log validation completion: $e');
      // Continue anyway - don't block the UI for logging issues
    }

    setState(() {
      _isProcessing = false;
      _currentStep = ValidationStep.completed;
    });
  }

  Future<void> _verifyCredentials() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _secureCodeHasError = false;
    });

    try {
      bool isValid = false;

      if (_validationPreference == ValidationPreference.pin) {
        // Combine the three digit controllers to form the PIN
        String enteredPin = _pinDigit1Controller.text +
            _pinDigit2Controller.text +
            _pinDigit3Controller.text;

        // Verify PIN using enhanced verification service
        if (enteredPin.length == 3 &&
            RegExp(r'^[0-9]+$').hasMatch(enteredPin)) {
          final storedPin =
              await ProfileManagementService.getPassOwnerStoredPin(
                  _scannedPass!.passId);
          if (storedPin != null) {
            isValid = enteredPin == storedPin;
            debugPrint(
                'PIN verification: entered=$enteredPin, stored=$storedPin, valid=$isValid');
          } else {
            debugPrint('No stored PIN found for verification');
            isValid = false;
          }
        } else {
          debugPrint('Invalid PIN format: $enteredPin');
          isValid = false;
        }
      } else if (_validationPreference == ValidationPreference.secureCode) {
        // Verify secure code using enhanced verification service
        final enteredCode = _secureDigit1Controller.text.trim() +
            _secureDigit2Controller.text.trim() +
            _secureDigit3Controller.text.trim();

        if (enteredCode.length == 3 &&
            RegExp(r'^[0-9]+$').hasMatch(enteredCode)) {
          // Get the current pass data to check stored secure code
          final currentPass =
              await PassService.getPassById(_scannedPass!.passId);
          if (currentPass != null &&
              currentPass.secureCode != null &&
              currentPass.secureCodeExpiresAt != null) {
            final now = DateTime.now();
            final isExpired = now.isAfter(currentPass.secureCodeExpiresAt!);
            if (isExpired) {
              debugPrint(
                  'Secure code expired at: ${currentPass.secureCodeExpiresAt}');
              isValid = false;
            } else {
              isValid = enteredCode == currentPass.secureCode;
              debugPrint(
                  'Secure code verification: entered=$enteredCode, stored=${currentPass.secureCode}, valid=$isValid');
            }
          } else {
            debugPrint('No stored secure code found for verification');
            isValid = false;
          }
        } else {
          debugPrint('Invalid secure code format: $enteredCode');
          isValid = false;
        }
      }

      if (isValid) {
        await _performEnhancedMovementProcessing();
      } else {
        String? localError;
        bool localSecureError = false;

        if (_validationPreference == ValidationPreference.pin) {
          String enteredPin = _pinDigit1Controller.text +
              _pinDigit2Controller.text +
              _pinDigit3Controller.text;

          if (enteredPin.length != 3) {
            localError = 'Please enter all 3 digits of the PIN';
          } else if (!RegExp(r'^[0-9]+$').hasMatch(enteredPin)) {
            localError = 'PIN must contain only numbers';
          } else {
            localError =
                'Incorrect PIN entered. Please ask the pass owner to try again.';
          }
        } else {
          // Secure code errors
          final enteredCode = _secureDigit1Controller.text.trim() +
              _secureDigit2Controller.text.trim() +
              _secureDigit3Controller.text.trim();

          if (enteredCode.length != 3) {
            localError = 'Please enter all 3 digits of the verification code';
            localSecureError = true;
          } else if (!RegExp(r'^[0-9]+$').hasMatch(enteredCode)) {
            localError = 'Verification code must contain only numbers';
            localSecureError = true;
          } else {
            // Check if code is expired by fetching pass BEFORE setState
            final currentPass =
                await PassService.getPassById(_scannedPass!.passId);
            if (currentPass?.secureCodeExpiresAt != null &&
                DateTime.now().isAfter(currentPass!.secureCodeExpiresAt!)) {
              localError =
                  'Verification code has expired. Please ask the border official to scan the pass again.';
              localSecureError = true;
            } else {
              localError =
                  'Incorrect verification code. Please check the code on the pass owner\'s device.';
              localSecureError = true;
            }
          }

          // Clear secure code inputs for retry
          _secureDigit1Controller.clear();
          _secureDigit2Controller.clear();
          _secureDigit3Controller.clear();
        }

        setState(() {
          _errorMessage = localError;
          _secureCodeHasError = localSecureError;
          if (_validationPreference == ValidationPreference.pin) {
            // Clear PIN fields and refocus for retry
            _pinDigit1Controller.clear();
            _pinDigit2Controller.clear();
            _pinDigit3Controller.clear();
            _pinDigit1Focus.requestFocus();
          } else {
            _secureDigit1Focus.requestFocus();
          }
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _performEnhancedMovementProcessing() async {
    setState(() {
      _currentStep = ValidationStep.processing;
      _isProcessing = true;
    });

    try {
      if (_scannedPass == null || _passAction == null) {
        throw Exception('No pass or action selected');
      }

      // For border officials, process the movement with GPS validation
      if (widget.role == AuthorityRole.borderOfficial) {
        String borderIdToUse;

        // SCENARIO 1: Pass has specific entry_point_id or exit_point_id
        if (_scannedPass!.entryPointId != null) {
          borderIdToUse = _scannedPass!.entryPointId!;
          debugPrint('🔍 Using pass entry point: $borderIdToUse');

          // Validate GPS distance to the specific border
          await _validateGpsDistanceToBorder(borderIdToUse);
        } else {
          // SCENARIO 2: Pass has no specific border - show border selection
          debugPrint(
              '🔍 Pass has no specific border - showing border selection');

          // Get current GPS position
          final position = await EnhancedBorderService.getCurrentPosition();

          // Get borders assigned to this official
          final assignedBorders =
              await BorderSelectionService.findNearestAssignedBorders(
            currentLat: position.latitude,
            currentLon: position.longitude,
          );

          if (assignedBorders.isEmpty) {
            throw Exception(
                'No borders assigned to your account. Please contact your supervisor.');
          }

          // If only one border, use it directly
          if (assignedBorders.length == 1) {
            borderIdToUse = assignedBorders.first.borderId;
            debugPrint('🔍 Using only assigned border: $borderIdToUse');

            // Still validate GPS distance
            await _validateGpsDistanceToBorder(borderIdToUse);
          } else {
            // Multiple borders - show selection UI
            borderIdToUse =
                await _showBorderSelectionDialog(assignedBorders, position);

            // Validate GPS distance to selected border
            await _validateGpsDistanceToBorder(borderIdToUse);
          }
        }

        final result = await EnhancedBorderService.processPassMovement(
          passId: _scannedPass!.passId,
          borderId: borderIdToUse,
          metadata: {
            'verification_method': _verificationMethod?.name ?? 'none',
            'official_id': widget.currentAuthorityId ?? 'unknown',
            'processed_via': 'authority_validation_screen',
          },
        );

        setState(() {
          _movementResult = result;
          _currentStep = ValidationStep.completed;
          _isProcessing = false;
        });

        debugPrint(
            '✅ Enhanced movement processing completed: ${result.actionDescription}');
      } else {
        // Local authority - just complete validation (no movement processing)
        setState(() {
          _currentStep = ValidationStep.completed;
          _isProcessing = false;
        });

        debugPrint('✅ Local authority validation completed');
      }
    } catch (e) {
      setState(() {
        // Handle GPS validation cancellation specifically
        if (e
            .toString()
            .contains('Processing cancelled due to GPS distance violation')) {
          _currentStep = ValidationStep.scanning; // Go back to scanning
          _isProcessing = false;
          _showProcessingCancelledDialog();
          return;
        }

        // Provide user-friendly error messages based on the error type
        if (e.toString().contains('Insufficient permissions') ||
            e.toString().contains('P0001')) {
          _errorMessage =
              '🚫 Access Denied\n\nYou don\'t have permission to process vehicle movements at this border crossing. This could be because:\n\n• You\'re not assigned to this specific border\n• Your account lacks check-in/check-out permissions\n• The border crossing is outside your jurisdiction\n\nPlease contact your supervisor to verify your border assignments and permissions.';
        } else if (e.toString().contains('No entries remaining')) {
          _errorMessage =
              '❌ Pass Exhausted\n\nThis pass has no remaining entries and cannot be used for border crossings.\n\nThe traveler will need to purchase a new pass to continue their journey.';
        } else if (e.toString().contains('Pass has expired')) {
          _errorMessage =
              '⏰ Pass Expired\n\nThis pass has expired and can no longer be used for border crossings.\n\nThe traveler will need to purchase a new pass to continue their journey.';
        } else if (e.toString().contains('Invalid pass status')) {
          _errorMessage =
              '⚠️ Invalid Pass Status\n\nThis pass is in an invalid state and cannot be processed at this time.\n\nPlease ask the traveler to contact customer support for assistance.';
        } else {
          _errorMessage =
              '⚠️ Processing Failed\n\nUnable to process this vehicle movement due to a technical issue.\n\nPlease try again, or contact technical support if the problem persists.\n\nError details: ${e.toString().length > 100 ? e.toString().substring(0, 100) + '...' : e.toString()}';
        }
        _currentStep = ValidationStep.completed;
        _isProcessing = false;
      });
      debugPrint('❌ Enhanced movement processing failed: $e');
    }
  }

  // Keep the old method for backward compatibility during transition
  Future<void> _performEntryDeduction() async {
    // Redirect to enhanced processing
    await _performEnhancedMovementProcessing();
  }

  void _resetScanning() {
    setState(() {
      _currentStep = ValidationStep.scanning;
      _scannedPass = null;
      _validationPreference = null;
      _errorMessage = null;
      _isProcessing = false;
      _useBackupCode = false;
      _secureCodeHasError = false;

      // Reset enhanced border control state
      _passAction = null;
      _movementResult = null;
      _verificationMethod = null;
      _passHistory = null;

      // Reset scanning controls
      _scanningEnabled = true;
      _lastScanAttempt = null;

      // Clear scan purpose and notes for next scan
      _selectedScanPurpose = null; // Reset to null to force selection
      _notesController.clear();
      _currentMovementId = null;
    });

    // Clear the movement ID in the service
    PassVerificationService.clearLastMovementId();

    _backupCodeController.clear();
    _secureCodeController.clear();

    // Clear PIN digit controllers
    _pinDigit1Controller.clear();
    _pinDigit2Controller.clear();
    _pinDigit3Controller.clear();

    // Clear Secure Code digit controllers
    _secureDigit1Controller.clear();
    _secureDigit2Controller.clear();
    _secureDigit3Controller.clear();

    // Some versions of mobile_scanner don't reliably restart after stop().
    // Recreate the controller to ensure detection resumes.
    try {
      controller?.dispose();
    } catch (_) {}
    controller = MobileScannerController();
    // Explicitly start to be safe.
    controller?.start();
  }

  /// Show vehicle search screen and handle pass selection
  Future<void> _showVehicleSearch() async {
    try {
      final selectedPass = await VehicleSearchScreen.showModal(
        context,
        title: widget.role == AuthorityRole.localAuthority
            ? 'Search for Pass to Validate'
            : 'Search for Pass to Process',
      );

      if (selectedPass != null) {
        // Auto-fill the backup code and validate
        _backupCodeController.text = selectedPass.displayShortCode;
        setState(() {
          _useBackupCode = true;
          _errorMessage = null;
        });

        // Automatically validate the selected pass
        await _validateBackupCode(selectedPass.displayShortCode);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to search for passes: $e';
      });
    }
  }

  String _generateSecureCode() {
    // Generate a 3-digit secure code (100-999)
    final random = DateTime.now().millisecondsSinceEpoch;
    return (random % 900 + 100).toString();
  }

  /// Format DateTime to a user-friendly time string
  String _formatFriendlyTime(DateTime dateTime) {
    return TimeUtils.formatCompactTime(dateTime);
  }

  Future<void> _sendSecureCodeToPassOwner(
      String passId, String secureCode) async {
    try {
      debugPrint(
          '🔐 Sending secure code $secureCode to pass owner for pass: $passId');

      // In a real implementation, this would:
      // 1. Get the pass owner's phone number from the database
      // 2. Send SMS with the secure code
      // 3. Or send push notification to their mobile app
      // 4. Store the code temporarily in database with expiration

      // For now, we'll simulate this by logging
      debugPrint(
          '📱 SMS would be sent: "Your border crossing verification code is: $secureCode"');
      debugPrint('⏰ Code expires in 10 minutes');

      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('❌ Failed to send secure code: $e');
      throw Exception('Failed to send verification code to pass owner');
    }
  }

  Future<PurchasedPass?> _parseAndValidatePass(String qrData) async {
    try {
      debugPrint(
          '🔍 Parsing QR data: ${qrData.length > 50 ? qrData.substring(0, 50) + '...' : qrData}');

      final pass = await PassService.validatePassByQRCode(qrData);
      if (pass == null) {
        debugPrint(
            '❌ PassService returned null - pass not found or invalid QR format');
        // Don't set error message here, let the calling method handle it
        return null;
      } else {
        debugPrint('✅ PassService found pass: ${pass.passId}');

        // Validate authority permissions
        final canValidate = await _validateAuthorityPermissions(pass);
        if (!canValidate) {
          debugPrint('❌ Authority validation failed');
          // Error message is already set by _validateAuthorityPermissions
          return null;
        }

        debugPrint('✅ All validations passed for pass: ${pass.passId}');
        return pass;
      }
    } catch (e) {
      debugPrint('❌ Error parsing QR data: $e');
      // Don't set error message here, let the calling method handle it
      return null;
    }
  }

  Future<PurchasedPass?> _validatePassByBackupCode(String backupCode) async {
    try {
      debugPrint('🔍 Validating backup code: $backupCode');

      final pass = await PassService.validatePassByBackupCode(backupCode);
      if (pass == null) {
        debugPrint('❌ PassService returned null - backup code not found');
        // Don't set error message here, let the calling method handle it
        return null;
      } else {
        debugPrint('✅ PassService found pass: ${pass.passId}');

        // Validate authority permissions
        final canValidate = await _validateAuthorityPermissions(pass);
        if (!canValidate) {
          debugPrint('❌ Authority validation failed');
          // Error message is already set by _validateAuthorityPermissions
          return null;
        }

        debugPrint('✅ All validations passed for pass: ${pass.passId}');
        return pass;
      }
    } catch (e) {
      debugPrint('❌ Error validating backup code: $e');
      // Don't set error message here, let the calling method handle it
      return null;
    }
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

    // Determine if there's a PIN-related error
    final bool hasError = _errorMessage != null &&
        _validationPreference == ValidationPreference.pin;

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        border:
            Border.all(color: hasError ? Colors.red : Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: hasError ? Colors.red.shade50 : Colors.orange.shade50,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: hasError ? Colors.red : Colors.orange,
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
              // Last digit entered, unfocus to hide keyboard
              focusNode.unfocus();
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

  Widget _buildValidationSummary(PurchasedPass pass, Color color) {
    return Column(
      children: [
        _buildSummaryRow('Vehicle', pass.vehicleDescription, color),
        if (pass.vehicleRegistrationNumber != null &&
            pass.vehicleRegistrationNumber!.isNotEmpty)
          _buildSummaryRow(
              'Registration Number', pass.vehicleRegistrationNumber!, color),
        if (pass.vehicleVin != null && pass.vehicleVin!.isNotEmpty)
          _buildSummaryRow('VIN', pass.vehicleVin!, color),
        if (pass.authorityName != null)
          _buildSummaryRow('Authority', pass.authorityName!, color),
        if (pass.countryName != null)
          _buildSummaryRow('Country', pass.countryName!, color),
        _buildSummaryRow(
            'Entry Point', pass.entryPointName ?? 'Any Entry Point', color),
        if (pass.exitPointName != null)
          _buildSummaryRow('Exit Point', pass.exitPointName!, color),
        _buildSummaryRow('Status', pass.statusDisplay, color),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: color.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// Validate that the current user's authority can process this pass
  /// Implements the exact logic: Border Control validation for border officials
  Future<bool> _validateAuthorityPermissions(PurchasedPass pass) async {
    try {
      debugPrint(
          '🔍 Starting Border Control validation for pass: ${pass.passId}');

      // Use pass data directly instead of making additional database calls
      final passAuthorityId = pass.authorityId;
      final passEntryPointId = pass.entryPointId;

      debugPrint('📋 Pass Information:');
      debugPrint('  - Authority ID: $passAuthorityId');
      debugPrint('  - Entry Point ID: $passEntryPointId');
      debugPrint('  - Country Name: ${pass.countryName}');
      debugPrint('👤 Current Border Official:');
      debugPrint('  - Authority ID: ${widget.currentAuthorityId}');
      debugPrint('  - Country ID: ${widget.currentCountryId}');
      debugPrint('  - Role: ${widget.role}');

      if (widget.role == AuthorityRole.borderOfficial) {
        // STEP 1: Check if pass has an entry_point_id set
        if (passEntryPointId != null) {
          debugPrint('🔍 Pass has specific entry point: $passEntryPointId');

          // STEP 2: Check if current border official is assigned to this border
          final currentUser = _supabase.auth.currentUser;
          if (currentUser == null) {
            debugPrint('❌ No authenticated user');
            setState(() {
              _errorMessage = 'Authentication error. Please log in again.';
            });
            return false;
          }

          final assignmentResponse = await _supabase
              .from('border_official_borders')
              .select('border_id')
              .eq('profile_id', currentUser.id)
              .eq('border_id', passEntryPointId)
              .eq('is_active', true)
              .maybeSingle();

          if (assignmentResponse == null) {
            debugPrint(
                '❌ Border official not assigned to entry point: $passEntryPointId');
            setState(() {
              _errorMessage =
                  '🚫 Access Denied\n\nYou don\'t have permission to process passes for this entry point. This pass is specific to a border crossing where you\'re not currently assigned.\n\nPlease contact your supervisor or use a different border terminal.';
            });
            return false;
          }

          debugPrint(
              '✅ Border official is assigned to entry point: $passEntryPointId');
          debugPrint(
              '✅ Validation passed - can process entry point-specific pass');
          return true;
        } else {
          debugPrint('🔍 Pass has no specific entry point (general pass)');

          // STEP 3: For general passes, check if border official is from same authority
          if (widget.currentAuthorityId == null) {
            debugPrint('❌ Current user has no authority assigned');
            setState(() {
              _errorMessage =
                  '⚠️ Account Setup Required\n\nYour border official account is not assigned to any authority. This is required to process passes.\n\nPlease contact your administrator to complete your account setup.';
            });
            return false;
          }

          if (widget.currentAuthorityId != passAuthorityId) {
            debugPrint(
                '❌ Authority mismatch: ${widget.currentAuthorityId} != $passAuthorityId');
            setState(() {
              _errorMessage =
                  '🚫 Authority Mismatch\n\nThis pass was issued by a different border authority. As a border official, you can only process passes issued by your own authority.\n\nIf you believe this is an error, please contact your supervisor.';
            });
            return false;
          }

          debugPrint('✅ Same authority - can process general pass');
          debugPrint(
              '✅ Validation passed - can process general authority pass');
          return true;
        }
      } else if (widget.role == AuthorityRole.localAuthority) {
        // Local Authority logic - validate by country
        if (widget.currentCountryId == null) {
          debugPrint('❌ Current user has no country assigned');
          setState(() {
            _errorMessage =
                '⚠️ Account Setup Required\n\nYour local authority account is not assigned to any country. This is required to validate passes.\n\nPlease contact your administrator to complete your account setup.';
          });
          return false;
        }

        // For local authority, we need to get the pass country info
        final passAuthorityInfo = await _getPassAuthorityInfo(pass.passId);
        if (passAuthorityInfo == null) {
          debugPrint('❌ Unable to get pass country information');
          setState(() {
            _errorMessage =
                '❌ Verification Failed\n\nUnable to verify this pass information. The pass may be invalid or corrupted.\n\nPlease ask the traveler to show their backup code or try scanning again.';
          });
          return false;
        }

        final passCountryId = passAuthorityInfo['country_id'] as String?;
        if (widget.currentCountryId != passCountryId) {
          debugPrint(
              '❌ Country mismatch: ${widget.currentCountryId} != $passCountryId');
          setState(() {
            _errorMessage =
                '🚫 Country Jurisdiction\n\nThis pass was issued by an authority in a different country. As a local authority, you can only validate passes from your own country.\n\nPlease refer the traveler to the appropriate authority.';
          });
          return false;
        }

        debugPrint('✅ Country validation passed for local authority');
        return true;
      }

      debugPrint('❌ Unknown role or validation failed');
      return false;
    } catch (e) {
      debugPrint('❌ Error during validation: $e');
      setState(() {
        _errorMessage =
            '⚠️ System Error\n\nA technical error occurred while validating your permissions. This is usually temporary.\n\nPlease try again in a moment, or contact technical support if the problem persists.';
      });
      return false;
    }
  }

  /// Get the authority and country information for a pass
  Future<Map<String, dynamic>?> _getPassAuthorityInfo(String passId) async {
    try {
      final response = await _supabase.from('purchased_passes').select('''
            entry_point_id,
            exit_point_id,
            authority_id,
            country_id,
            authorities!inner(
              id,
              country_id
            )
          ''').eq('id', passId).maybeSingle();

      if (response != null) {
        final authority = response['authorities'] as Map<String, dynamic>;

        return {
          'authority_id': authority['id'] as String,
          'country_id': authority['country_id'] as String,
          'entry_point_id': response['entry_point_id']
              as String?, // Get entry_point_id directly from purchased_passes
          'exit_point_id': response['exit_point_id']
              as String?, // Get exit_point_id directly from purchased_passes
        };
      }

      return null;
    } catch (e) {
      debugPrint('Error getting pass authority info: $e');
      return null;
    }
  }

  // Helper methods for movement history display
  IconData _getMovementIcon(String movementType) {
    switch (movementType) {
      case 'check_in':
        return Icons.login;
      case 'check_out':
        return Icons.logout;
      case 'local_authority_scan':
        return Icons.verified_user;
      default:
        return Icons.history;
    }
  }

  Color _getMovementColor(String movementType) {
    switch (movementType) {
      case 'check_in':
        return Colors.green;
      case 'check_out':
        return Colors.blue;
      case 'local_authority_scan':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getMovementTitle(PassMovement movement) {
    if (movement.movementType == 'local_authority_scan') {
      // For local authority: just show scan purpose (no "by Local Authority")
      return movement.actionDescription;
    } else {
      // For border control: show action at border
      return '${movement.actionDescription} at ${movement.borderName}';
    }
  }

  String _getOfficialName(PassMovement movement) {
    if (movement.movementType == 'local_authority_scan') {
      // For local authority: show "Local Authority: [Name]"
      return 'Local Authority: ${movement.officialName}';
    } else {
      // For border control: show just the official name
      return movement.officialName;
    }
  }

  bool _shouldShowNotes(PassMovement movement) {
    // Only show notes if movement has notes and user has proper access rights
    if (movement.notes == null || movement.notes!.isEmpty) {
      return false;
    }

    // Check if current user has rights to see notes
    // Allowed roles: border_official, local_authority, country_administrator, auditor, business_intelligence
    return _hasNotesViewingRights();
  }

  bool _hasNotesViewingRights() {
    // For now, allow all authenticated users to see notes
    // In production, you would check the user's role from their profile
    // Example roles that should see notes:
    // - border_official
    // - local_authority
    // - country_administrator
    // - auditor
    // - business_intelligence

    // TODO: Implement proper role checking
    // For now, return true to show notes to all users
    return true;
  }

  // Cache for location names to avoid repeated API calls
  static final Map<String, String> _locationCache = {};

  Future<String> _getLocationName(double latitude, double longitude) async {
    final key =
        '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';

    debugPrint('🌍 Getting location for: $latitude, $longitude');

    // Check cache first
    if (_locationCache.containsKey(key)) {
      debugPrint('🌍 Using cached location: ${_locationCache[key]}');
      return _locationCache[key]!;
    }

    try {
      debugPrint('🌍 Calling geocoding API...');
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      debugPrint('🌍 Geocoding returned ${placemarks.length} placemarks');

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;

        debugPrint('🌍 Placemark details:');
        debugPrint('  - Name: ${placemark.name}');
        debugPrint('  - Locality: ${placemark.locality}');
        debugPrint('  - SubLocality: ${placemark.subLocality}');
        debugPrint('  - AdministrativeArea: ${placemark.administrativeArea}');
        debugPrint(
            '  - SubAdministrativeArea: ${placemark.subAdministrativeArea}');
        debugPrint('  - Country: ${placemark.country}');
        debugPrint('  - PostalCode: ${placemark.postalCode}');
        debugPrint('  - Street: ${placemark.street}');
        debugPrint('  - Thoroughfare: ${placemark.thoroughfare}');

        // Build location string with available information
        List<String> locationParts = [];

        // Try different combinations to get the best location description
        if (placemark.subLocality != null &&
            placemark.subLocality!.isNotEmpty) {
          locationParts.add(placemark.subLocality!);
        } else if (placemark.locality != null &&
            placemark.locality!.isNotEmpty) {
          locationParts.add(placemark.locality!);
        } else if (placemark.name != null && placemark.name!.isNotEmpty) {
          locationParts.add(placemark.name!);
        }

        if (placemark.subAdministrativeArea != null &&
            placemark.subAdministrativeArea!.isNotEmpty) {
          locationParts.add(placemark.subAdministrativeArea!);
        } else if (placemark.administrativeArea != null &&
            placemark.administrativeArea!.isNotEmpty) {
          locationParts.add(placemark.administrativeArea!);
        }

        if (placemark.country != null && placemark.country!.isNotEmpty) {
          locationParts.add(placemark.country!);
        }

        String locationName = locationParts.isNotEmpty
            ? locationParts.join(', ')
            : 'Unknown Location';

        debugPrint('🌍 Final location name: $locationName');

        // Cache the result
        _locationCache[key] = locationName;
        return locationName;
      } else {
        debugPrint('🌍 No placemarks returned');
      }
    } catch (e) {
      debugPrint('🌍 ❌ Error getting location name: $e');
      debugPrint('🌍 Error type: ${e.runtimeType}');
    }

    // Fallback to coordinates
    final fallback =
        '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    debugPrint('🌍 Using fallback: $fallback');
    _locationCache[key] = fallback;
    return fallback;
  }

  /// Build owner details section with basic info and view complete details button
  Widget _buildOwnerDetailsSection(PurchasedPass pass) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getOwnerBasicInfo(pass.profileId ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Owner Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Owner Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade400),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Unable to load owner information',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        final ownerData = snapshot.data!;
        final ownerName = ownerData['full_name']?.toString() ?? 'Unknown Owner';
        final ownerEmail = ownerData['email']?.toString();
        final ownerPhone = ownerData['phone_number']?.toString();
        final profileImageUrl = ownerData['profile_image_url']?.toString();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    const Text(
                      'Owner Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Owner basic info
                Row(
                  children: [
                    // Profile image
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.blue.shade300, width: 2),
                      ),
                      child: ClipOval(
                        child: profileImageUrl != null &&
                                profileImageUrl.isNotEmpty
                            ? Image.network(
                                profileImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person,
                                    size: 24,
                                    color: Colors.grey.shade400,
                                  );
                                },
                              )
                            : Icon(
                                Icons.person,
                                size: 24,
                                color: Colors.grey.shade400,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Owner info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ownerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (ownerEmail != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              ownerEmail,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                          if (ownerPhone != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              ownerPhone,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // View complete details button
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: () => _showOwnerDetailsPopup(
                            pass.profileId ?? '', ownerName),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text(
                          'View Complete',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Get basic owner information for display
  Future<Map<String, dynamic>?> _getOwnerBasicInfo(String profileId) async {
    try {
      return await ProfileManagementService.getProfileById(profileId);
    } catch (e) {
      debugPrint('Error getting owner basic info: $e');
      return null;
    }
  }

  /// Show owner details popup
  void _showOwnerDetailsPopup(String ownerId, String ownerName) {
    showDialog(
      context: context,
      builder: (context) => OwnerDetailsPopup(
        ownerId: ownerId,
        ownerName: ownerName,
      ),
    );
  }

  /// Validate GPS distance to border (30km rule)
  Future<void> _validateGpsDistanceToBorder(String borderId) async {
    try {
      debugPrint('🌍 Validating GPS distance to border: $borderId');

      // Get current GPS position
      final position = await EnhancedBorderService.getCurrentPosition();

      // Validate GPS distance using the border selection service
      final validation = await BorderSelectionService.validateBorderGpsDistance(
        passId: _scannedPass!.passId,
        borderId: borderId,
        currentLat: position.latitude,
        currentLon: position.longitude,
        maxDistanceKm: 30.0,
      );

      if (!validation.withinRange) {
        debugPrint('⚠️ GPS validation failed: ${validation.violationMessage}');

        // Show GPS violation dialog
        final shouldProceed = await _showGpsViolationDialog(validation);

        if (!shouldProceed) {
          // User chose to cancel
          await BorderSelectionService.logDistanceViolationResponse(
            auditId: validation.auditId!,
            decision: 'cancel',
            notes: 'Official chose to cancel due to distance violation',
          );

          throw Exception('Processing cancelled due to GPS distance violation');
        } else {
          // User chose to proceed - log the decision
          await BorderSelectionService.logDistanceViolationResponse(
            auditId: validation.auditId!,
            decision: 'proceed',
            notes: 'Official chose to proceed despite distance violation',
          );

          debugPrint('✅ Official chose to proceed despite GPS violation');
        }
      } else {
        debugPrint(
            '✅ GPS validation passed - within ${validation.maxAllowedKm}km range');
      }
    } catch (e) {
      debugPrint('❌ GPS validation error: $e');

      // Re-throw cancellation exceptions to stop processing
      if (e
          .toString()
          .contains('Processing cancelled due to GPS distance violation')) {
        rethrow; // This will stop the processing
      }

      // For other GPS errors (network, permissions, etc.), just log and continue
      debugPrint('⚠️ GPS validation failed but continuing processing');
    }
  }

  /// Show border selection dialog for officials with multiple borders
  Future<String> _showBorderSelectionDialog(
      List<AssignedBorder> borders, Position position) async {
    return await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Select Border Crossing'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'You are assigned to multiple borders. Please select which border you are currently working at:'),
                  const SizedBox(height: 16),
                  ...borders.map((border) => ListTile(
                        leading: Icon(Icons.location_on,
                            color: Colors.blue.shade600),
                        title: Text(border.borderName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(border.permissionsDisplay),
                            if (border.distanceKm != null)
                              Text(border.distanceDisplay,
                                  style:
                                      TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                        onTap: () => Navigator.of(context).pop(border.borderId),
                      )),
                ],
              ),
            ),
          ),
        ) ??
        borders.first.borderId; // Fallback to first border if dialog dismissed
  }

  /// Show GPS violation warning dialog
  Future<bool> _showGpsViolationDialog(GpsValidationResult validation) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('GPS Distance Warning'),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location Verification Failed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(validation.violationMessage),
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
                      Text(
                        'Location Details:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Border: ${validation.borderName}'),
                      Text('Distance: ${validation.distanceDisplay}'),
                      Text(
                          'Max Allowed: ${validation.maxAllowedKm.toStringAsFixed(0)}km'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This action will be logged for audit purposes. Do you want to proceed anyway?',
                  style: TextStyle(fontWeight: FontWeight.w500),
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
                child: const Text('Proceed Anyway'),
              ),
            ],
          ),
        ) ??
        false; // Default to false if dialog dismissed
  }

  /// Show processing cancelled dialog
  void _showProcessingCancelledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Processing Cancelled'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📍 GPS Distance Violation',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You chose to cancel processing due to GPS distance violation. This is the correct action when you are not at the designated border location.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To proceed, please:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Move to the correct border location'),
                  const Text(
                      '• Or contact your supervisor if this is an emergency situation'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  /// Show full pass history using the existing PassHistoryWidget
  void _showFullPassHistory() {
    if (_scannedPass == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PassHistoryWidget(
          passId: _scannedPass!.passId,
          shortCode: _scannedPass!.shortCode,
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class _BackupCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Uppercase and strip non-alphanumerics/hyphens, then remove hyphens
    String raw = newValue.text.toUpperCase();
    raw = raw.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
    String alnum = raw.replaceAll('-', '');

    // Cap at 8 alphanumeric characters
    if (alnum.length > 8) {
      alnum = alnum.substring(0, 8);
    }

    // Re-insert hyphen after the first 4 if needed
    String formatted;
    if (alnum.length <= 4) {
      formatted = alnum;
    } else {
      formatted = '${alnum.substring(0, 4)}-${alnum.substring(4)}';
    }

    // Compute new cursor position near the end
    final newOffset = formatted.length;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}
