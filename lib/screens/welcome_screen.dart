// lib/screens/welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:mkuluwanga/screens/login_screen.dart'; // Update with your project name

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Placeholder for your illustration
              SizedBox(
                height: 250,
                child: Image(
                  image: AssetImage('assets/images/1.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 48),
              const Text(
                'Stay connected, grow stronger',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to the Login Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  child: const Text('Get Started'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
