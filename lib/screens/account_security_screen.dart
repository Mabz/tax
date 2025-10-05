import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mfa_enroll_screen.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  // Change password controllers
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _changingPassword = false;

  // MFA factors state
  bool _loadingFactors = true;
  String? _factorsError;
  List<dynamic> _totpFactors = const [];

  @override
  void initState() {
    super.initState();
    _refreshFactors();
  }

  Future<void> _refreshFactors() async {
    setState(() {
      _loadingFactors = true;
      _factorsError = null;
      _totpFactors = const [];
    });
    try {
      final res = await Supabase.instance.client.auth.mfa.listFactors();
      setState(() {
        _totpFactors = res.totp; // v2 returns a list of factor objects
        _loadingFactors = false;
      });
    } on AuthException catch (e) {
      setState(() {
        _factorsError = e.message;
        _loadingFactors = false;
      });
    } catch (e) {
      setState(() {
        _factorsError = 'Failed to load factors: $e';
        _loadingFactors = false;
      });
    }
  }

  Future<void> _unenroll(String factorId) async {
    try {
      // v2 unenroll may take positional id
      await Supabase.instance.client.auth.mfa.unenroll(factorId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MFA factor removed.')),
        );
      }
      await _refreshFactors();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPasswordCtrl.text;
    final next = _newPasswordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    if (next.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 8 characters.')),
      );
      return;
    }
    if (next != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    setState(() => _changingPassword = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final email = user?.email;
      if (email == null) {
        throw 'No signed-in user email.';
      }

      // Re-authenticate to validate current password
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: current,
      );

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: next),
      );

      if (!mounted) return;
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account & Security')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Change Password section
              Text(
                'Change Password',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _currentPasswordCtrl,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newPasswordCtrl,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPasswordCtrl,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: _changingPassword ? null : _changePassword,
                  child: _changingPassword
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Update Password'),
                ),
              ),
              const SizedBox(height: 24),

              // Two-Factor Authentication section
              Text(
                'Two‑Factor Authentication (TOTP)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_factorsError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_factorsError!,
                      style: const TextStyle(color: Colors.red)),
                ),
              if (_loadingFactors)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_totpFactors.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MFA not enabled',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                  'Add a TOTP authenticator for extra account protection.'),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.verified_user),
                                  label: const Text('Enable 2FA'),
                                  onPressed: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const MfaEnrollScreen(),
                                      ),
                                    );
                                    if (!mounted) return;
                                    await _refreshFactors();
                                  },
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  )
                else ...[
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _totpFactors.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final factor = _totpFactors[index];
                      final factorData = factor as dynamic;
                      final friendlyName = factorData.friendlyName as String?;
                      final factorId = factorData.id as String;
                      final isEmpty =
                          friendlyName == null || friendlyName.isEmpty;

                      return ListTile(
                        leading: Icon(
                          Icons.verified_user,
                          color: isEmpty ? Colors.orange : Colors.green,
                        ),
                        title: Text(
                          isEmpty ? 'Unnamed Authenticator' : friendlyName,
                          style: TextStyle(
                            color: isEmpty ? Colors.orange.shade700 : null,
                          ),
                        ),
                        subtitle: Text(
                          isEmpty
                              ? 'Time‑based one‑time password (needs setup)'
                              : 'Time‑based one‑time password',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isEmpty) ...[
                              TextButton(
                                onPressed: () async {
                                  // Remove the broken factor and restart enrollment
                                  await _unenroll(factorId);
                                  if (!mounted) return;
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const MfaEnrollScreen(),
                                    ),
                                  );
                                  if (!mounted) return;
                                  await _refreshFactors();
                                },
                                child: const Text('Fix'),
                              ),
                              const SizedBox(width: 8),
                            ],
                            TextButton(
                              onPressed: () => _unenroll(factorId),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add another authenticator'),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const MfaEnrollScreen()),
                        );
                        if (!mounted) return;
                        await _refreshFactors();
                      },
                    ),
                  )
                ]
              ],
            ],
          ),
        ),
      ),
    );
  }
}
