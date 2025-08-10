import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mfa_enroll_screen.dart';

class MfaChallengeScreen extends StatefulWidget {
  const MfaChallengeScreen({super.key});

  @override
  State<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends State<MfaChallengeScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _factorId;
  String? _challengeId;

  @override
  void initState() {
    super.initState();
    _prepareChallenge();
  }

  Future<void> _prepareChallenge() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      final factors = await auth.mfa.listFactors();
      final totpFactors = factors.totp;
      if (totpFactors.isEmpty) {
        setState(() {
          _error = null;
          _isLoading = false;
        });
        // No factor: show enroll UI in build
        return;
      }
      // Choose first active TOTP factor
      _factorId = totpFactors.first.id;
      final challenge = await auth.mfa.challenge(factorId: _factorId!);
      _challengeId = challenge.id;
    } catch (e) {
      setState(() {
        _error = 'Failed to start MFA challenge: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    if (_factorId == null || _challengeId == null) {
      setState(() => _error = 'MFA is not ready. Please try again.');
      return;
    }
    setState(() {
      _isLoading = true;
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
      // On success, pop this screen so wrapper shows the app.
      Navigator.of(context).maybePop();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Verification failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      appBar: AppBar(title: const Text('Two‑Factor Authentication')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_factorId == null && _challengeId == null) ...[
                const Text(
                  'Two‑factor authentication is not set up on this account.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const MfaEnrollScreen()),
                            );
                            if (!mounted) return;
                            // After enrollment, retry challenge
                            await _prepareChallenge();
                          },
                    icon: const Icon(Icons.verified_user),
                    label: const Text('Set up 2FA (TOTP)'),
                  ),
                ),
              ] else ...[
                const Text(
                  'Enter the 6-digit code from your authenticator app to continue.',
                ),
              ],
              const SizedBox(height: 12),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verify,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Verify and continue'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isLoading ? null : _prepareChallenge,
                child: const Text('Resend challenge'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
