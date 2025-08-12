import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/mfa_challenge_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cydtpwbgzilgrpozvesv.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN5ZHRwd2JnemlsZ3Jwb3p2ZXN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM5MzcyMTAsImV4cCI6MjA2OTUxMzIxMH0._cp0DYb56Krctnz74QcPIJT2m5b-hE6-zGpceskFYXo',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cross-Border Tax Platform',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        final session = snapshot.data?.session;
        if (session != null) {
          debugPrint('🔑 AuthWrapper: User session found: ${session.user.id}');
          return const _PostLoginGate();
        } else {
          debugPrint('🚺 AuthWrapper: No user session, showing auth screen');
          return const AuthScreen();
        }
      },
    );
  }
}

/// Checks if MFA is required (AAL = aal2) and if so, presents the challenge
/// screen, then re-checks before showing the HomeScreen.
class _PostLoginGate extends StatefulWidget {
  const _PostLoginGate();

  @override
  State<_PostLoginGate> createState() => _PostLoginGateState();
}

class _PostLoginGateState extends State<_PostLoginGate> {
  bool _checking = true;
  bool _needsMfa = false;

  @override
  void initState() {
    super.initState();
    _checkAalAndProceed();
  }

  Future<void> _checkAalAndProceed() async {
    setState(() {
      _checking = true;
      _needsMfa = false;
    });
    try {
      final res = Supabase.instance.client.auth.mfa
          .getAuthenticatorAssuranceLevel();
      final current = res.currentLevel;
      final next = res.nextLevel;
      final needs =
          next == AuthenticatorAssuranceLevels.aal2 && current != next;
      if (needs) {
        setState(() => _needsMfa = true);
        // Push challenge screen and wait for completion
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MfaChallengeScreen()),
        );
        // Re-check AAL after verification attempt
        final res2 = Supabase.instance.client.auth.mfa
            .getAuthenticatorAssuranceLevel();
        final ok = res2.currentLevel == AuthenticatorAssuranceLevels.aal2;
        setState(() {
          _needsMfa = !ok;
          _checking = false;
        });
      } else {
        setState(() {
          _needsMfa = false;
          _checking = false;
        });
      }
    } catch (e) {
      // On error, allow app to proceed but log.
      debugPrint('AAL check failed: $e');
      setState(() {
        _needsMfa = false;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_needsMfa) {
      // If still needed after attempt, show challenge inline as fallback
      return const MfaChallengeScreen();
    }
    return const HomeScreen();
  }
}
