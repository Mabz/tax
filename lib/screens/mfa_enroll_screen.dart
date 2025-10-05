import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MfaEnrollScreen extends StatefulWidget {
  const MfaEnrollScreen({super.key});

  @override
  State<MfaEnrollScreen> createState() => _MfaEnrollScreenState();
}

class _MfaEnrollScreenState extends State<MfaEnrollScreen> {
  bool _loading = true;
  String? _error;
  String? _qrSvg;
  String? _secret;
  String? _factorId;
  String? _challengeId;
  final _codeController = TextEditingController();
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _startEnroll();
  }

  Future<void> _startEnroll() async {
    // Clear the code input when restarting
    _codeController.clear();

    setState(() {
      _loading = true;
      _error = null;
      _qrSvg = null;
      _secret = null;
      _factorId = null;
      _challengeId = null;
      _verifying = false;
    });

    try {
      final auth = Supabase.instance.client.auth;

      // Check for existing factors and determine unique name
      String friendlyName = 'Authenticator App';
      final existingNames = <String>{};

      try {
        final factors = await auth.mfa.listFactors();
        final totpFactors = factors.totp;

        for (final factor in totpFactors) {
          final factorData = factor as dynamic;
          final factorId = factorData.id as String;
          final name = factorData.friendlyName as String?;
          final status = factorData.status as String?;

          // Remove factors that are unverified or have empty/null friendly names
          if (status != 'verified' || name == null || name.isEmpty) {
            try {
              await auth.mfa.unenroll(factorId);
            } catch (e) {
              // Continue with enrollment even if cleanup fails
            }
          } else {
            // Track existing verified factor names
            existingNames.add(name);
          }
        }

        // Generate unique friendly name
        int counter = 1;
        const baseName = 'Authenticator App';
        friendlyName = baseName;
        while (existingNames.contains(friendlyName)) {
          counter++;
          friendlyName = '$baseName $counter';
        }

        // Small delay to ensure cleanup is processed
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        // If we can't list factors, use timestamp to make name unique
        final timestamp =
            DateTime.now().millisecondsSinceEpoch.toString().substring(8);
        friendlyName = 'Authenticator App $timestamp';
      }

      // Start TOTP enrollment with unique name
      final enrollRes = await auth.mfa.enroll(
        factorType: FactorType.totp,
        friendlyName: friendlyName,
        issuer: 'EasyTax',
      );

      // Capture details
      _factorId = enrollRes.id;
      _qrSvg = enrollRes.totp?.qrCode;

      // Some SDKs provide a secret field as an alternative
      try {
        _secret = (enrollRes.totp as dynamic).secret as String?;
      } catch (_) {
        _secret = null;
      }

      // Create a challenge to verify this new factor
      final challenge = await auth.mfa.challenge(factorId: _factorId!);
      _challengeId = challenge.id;

      print('Enrollment started successfully. Factor ID: $_factorId');
    } on AuthException catch (e) {
      print('Auth error during enrollment: ${e.message}');
      _error = e.message;
    } catch (e) {
      print('General error during enrollment: $e');
      _error = 'Failed to start enrollment: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restartEnrollment() async {
    // Always show the force cleanup option since there seems to be a persistent factor
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Enrollment'),
        content: const Text(
          'Choose how to restart enrollment:\n\n'
          '• Force Clean: Remove all existing factors and start fresh\n'
          '• Add New: Try to add alongside existing factors\n'
          '• Debug: Show current factor status',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('debug'),
            child: const Text('Debug'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('add'),
            child: const Text('Add New'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('force'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Force Clean'),
          ),
        ],
      ),
    );

    if (result == 'add') {
      await _startEnroll();
    } else if (result == 'force') {
      await _forceCleanAndRestart();
    } else if (result == 'debug') {
      await _showDebugInfo();
    }
  }

  Future<void> _forceCleanAndRestart() async {
    setState(() {
      _loading = true;
      _error = null;
      _qrSvg = null;
      _secret = null;
      _factorId = null;
      _challengeId = null;
    });

    try {
      final auth = Supabase.instance.client.auth;

      // Aggressively remove ALL existing TOTP factors
      try {
        final factors = await auth.mfa.listFactors();
        for (final factor in factors.totp) {
          final factorData = factor as dynamic;
          final factorId = factorData.id as String;
          final name = factorData.friendlyName as String?;
          try {
            await auth.mfa.unenroll(factorId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed factor: ${name ?? "Unknown"}')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to remove factor: $e')),
              );
            }
          }
        }
      } catch (e) {
        setState(() {
          _error = 'Failed to list existing factors: $e';
          _loading = false;
        });
        return;
      }

      // Wait longer for cleanup to process
      await Future.delayed(const Duration(seconds: 2));

      // Now try to enroll with a completely unique name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueName = 'Authenticator $timestamp';

      final enrollRes = await auth.mfa.enroll(
        factorType: FactorType.totp,
        friendlyName: uniqueName,
        issuer: 'EasyTax',
      );

      // Capture details
      _factorId = enrollRes.id;
      _qrSvg = enrollRes.totp?.qrCode;

      try {
        _secret = (enrollRes.totp as dynamic).secret as String?;
      } catch (_) {
        _secret = null;
      }

      // Create a challenge to verify this new factor
      final challenge = await auth.mfa.challenge(factorId: _factorId!);
      _challengeId = challenge.id;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New factor created: $uniqueName')),
        );
      }
    } on AuthException catch (e) {
      setState(() => _error = 'Auth error: ${e.message}');
    } catch (e) {
      setState(() => _error = 'Failed to force clean and restart: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showDebugInfo() async {
    setState(() => _loading = true);

    try {
      final auth = Supabase.instance.client.auth;
      final factors = await auth.mfa.listFactors();
      final totpFactors = factors.totp;

      String debugInfo = 'Current TOTP Factors:\n\n';
      if (totpFactors.isEmpty) {
        debugInfo += 'No TOTP factors found.';
      } else {
        for (int i = 0; i < totpFactors.length; i++) {
          final factor = totpFactors[i] as dynamic;
          debugInfo += 'Factor ${i + 1}:\n';
          debugInfo += '  ID: ${factor.id}\n';
          debugInfo += '  Name: "${factor.friendlyName ?? "null"}"\n';
          debugInfo += '  Status: ${factor.status ?? "unknown"}\n';
          debugInfo += '  Created: ${factor.createdAt ?? "unknown"}\n\n';
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Debug Info'),
            content: SingleChildScrollView(
              child: Text(debugInfo,
                  style: const TextStyle(fontFamily: 'monospace')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Debug failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_factorId == null || _challengeId == null) {
      setState(() => _error = 'Enrollment is not ready. Please try again.');
      return;
    }
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Please enter the 6-digit code.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      await auth.mfa.verify(
        factorId: _factorId!,
        challengeId: _challengeId!,
        code: code,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Two-factor authentication enabled.')),
      );
      Navigator.of(context).maybePop();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Verification failed: $e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enable Two‑Factor Authentication')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Scan the QR code with your authenticator app (e.g. Google Authenticator, Authy) and then enter the 6‑digit code to verify.',
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      const SizedBox(height: 12),
                      if (_qrSvg != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Center(
                            child: SvgPicture.string(
                              _qrSvg!,
                              width: 220,
                              height: 220,
                            ),
                          ),
                        )
                      else
                        const Center(child: Text('QR code unavailable')),
                      const SizedBox(height: 12),
                      if (_secret != null) ...[
                        Text(
                          'Or enter this secret manually:',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          _secret!,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: '6‑digit code',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _verifying ? null : _verify,
                          child: _verifying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.4),
                                )
                              : const Text('Verify and enable'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed:
                            _loading || _verifying ? null : _restartEnrollment,
                        child: const Text('Restart enrollment'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
