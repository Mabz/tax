import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/purchased_pass.dart';
import '../services/pass_service.dart';
import '../services/profile_management_service.dart';
import '../enums/pass_verification_method.dart';
import '../widgets/pass_card_widget.dart';

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
  String? _dynamicSecureCode;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _useBackupCode = false;

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
          if (_currentStep == ValidationStep.scanning)
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
        // Use the reusable PassCardWidget
        Expanded(
          child: PassCardWidget(
            pass: pass,
            showQrCode: false, // Don't show QR code in validation screen
            showDetails: true,
            isCompact: true,
            showSecureCode: false, // Hide secure code on authority UI
          ),
        ),

        // Action Buttons at the bottom
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (widget.role == AuthorityRole.localAuthority) ...[
                // Local Authority - Just validation
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _completeValidation(),
                    icon: const Icon(Icons.check),
                    label: const Text('Complete Validation'),
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
              ] else if (isActive && pass.hasEntriesRemaining) ...[
                // Border Official - Deduction
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

    // Determine validation result for Local Authority
    String validationResult = '';
    String validationDetails = '';
    IconData resultIcon = Icons.error;
    Color resultColor = Colors.red.shade600;

    if (isSuccess && pass != null) {
      if (widget.role == AuthorityRole.localAuthority) {
        // Local Authority validation summary
        if (pass.isActive) {
          validationResult = 'Vehicle is LEGAL';
          validationDetails =
              'Pass is valid and active. Vehicle is authorized to be in the country.';
          resultIcon = Icons.verified;
          resultColor = Colors.green.shade600;
        } else if (pass.statusDisplay == 'Consumed') {
          validationResult = 'Pass CONSUMED';
          validationDetails =
              'All entries have been used. Vehicle may need a new pass.';
          resultIcon = Icons.warning;
          resultColor = Colors.orange.shade600;
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
        // Border Official - keep existing behavior
        validationResult = 'Entry Deducted Successfully';
        validationDetails =
            'Pass entry has been deducted. Vehicle may proceed.';
        resultIcon = Icons.check_circle;
        resultColor = Colors.green.shade600;
      }
    } else {
      validationResult = 'Validation Failed';
      validationDetails =
          _errorMessage ?? 'Unable to validate pass. Please try again.';
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
      debugPrint('🔍 Starting QR code validation...');
      debugPrint('📱 QR Data length: ${qrData.length} characters');
      debugPrint(
          '📱 QR Data preview: ${qrData.length > 100 ? '${qrData.substring(0, 100)}...' : qrData}');

      // Parse QR code data and validate pass
      final pass = await _parseAndValidatePass(qrData);
      if (pass != null) {
        debugPrint('✅ QR code validation successful');
        setState(() {
          _scannedPass = pass;
          _currentStep = ValidationStep.passDetails;
          _isProcessing = false;
          _scanningEnabled = false; // Disable scanning after success
        });
        controller?.stop();
      } else {
        debugPrint(
            '❌ QR code validation failed - no pass found or access denied');
        setState(() {
          _errorMessage = _errorMessage ??
              'QR code not recognized or access denied. This could be because:\n\n'
                  '• The QR code is not a valid pass\n'
                  '• The pass is from a different authority\n'
                  '• You don\'t have permission to process this pass\n\n'
                  'Try entering the backup code manually or contact your administrator.';
          _isProcessing = false;
          // Keep scanning enabled for retry after cooldown
        });
        _startCooldownTimer();
      }
    } catch (e) {
      debugPrint('❌ QR validation error: $e');
      setState(() {
        _errorMessage =
            'Network error while validating QR code. Please check your internet connection and try again.';
        _isProcessing = false;
        // Keep scanning enabled for retry after cooldown
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
      debugPrint('🔍 Starting backup code validation: $backupCode');

      // Validate backup code and get pass
      final pass = await _validatePassByBackupCode(backupCode);
      if (pass != null) {
        debugPrint(
            '✅ Backup code validation successful, found pass: ${pass.passId}');
        setState(() {
          _scannedPass = pass;
          _currentStep = ValidationStep.passDetails;
          _isProcessing = false;
        });
      } else {
        debugPrint('❌ Backup code validation failed');
        setState(() {
          _errorMessage = _errorMessage ??
              'Backup code not found or access denied. This could be because:\n\n'
                  '• The backup code is incorrect (check for typos)\n'
                  '• The pass is from a different authority\n'
                  '• You don\'t have permission to process this pass\n\n'
                  'Please verify the 8-character code (XXXX-XXXX format) or contact your administrator.';
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Backup code validation error: $e');
      setState(() {
        _errorMessage =
            'Network error while validating backup code. Please check your internet connection and try again.';
        _isProcessing = false;
      });
    }
  }

  void _proceedToDeduction() async {
    if (_scannedPass == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      debugPrint(
          '🚀 Starting verification preference check for pass: ${_scannedPass!.passId}');

      // Get the pass owner's verification preference
      final verificationMethod =
          await ProfileManagementService.getPassOwnerVerificationPreference(
              _scannedPass!.passId);

      debugPrint('📨 Received verification method: $verificationMethod');

      // Map to internal enum
      switch (verificationMethod) {
        case PassVerificationMethod.none:
          _validationPreference = ValidationPreference.direct;
          debugPrint('✅ Set preference to: direct');
          break;
        case PassVerificationMethod.pin:
          _validationPreference = ValidationPreference.pin;
          debugPrint('✅ Set preference to: pin');
          break;
        case PassVerificationMethod.secureCode:
          _validationPreference = ValidationPreference.secureCode;
          debugPrint('✅ Set preference to: secureCode');
          break;
      }

      setState(() {
        _isProcessing = false;
      });

      if (_validationPreference == ValidationPreference.direct) {
        debugPrint('➡️ Proceeding with direct deduction (no verification)');
        // Direct deduction without verification
        _performEntryDeduction();
      } else {
        debugPrint('➡️ Requiring verification: $_validationPreference');
        // Require verification
        if (_validationPreference == ValidationPreference.secureCode) {
          _dynamicSecureCode = _generateSecureCode();
          debugPrint('🔐 Generated secure code: $_dynamicSecureCode');

          // Save secure code to database with expiry (10 minutes)
          final expiryTime = DateTime.now().add(const Duration(minutes: 10));
          await _supabase.from('purchased_passes').update({
            'secure_code': _dynamicSecureCode,
            'secure_code_expires_at': expiryTime.toIso8601String(),
          }).eq('id', _scannedPass!.passId);

          debugPrint(
              '💾 Secure code saved to database, expires at: $expiryTime');

          // Send the secure code to the pass owner (realtime + future SMS)
          await _sendSecureCodeToPassOwner(
              _scannedPass!.passId, _dynamicSecureCode!);
        }
        setState(() {
          _currentStep = ValidationStep.verification;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Failed to get verification preferences: $e';
      });
    }
  }

  void _completeValidation() {
    setState(() {
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

        // Verify PIN is 3 digits and numeric
        if (enteredPin.length == 3 &&
            RegExp(r'^[0-9]+$').hasMatch(enteredPin)) {
          // Get the stored PIN from database and verify
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
        // Verify secure code against database using 3-digit boxes
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
        await _performEntryDeduction();
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

  Future<void> _performEntryDeduction() async {
    setState(() {
      _currentStep = ValidationStep.processing;
      _isProcessing = true;
    });

    try {
      if (_scannedPass == null) {
        throw Exception('No pass selected');
      }

      // Call PassService to deduct entry
      final success = await PassService.deductEntry(_scannedPass!.passId);

      if (!success) {
        throw Exception('Failed to deduct entry from database');
      }

      // Update local pass object
      _scannedPass = PurchasedPass(
        passId: _scannedPass!.passId,
        vehicleDescription: _scannedPass!.vehicleDescription,
        passDescription: _scannedPass!.passDescription,
        borderName: _scannedPass!.borderName,
        entryLimit: _scannedPass!.entryLimit,
        entriesRemaining: _scannedPass!.entriesRemaining - 1,
        issuedAt: _scannedPass!.issuedAt,
        activationDate: _scannedPass!.activationDate,
        expiresAt: _scannedPass!.expiresAt,
        status: _scannedPass!.status,
        currency: _scannedPass!.currency,
        amount: _scannedPass!.amount,
        qrCode: _scannedPass!.qrCode,
        shortCode: _scannedPass!.shortCode,
        authorityId: _scannedPass!.authorityId,
        authorityName: _scannedPass!.authorityName,
        countryName: _scannedPass!.countryName,
        vehicleNumberPlate: _scannedPass!.vehicleNumberPlate,
        vehicleVin: _scannedPass!.vehicleVin,
      );

      setState(() {
        _currentStep = ValidationStep.completed;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to deduct entry: $e';
        _currentStep = ValidationStep.completed;
        _isProcessing = false;
      });
    }
  }

  void _resetScanning() {
    setState(() {
      _currentStep = ValidationStep.scanning;
      _scannedPass = null;
      _validationPreference = null;
      _dynamicSecureCode = null;
      _errorMessage = null;
      _isProcessing = false;
      _useBackupCode = false;
      _secureCodeHasError = false;

      // Reset scanning controls
      _scanningEnabled = true;
      _lastScanAttempt = null;
    });

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

  String _generateSecureCode() {
    // Generate a 3-digit secure code (100-999)
    final random = DateTime.now().millisecondsSinceEpoch;
    return (random % 900 + 100).toString();
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
          '🔍 Parsing QR data: ${qrData.substring(0, qrData.length > 50 ? 50 : qrData.length)}...');

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
        if (pass.vehicleNumberPlate != null &&
            pass.vehicleNumberPlate!.isNotEmpty)
          _buildSummaryRow('Number Plate', pass.vehicleNumberPlate!, color),
        if (pass.vehicleVin != null && pass.vehicleVin!.isNotEmpty)
          _buildSummaryRow('VIN', pass.vehicleVin!, color),
        if (pass.authorityName != null)
          _buildSummaryRow('Authority', pass.authorityName!, color),
        if (pass.countryName != null)
          _buildSummaryRow('Country', pass.countryName!, color),
        if (pass.borderName != null)
          _buildSummaryRow('Border', pass.borderName!, color),
        _buildSummaryRow('Status', pass.statusDisplay, color),
        _buildSummaryRow('Entries', pass.entriesDisplay, color),
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
      final passBorderId = pass.borderId;

      debugPrint('📋 Pass Information:');
      debugPrint('  - Authority ID: $passAuthorityId');
      debugPrint('  - Border ID: $passBorderId');
      debugPrint('  - Country Name: ${pass.countryName}');
      debugPrint('👤 Current Border Official:');
      debugPrint('  - Authority ID: ${widget.currentAuthorityId}');
      debugPrint('  - Country ID: ${widget.currentCountryId}');
      debugPrint('  - Role: ${widget.role}');

      if (widget.role == AuthorityRole.borderOfficial) {
        // STEP 1: Check if pass has a border_id set
        if (passBorderId != null) {
          debugPrint('🔍 Pass has specific border: $passBorderId');

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
              .eq('border_id', passBorderId)
              .eq('is_active', true)
              .maybeSingle();

          if (assignmentResponse == null) {
            debugPrint(
                '❌ Border official not assigned to border: $passBorderId');
            setState(() {
              _errorMessage =
                  'Access denied: You are not assigned to process passes for this specific border. This pass is for a border you do not have access to.';
            });
            return false;
          }

          debugPrint('✅ Border official is assigned to border: $passBorderId');
          debugPrint('✅ Validation passed - can process border-specific pass');
          return true;
        } else {
          debugPrint('🔍 Pass has no specific border (general pass)');

          // STEP 3: For general passes, check if border official is from same authority
          if (widget.currentAuthorityId == null) {
            debugPrint('❌ Current user has no authority assigned');
            setState(() {
              _errorMessage =
                  'Error: Your account is not assigned to any authority. Please contact your administrator.';
            });
            return false;
          }

          if (widget.currentAuthorityId != passAuthorityId) {
            debugPrint(
                '❌ Authority mismatch: ${widget.currentAuthorityId} != $passAuthorityId');
            setState(() {
              _errorMessage =
                  'Access denied: This pass was issued by a different authority. You can only process passes from your own authority.';
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
                'Error: Your account is not assigned to any country. Please contact your administrator.';
          });
          return false;
        }

        // For local authority, we need to get the pass country info
        final passAuthorityInfo = await _getPassAuthorityInfo(pass.passId);
        if (passAuthorityInfo == null) {
          debugPrint('❌ Unable to get pass country information');
          setState(() {
            _errorMessage =
                'Unable to verify pass information. The pass may be invalid.';
          });
          return false;
        }

        final passCountryId = passAuthorityInfo['country_id'] as String?;
        if (widget.currentCountryId != passCountryId) {
          debugPrint(
              '❌ Country mismatch: ${widget.currentCountryId} != $passCountryId');
          setState(() {
            _errorMessage =
                'Access denied: This pass was issued by an authority in a different country. Local authorities can only validate passes from their own country.';
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
            'System error while validating permissions. Please try again or contact support.';
      });
      return false;
    }
  }

  /// Get the authority and country information for a pass
  Future<Map<String, dynamic>?> _getPassAuthorityInfo(String passId) async {
    try {
      final response = await _supabase.from('purchased_passes').select('''
            border_id,
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
          'border_id': response['border_id']
              as String?, // Get border_id directly from purchased_passes
        };
      }

      return null;
    } catch (e) {
      debugPrint('Error getting pass authority info: $e');
      return null;
    }
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
