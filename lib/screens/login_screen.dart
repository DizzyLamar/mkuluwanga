// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mkuluwanga/screens/home_screen.dart';
import 'package:mkuluwanga/screens/signup_flow/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final authResponse = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = authResponse.user;
      if (user != null) {
        if (user.emailConfirmedAt == null) {
          if (mounted) {
            await supabase.auth.signOut();
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Email Not Confirmed'),
                content: const Text(
                  'Please check your email and click the confirmation link before logging in. Check your spam folder if you don\'t see it.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await supabase.auth.resend(
                          type: OtpType.signup,
                          email: _emailController.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Confirmation email resent!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Resend Email'),
                  ),
                ],
              ),
            );
          }
          return;
        }

        String? userRole;
        try {
          final res = await supabase
              .from('users')
              .select('role')
              .eq('id', user.id)
              .single();
          userRole = res['role']?.toString().toUpperCase();
          if (userRole == null || (userRole != 'MENTOR' && userRole != 'MENTEE')) {
            throw 'User role not assigned. Please contact support.';
          }
        } catch (e) {
          if (mounted) {
            await supabase.auth.signOut();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('User profile not found. Please sign up again or contact support.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(userRole: userRole),
            ),
            (Route<dynamic> route) => false,
          );
        }
      }
    } on AuthException catch (e) {
      String errorMessage = 'Login failed';
      if (e.message.contains('Invalid login credentials')) {
        errorMessage = 'Invalid email or password';
      } else if (e.message.contains('Email not confirmed')) {
        errorMessage = 'Please confirm your email before logging in';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: const Text(
            'MkuluWanga',
            style: TextStyle(fontSize: 40.0, fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(hintText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Password'),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _login,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Login'),
              ),
            ),
            const SizedBox(height: 150),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?"),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUpFlow(),
                      ),
                    );
                  },
                  child: const Text('Sign up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
