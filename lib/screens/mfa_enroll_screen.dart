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
      // Start TOTP enrollment
      final enrollRes = await auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'EasyTax',
      );
      // Capture details
      _factorId = enrollRes.id; // factor id for subsequent challenge/verify
      _qrSvg = enrollRes.totp?.qrCode; // SVG string (totp can be null)
      // Some SDKs provide a secret field as an alternative. Guarded access.
      try {
        // ignore: avoid_dynamic_calls
        _secret = (enrollRes.totp as dynamic).secret as String?;
      } catch (_) {
        _secret = null;
      }

      // Immediately create a challenge to verify this new factor
      final challenge = await auth.mfa.challenge(factorId: _factorId!);
      _challengeId = challenge.id;
    } on AuthException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to start enrollment: $e';
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
                        onPressed: _loading ? null : _startEnroll,
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
