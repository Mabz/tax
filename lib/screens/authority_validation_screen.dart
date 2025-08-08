import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/purchased_pass.dart';
import '../services/pass_service.dart';

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

  const AuthorityValidationScreen({
    super.key,
    required this.role,
  });

  @override
  State<AuthorityValidationScreen> createState() =>
      _AuthorityValidationScreenState();
}

class _AuthorityValidationScreenState extends State<AuthorityValidationScreen> {
  final TextEditingController _backupCodeController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _secureCodeController = TextEditingController();

  MobileScannerController? controller;
  ValidationStep _currentStep = ValidationStep.scanning;
  PurchasedPass? _scannedPass;
  ValidationPreference? _validationPreference;
  String? _dynamicSecureCode;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _useBackupCode = false;

  @override
  void dispose() {
    controller?.dispose();
    _backupCodeController.dispose();
    _pinController.dispose();
    _secureCodeController.dispose();
    super.dispose();
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
                    : 'Position QR code within the frame',
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
              if (barcode.rawValue != null && !_isProcessing) {
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
                const SizedBox(height: 8),
                Text(
                  'Enter the 8-character backup code (format: XXXX-XXXX)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                  maxLength: 9, // 8 + 1 hyphen
                  inputFormatters: [
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
                    final canSubmit =
                        RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(_backupCodeController.text);
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
    final isExpired = pass.isExpired;
    final hasEntries = pass.hasEntriesRemaining;
    final activationDate = pass.activationDate;
    final isPendingActivation = activationDate.isAfter(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pass Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive ? Colors.green.shade200 : Colors.red.shade200,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.error,
                  size: 48,
                  color: isActive ? Colors.green.shade600 : Colors.red.shade600,
                ),
                const SizedBox(height: 12),
                Text(
                  isActive ? 'Valid Pass' : 'Invalid Pass',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color:
                        isActive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  pass.statusDisplay,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        isActive ? Colors.green.shade600 : Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Pass Details
          _buildDetailCard('Pass Information', [
            _buildDetailRow(
                Icons.description, 'Description', pass.passDescription),
            _buildDetailRow(
                Icons.directions_car, 'Vehicle', pass.vehicleDescription),
            if (pass.vehicleNumberPlate != null)
              _buildDetailRow(
                  Icons.pin, 'Number Plate', pass.vehicleNumberPlate!),
            if (pass.vehicleVin != null && pass.vehicleVin!.isNotEmpty)
              _buildDetailRow(Icons.fingerprint, 'VIN', pass.vehicleVin!),
            if (pass.borderName != null)
              _buildDetailRow(Icons.location_on, 'Border', pass.borderName!),
          ]),

          const SizedBox(height: 16),

          _buildDetailCard('Entry Information', [
            _buildDetailRow(
              Icons.confirmation_number,
              'Entries',
              pass.entriesDisplay,
              valueColor: hasEntries ? Colors.black87 : Colors.red,
            ),
            _buildDetailRow(
              Icons.attach_money,
              'Amount',
              '${pass.currency} ${pass.amount.toStringAsFixed(2)}',
            ),
            _buildDetailRow(
              Icons.calendar_today,
              'Issued',
              _formatDate(pass.issuedAt),
            ),
            _buildDetailRow(
              Icons.play_arrow,
              'Activates',
              _formatDate(activationDate),
              valueColor: isPendingActivation ? Colors.orange : Colors.black87,
            ),
            _buildDetailRow(
              Icons.event,
              'Expires',
              _formatDate(pass.expiresAt),
              valueColor: isExpired ? Colors.red : Colors.black87,
            ),
          ]),

          const SizedBox(height: 32),

          // Action Buttons
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
                        ? 'Please ask the pass owner to enter their PIN'
                        : 'Please ask the pass owner for the secure code: $_dynamicSecureCode',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_validationPreference == ValidationPreference.pin) ...[
                    TextField(
                      controller: _pinController,
                      decoration: InputDecoration(
                        hintText: 'Enter PIN',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.lock),
                      ),
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ] else ...[
                    if (_dynamicSecureCode != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Show this code to pass owner:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _dynamicSecureCode!,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                                letterSpacing: 4,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _secureCodeController,
                      decoration: InputDecoration(
                        hintText: 'Enter secure code from pass owner',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.security),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              size: 80,
              color: isSuccess ? Colors.green.shade600 : Colors.red.shade600,
            ),
            const SizedBox(height: 24),
            Text(
              isSuccess
                  ? (widget.role == AuthorityRole.localAuthority
                      ? 'Validation Complete'
                      : 'Entry Deducted Successfully')
                  : 'Operation Failed',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (isSuccess && _scannedPass != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      _scannedPass!.passDescription,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.role == AuthorityRole.borderOfficial)
                      Text(
                        'Remaining entries: ${_scannedPass!.entriesRemaining - 1}/${_scannedPass!.entryLimit}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade700,
                        ),
                      ),
                  ],
                ),
              ),
            ] else if (!isSuccess) ...[
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
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.blue.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
  }

  Future<void> _validateQRCode(String qrData) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Parse QR code data and validate pass
      final pass = await _parseAndValidatePass(qrData);
      if (pass != null) {
        setState(() {
          _scannedPass = pass;
          _currentStep = ValidationStep.passDetails;
          _isProcessing = false;
        });
        controller?.stop();
      } else {
        setState(() {
          _errorMessage =
              'QR code not recognized. Please check the code or try entering the backup code manually.';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Network error. Please check your connection and try again.';
        _isProcessing = false;
      });
      debugPrint('QR validation error: $e');
    }
  }

  Future<void> _validateBackupCode(String backupCode) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      debugPrint('UI: Starting validation for backup code: $backupCode');
      // Validate backup code and get pass
      final pass = await _validatePassByBackupCode(backupCode);
      if (pass != null) {
        debugPrint('UI: Validation successful, found pass: ${pass.passId}');
        setState(() {
          _scannedPass = pass;
          _currentStep = ValidationStep.passDetails;
          _isProcessing = false;
        });
      } else {
        debugPrint('UI: Validation failed, no pass found');
        setState(() {
          _errorMessage =
              'Backup code not found. Please check the 8-character code and try again.';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Network error. Please check your connection and try again.';
        _isProcessing = false;
      });
      debugPrint('Backup code validation error: $e');
    }
  }

  void _proceedToDeduction() {
    // Simulate getting validation preference from pass owner settings
    // In real implementation, this would come from user preferences or pass settings
    final preferences = [
      ValidationPreference.direct,
      ValidationPreference.pin,
      ValidationPreference.secureCode,
    ];

    // For demo, randomly select a preference (in real app, get from user settings)
    _validationPreference = preferences[DateTime.now().millisecond % 3];

    if (_validationPreference == ValidationPreference.direct) {
      // Direct deduction without verification
      _performEntryDeduction();
    } else {
      // Require verification
      if (_validationPreference == ValidationPreference.secureCode) {
        _dynamicSecureCode = _generateSecureCode();
      }
      setState(() {
        _currentStep = ValidationStep.verification;
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
    });

    try {
      bool isValid = false;

      if (_validationPreference == ValidationPreference.pin) {
        // Verify PIN (in real app, check against stored PIN)
        isValid = _pinController.text.length >= 4;
      } else if (_validationPreference == ValidationPreference.secureCode) {
        // Verify secure code
        isValid = _secureCodeController.text == _dynamicSecureCode;
      }

      if (isValid) {
        await _performEntryDeduction();
      } else {
        setState(() {
          _errorMessage =
              'Invalid ${_validationPreference == ValidationPreference.pin ? 'PIN' : 'secure code'}';
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
    });

    _backupCodeController.clear();
    _pinController.clear();
    _secureCodeController.clear();

    controller?.start();
  }

  String _generateSecureCode() {
    // Generate a 6-digit secure code
    final random = DateTime.now().millisecondsSinceEpoch;
    return (random % 900000 + 100000).toString();
  }

  Future<PurchasedPass?> _parseAndValidatePass(String qrData) async {
    try {
      debugPrint(
          'Attempting to validate QR data: ${qrData.substring(0, qrData.length > 50 ? 50 : qrData.length)}...');
      final pass = await PassService.validatePassByQRCode(qrData);
      if (pass == null) {
        debugPrint(
            'QR validation returned null - pass not found or invalid format');
      } else {
        debugPrint('QR validation successful - found pass: ${pass.passId}');
      }
      return pass;
    } catch (e) {
      debugPrint('Error parsing QR data: $e');
      return null;
    }
  }

  Future<PurchasedPass?> _validatePassByBackupCode(String backupCode) async {
    try {
      debugPrint('Attempting to validate backup code: $backupCode');
      final pass = await PassService.validatePassByBackupCode(backupCode);
      if (pass == null) {
        debugPrint('Backup code validation returned null - code not found');
      } else {
        debugPrint(
            'Backup code validation successful - found pass: ${pass.passId}');
      }
      return pass;
    } catch (e) {
      debugPrint('Error validating backup code: $e');
      return null;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final compareDate = DateTime(date.year, date.month, date.day);
    final difference = nowDate.difference(compareDate);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == -1) {
      return 'Tomorrow';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < -1) {
      return '${-difference.inDays} days from now';
    } else {
      return '${difference.inDays} days ago';
    }
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
