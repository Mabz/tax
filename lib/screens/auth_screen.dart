import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handle user authentication (sign up or sign in)
  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        // Sign up flow
        debugPrint('🔐 Starting sign up process');

        final response = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (response.user != null) {
          debugPrint('✅ Sign up successful for: ${response.user!.email}');

          // User creation and role assignment handled automatically by Supabase cloud function
          debugPrint('✅ User signed up successfully: ${response.user!.email}');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Account created! Please check your email to confirm your account.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          debugPrint('❌ Sign up failed: No user returned');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to create account. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Sign in flow
        debugPrint('🔐 Starting sign in process');

        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (response.user != null) {
          debugPrint('✅ Sign in successful for: ${response.user!.email}');

          // User authentication successful - everything else handled by Supabase
          debugPrint('✅ User signed in successfully: ${response.user!.email}');
        } else {
          debugPrint('❌ Sign in failed: No user returned');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid email or password'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } on AuthException catch (e) {
      debugPrint('❌ Auth error: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Handle Google Sign In
  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      debugPrint('🔐 Starting Google sign in process');

      // Initialize Google Sign In
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
      );

      // Start the Google Sign In flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('❌ Google sign in aborted by user');
        return;
      }

      // Get authentication details from Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Sign in to Supabase with Google credentials
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user != null) {
        debugPrint('✅ Google sign in successful for: ${response.user!.email}');

        // User authentication successful - everything else handled by Supabase
        debugPrint('✅ Google sign in successful: ${response.user!.email}');
      } else {
        debugPrint('❌ Google sign in failed: No user returned');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to sign in with Google'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Google sign in error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign in failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  /// Handle Forgot Password flow
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid email to reset your password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reset email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + keyboardInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width < 600 ? 480 : 720,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left brand panel (hidden on small screens)
                    if (size.width >= 900)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 16),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.account_balance_wallet,
                                  color: Colors.white, size: 48),
                              SizedBox(height: 16),
                              Text(
                                'Cross-Border Tax Platform',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Sign in to manage passes, vehicles and validations across borders.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Auth card
                    Expanded(
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE3F2FD),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.lock_outline,
                                          color: Color(0xFF1E88E5)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _isSignUp
                                                ? 'Create your account'
                                                : 'Welcome back',
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _isSignUp
                                                ? 'Sign up to get started'
                                                : 'Sign in to continue',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Email
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon:
                                        const Icon(Icons.lock_outline_rounded),
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      icon: Icon(_obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined),
                                      onPressed: () => setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      }),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (_isSignUp && value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 8),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  runAlignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    TextButton(
                                      onPressed: _resetPassword,
                                      child: const Text('Forgot password?'),
                                    ),
                                    TextButton(
                                      onPressed: () => setState(
                                          () => _isSignUp = !_isSignUp),
                                      child: Text(
                                        _isSignUp
                                            ? 'Have an account? Sign in'
                                            : 'New here? Create account',
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isLoading ? null : _authenticate,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF1E88E5),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(_isSignUp ? 'Create account' : 'Sign in'),
                                  ),
                                ),

                                const SizedBox(height: 16),
                                Row(
                                  children: const [
                                    Expanded(child: Divider()),
                                    Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('OR'),
                                    ),
                                    Expanded(child: Divider()),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: _isGoogleLoading
                                        ? null
                                        : _signInWithGoogle,
                                    icon: _isGoogleLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.login, size: 20),
                                    label: Text(
                                      _isGoogleLoading
                                          ? 'Signing in...'
                                          : 'Continue with Google',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
