import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _signedIn = false;
  String? _role; // 'MENTOR' or 'MENTEE'
  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((data) {
          final session = data.session;
          if (session != null) {
            _restoreSession(session.user);
          } else {
            if (mounted) {
              setState(() {
                _signedIn = false;
                _role = null;
                _loading = false;
              });
            }
          }
        });

    // Check initial session
    final initialSession = Supabase.instance.client.auth.currentSession;
    if (initialSession == null) {
      setState(() {
        _loading = false;
        _signedIn = false;
      });
    }
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _restoreSession(User user) async {
    final supabase = Supabase.instance.client;
    
    if (user.emailConfirmedAt == null) {
      // Email not confirmed, sign out and show welcome screen
      await supabase.auth.signOut();
      if (mounted) {
        setState(() {
          _signedIn = false;
          _role = null;
          _loading = false;
        });
      }
      return;
    }
    
    try {
      final res = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      final map = res != null ? Map<String, dynamic>.from(res as Map) : null;
      if (mounted) {
        setState(() {
          _signedIn = true;
          _role = map != null && map['role'] != null
              ? map['role'].toString().toUpperCase()
              : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _signedIn = true;
          _role = null;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_signedIn) {
      // Pass role to HomeScreen so it can show the correct dashboard
      return HomeScreen(userRole: _role);
    }

    return const WelcomeScreen();
  }
}
