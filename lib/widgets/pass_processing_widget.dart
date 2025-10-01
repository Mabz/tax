import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/enhanced_border_service.dart';
import '../services/pass_verification_service.dart';
import '../enums/pass_verification_method.dart';
import '../models/purchased_pass.dart';

/// Widget for border officials to process pass check-in/check-out
class PassProcessingWidget extends StatefulWidget {
  final String borderId;
  final String borderName;

  const PassProcessingWidget({
    super.key,
    required this.borderId,
    required this.borderName,
  });

  @override
  State<PassProcessingWidget> createState() => _PassProcessingWidgetState();
}

class _PassProcessingWidgetState extends State<PassProcessingWidget> {
  final TextEditingController _passIdController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _secureCodeController = TextEditingController();
  bool _isLoading = false;
  PassActionInfo? _passAction;
  PurchasedPass? _verifiedPass;
  PassVerificationMethod? _verificationMethod;
  String? _error;
  PassMovementResult? _lastResult;
  bool _showVerificationStep = false;

  @override
  void dispose() {
    _passIdController.dispose();
    _pinController.dispose();
    _secureCodeController.dispose();
    super.dispose();
  }

  Future<void> _scanPassId(String passId) async {
    if (passId.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _passAction = null;
      _verifiedPass = null;
      _verificationMethod = null;
      _lastResult = null;
      _showVerificationStep = false;
    });

    try {
      // Step 1: Verify the pass exists and get pass details
      final pass = await PassVerificationService.verifyPass(
        code: passId.trim(),
        isQrCode: true, // Assume QR code for now, could be enhanced
      );

      if (pass == null) {
        setState(() {
          _error = 'Pass not found or invalid';
          _isLoading = false;
        });
        return;
      }

      // Step 2: Determine what action would be performed
      final action =
          await EnhancedBorderService.determinePassAction(pass.passId);

      // Step 3: Check if current official can perform this action
      final canPerform = await EnhancedBorderService.canProcessMovementType(
        borderId: widget.borderId,
        movementType: action.actionType,
      );

      if (!canPerform) {
        setState(() {
          _error =
              'You do not have permission to perform ${action.actionDescription} at this border';
          _isLoading = false;
        });
        return;
      }

      // Step 4: Get verification method from user preferences
      final verificationMethod =
          await PassVerificationService.getPassVerificationMethod(pass.passId);

      setState(() {
        _verifiedPass = pass;
        _passAction = action;
        _verificationMethod = verificationMethod;
        _showVerificationStep =
            verificationMethod != PassVerificationMethod.none;
        _isLoading = false;
      });

      // If no verification needed, we're ready to process
      if (verificationMethod == PassVerificationMethod.none) {
        // Auto-generate secure code if needed for display
        if (verificationMethod == PassVerificationMethod.secureCode) {
          await PassVerificationService.generateSecureCode(pass.passId);
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyAndProcess() async {
    if (_verifiedPass == null ||
        _passAction == null ||
        _verificationMethod == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      bool verificationPassed = true;

      // Perform verification based on method
      if (_verificationMethod == PassVerificationMethod.pin) {
        if (_pinController.text.trim().isEmpty) {
          setState(() {
            _error = 'Please enter the PIN';
            _isLoading = false;
          });
          return;
        }

        verificationPassed = await PassVerificationService.verifyPin(
          passId: _verifiedPass!.passId,
          pin: _pinController.text.trim(),
        );

        if (!verificationPassed) {
          setState(() {
            _error = 'Invalid PIN. Please check with the pass holder.';
            _isLoading = false;
          });
          return;
        }
      } else if (_verificationMethod == PassVerificationMethod.secureCode) {
        if (_secureCodeController.text.trim().isEmpty) {
          setState(() {
            _error = 'Please enter the secure code';
            _isLoading = false;
          });
          return;
        }

        verificationPassed = await PassVerificationService.verifySecureCode(
          passId: _verifiedPass!.passId,
          secureCode: _secureCodeController.text.trim(),
        );

        if (!verificationPassed) {
          setState(() {
            _error = 'Invalid secure code. Please check with the pass holder.';
            _isLoading = false;
          });
          return;
        }
      }

      // Process the movement using enhanced border service
      final result = await EnhancedBorderService.processPassMovement(
        passId: _verifiedPass!.passId,
        borderId: widget.borderId,
      );

      setState(() {
        _lastResult = result;
        _passAction = null;
        _verifiedPass = null;
        _verificationMethod = null;
        _showVerificationStep = false;
        _isLoading = false;
      });

      // Clear all inputs for next scan
      _passIdController.clear();
      _pinController.clear();
      _secureCodeController.clear();

      // Show success feedback
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.actionDescription),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      // Show error feedback
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Process Passes - ${widget.borderName}'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pass ID Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scan or Enter Pass ID',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passIdController,
                      decoration: InputDecoration(
                        hintText: 'Enter pass ID or scan QR code',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _passIdController.clear(),
                              icon: const Icon(Icons.clear),
                            ),
                            IconButton(
                              onPressed: () =>
                                  _scanPassId(_passIdController.text),
                              icon: const Icon(Icons.search),
                            ),
                          ],
                        ),
                      ),
                      onSubmitted: _scanPassId,
                      enabled: !_isLoading,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Loading indicator
            if (_isLoading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Colors.orange),
                      SizedBox(height: 16),
                      Text('Processing...'),
                    ],
                  ),
                ),
              ),

            // Error display
            if (_error != null)
              Card(
                color: Colors.red.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text(
                            'Error',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),

            // Pass action preview
            if (_passAction != null)
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
                            _passAction!.isCheckIn ? Icons.login : Icons.logout,
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
                      _buildPassDetails(),

                      // Verification step (if required)
                      if (_showVerificationStep) ...[
                        const SizedBox(height: 16),
                        _buildVerificationStep(),
                      ],

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _verifyAndProcess,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            _passAction!.actionDescription,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Last result display
            if (_lastResult != null)
              Card(
                color: Colors.green.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text(
                            'Success',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Action: ${_lastResult!.actionDescription}'),
                      Text(
                          'Status: ${_lastResult!.previousStatus} → ${_lastResult!.newStatus}'),
                      if (_lastResult!.entriesDeducted > 0)
                        Text(
                            'Entries deducted: ${_lastResult!.entriesDeducted}'),
                      Text(
                          'Entries remaining: ${_lastResult!.entriesRemaining}'),
                      Text(
                          'Processed at: ${_lastResult!.processedAt.toString().split('.')[0]}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassDetails() {
    if (_passAction == null || _verifiedPass == null)
      return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_verifiedPass!.vehicleDescription.isNotEmpty)
          Text('Vehicle: ${_verifiedPass!.vehicleDescription}'),
        if (_verifiedPass!.vehicleNumberPlate != null &&
            _verifiedPass!.vehicleNumberPlate!.isNotEmpty)
          Text('Plate: ${_verifiedPass!.vehicleNumberPlate}'),
        Text('Current Status: ${_passAction!.currentStatus}'),
        Text('Entries Remaining: ${_passAction!.entriesRemaining}'),
        Text('Expires: ${_passAction!.expiresAt.toString().split(' ')[0]}'),
        if (_verificationMethod != null)
          Text('Verification: ${_verificationMethod!.displayName}'),
        if (_passAction!.willDeductEntry)
          const Text(
            'This action will deduct 1 entry',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.orange,
            ),
          ),
      ],
    );
  }

  Widget _buildVerificationStep() {
    if (_verificationMethod == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Verification Required',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _verificationMethod!.description,
            style: TextStyle(
              color: Colors.blue.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          if (_verificationMethod == PassVerificationMethod.pin) ...[
            TextField(
              controller: _pinController,
              decoration: const InputDecoration(
                labelText: 'Enter PIN from pass holder',
                hintText: 'Ask the pass holder for their PIN',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pin),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              enabled: !_isLoading,
            ),
          ] else if (_verificationMethod ==
              PassVerificationMethod.secureCode) ...[
            TextField(
              controller: _secureCodeController,
              decoration: const InputDecoration(
                labelText: 'Enter Secure Code',
                hintText: 'Ask the pass holder to show their secure code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.verified_user),
              ),
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              enabled: !_isLoading,
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _verificationMethod == PassVerificationMethod.pin
                        ? 'The pass holder must provide their personal PIN to authorize this transaction.'
                        : 'The pass holder must show you the secure code displayed on their device.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
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
