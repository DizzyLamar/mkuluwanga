// lib/screens/signup_flow/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:mkuluwanga/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//import '../home_screen.dart';
import 'widgets/role_card.dart';
import 'widgets/form_progress_indicator.dart';

class SignUpFlow extends StatefulWidget {
  const SignUpFlow({super.key});

  @override
  State<SignUpFlow> createState() => _SignUpFlowState();
}

class _SignUpFlowState extends State<SignUpFlow> {
  final PageController _pageController = PageController();
  final _formKeyPage1 = GlobalKey<FormState>();
  final _formKeyPage2 = GlobalKey<FormState>();
  final _formKeyPage3 = GlobalKey<FormState>();
  final _formKeyPage4 = GlobalKey<FormState>();

  bool _isLoading = false;
  int _currentPage = 0;
  String? _selectedRole;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  // Controllers for user details
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _professionController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String? _selectedGender;
  String? _selectedDistrict;

  // Controllers for interests
  final Set<String> _selectedInterests = {};

  final List<String> _malawiDistricts = [
    'Balaka',
    'Blantyre',
    'Chikwawa',
    'Chiradzulu',
    'Chitipa',
    'Dedza',
    'Dowa',
    'Karonga',
    'Kasungu',
    'Likoma',
    'Lilongwe',
    'Machinga',
    'Mangochi',
    'Mchinji',
    'Mulanje',
    'Mwanza',
    'Mzimba',
    'Neno',
    'Nkhata Bay',
    'Nkhotakota',
    'Nsanje',
    'Ntcheu',
    'Ntchisi',
    'Phalombe',
    'Rumphi',
    'Salima',
    'Thyolo',
    'Zomba',
  ];

  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
  }

  void _buildPages() {
    _pages = [
      _buildRolePage(),
      _buildDetailsPage(),
      _buildLocationPage(),
      if (_selectedRole == 'Mentor') _buildMentorDetailsPage(),
      _buildInterestsPage(),
      _buildPasswordPage(),
    ];
  }

  @override
  void dispose() {
    // Dispose all controllers to prevent memory leaks
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _professionController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _nextPage() {
    // Validate current page before proceeding
    if (_currentPage == 0 && _selectedRole == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please choose a role.')));
      return;
    }
    if (_currentPage == 1 && !_formKeyPage1.currentState!.validate()) {
      return;
    }
    if (_currentPage == 2 && !_formKeyPage4.currentState!.validate()) {
      return;
    }

    if (_selectedRole == 'Mentor') {
      if (_currentPage == 3 && !_formKeyPage3.currentState!.validate()) {
        return;
      }
      if (_currentPage == 4 && _selectedInterests.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one area of expertise.'),
          ),
        );
        return;
      }
      if (_currentPage == 5 && !_formKeyPage2.currentState!.validate()) return;
    } else {
      if (_currentPage == 3 && _selectedInterests.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one interest.')),
        );
        return;
      }
      if (_currentPage == 4 && !_formKeyPage2.currentState!.validate()) return;
    }

    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      _submitForm();
    }
  }

  Future<void> _submitForm() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (authResponse.user != null) {
        final user = authResponse.user!;
        
        final profileData = {
          'id': user.id,
          'email': _emailController.text.trim(),
          'full_name': _nameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'bio': _bioController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()),
          'gender': _selectedGender,
          'district': _selectedDistrict,
          'role': _selectedRole?.toUpperCase(), // Converts 'Mentor' to 'MENTOR', 'Mentee' to 'MENTEE'
          'profession': _selectedRole == 'Mentor'
              ? _professionController.text.trim()
              : null,
        };

        await supabase.from('users').insert(profileData);

        // Handle interests insertion
        if (_selectedInterests.isNotEmpty) {
          // This assumes you have a table 'user_interests' with columns 'user_id' and 'interest'
          final interestRows = _selectedInterests
              .map(
                (interest) => {'user_id': user.id, 'interest': interest},
              )
              .toList();

          await supabase.from('user_interests').insert(interestRows);
        }

        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Confirm your email'),
                content: const Text(
                  'We\'ve sent a confirmation link to your email. Please check your inbox to complete the sign-up process.',
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ],
              );
            },
          );
        }
      } else {
        throw 'Sign up failed';
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

  // Helper to get the title for the app bar based on the current page
  String _getAppBarTitle() {
    int totalPages = _pages.length;
    int step = _currentPage + 1;
    return 'Sign Up (Step $step of $totalPages)';
  }

  @override
  Widget build(BuildContext context) {
    _buildPages(); // Rebuild pages list on each build
    return Scaffold(
      appBar: AppBar(
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease,
                ),
              )
            : null,
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: FormProgressIndicator(
            currentPage: _currentPage,
            totalPages: _pages.length,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (int page) => setState(() => _currentPage = page),
        children: _pages,
      ),
    );
  }

  // --- BUILD METHODS FOR EACH PAGE ---

  /// Builds the first page of the sign-up flow (Choose Role).
  Widget _buildRolePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Your Role',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Are you here to seek guidance or to provide it?',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          RoleCard(
            title: 'Mentee',
            description:
                'Seeking guidance and support on your mental health journey.',
            isSelected: _selectedRole == 'Mentee',
            onTap: () => setState(() => _selectedRole = 'Mentee'),
            imagePath:
                'assets/mentee.png', // Replace with your actual image asset
          ),
          const SizedBox(height: 16),
          RoleCard(
            title: 'Mentor',
            description:
                'Share your experiences and provide support to others.',
            isSelected: _selectedRole == 'Mentor',
            onTap: () => setState(() => _selectedRole = 'Mentor'),
            imagePath:
                'assets/mentor.png', // Replace with your actual image asset
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the second page of the sign-up flow (User Details).
  Widget _buildDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeyPage1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tell us about yourself',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _buildTextFormField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              validator: (value) => value == null || value.isEmpty
                  ? 'Please enter your name'
                  : null,
            ),
            _buildTextFormField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'Enter your email',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            _buildTextFormField(
              controller: _phoneController,
              label: 'Phone Number (Optional)',
              hint: 'Enter your phone number',
              keyboardType: TextInputType.phone,
            ),
            _buildTextFormField(
              controller: _bioController,
              label: 'Short Bio',
              hint: 'Tell us a little about yourself...',
              maxLines: 3,
              validator: (value) => value == null || value.isEmpty
                  ? 'Please enter a short bio'
                  : null,
            ),
            _buildTextFormField(
              controller: _ageController,
              label: 'Age',
              hint: 'Enter your age',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your age';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(hintText: 'Select'),
              initialValue: _selectedGender,
              items: ['Male', 'Female', 'Other', 'Prefer not to say']
                  .map(
                    (label) =>
                        DropdownMenuItem(value: label, child: Text(label)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedGender = value),
              validator: (value) =>
                  value == null ? 'Please select your gender' : null,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextPage,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the page for selecting location.
  Widget _buildLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeyPage4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Where are you located?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            const Text(
              'District',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                hintText: 'Select your district',
              ),
              initialValue: _selectedDistrict,
              items: _malawiDistricts
                  .map(
                    (label) =>
                        DropdownMenuItem(value: label, child: Text(label)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedDistrict = value),
              validator: (value) =>
                  value == null ? 'Please select your district' : null,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextPage,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the mentor-specific details page.
  Widget _buildMentorDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeyPage3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mentor Details',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _buildTextFormField(
              controller: _professionController,
              label: 'Profession',
              hint: 'e.g., Software Engineer, Doctor, etc.',
              validator: (value) => value == null || value.isEmpty
                  ? 'Please enter your profession'
                  : null,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextPage,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the page for selecting interests.
  Widget _buildInterestsPage() {
    // Interests can be dynamically loaded based on role if needed
    final interests = _selectedRole == 'Mentor'
        ? [
            'Anxiety',
            'Depression',
            'Stress Management',
            'Relationships',
            'Trauma',
            'Career Guidance',
          ]
        : [
            'Anxiety',
            'Depression',
            'Stress Management',
            'Relationships',
            'Family Issues',
            'School/Work Life',
          ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedRole == 'Mentor'
                ? 'Areas of Expertise'
                : 'What brings you here?',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select all that apply. This helps us find the right match for you.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children: interests.map((interest) {
              final isSelected = _selectedInterests.contains(interest);
              return ChoiceChip(
                label: Text(interest),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedInterests.add(interest);
                    } else {
                      _selectedInterests.remove(interest);
                    }
                  });
                },
                selectedColor: Theme.of(context).primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                ),
                backgroundColor: Colors.grey[200],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextPage,
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the final page of the sign-up flow (Create Password).
  Widget _buildPasswordPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeyPage2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a secure password',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _buildTextFormField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Enter your password',
              obscureText: !_passwordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              ),
              validator: (value) {
                if (value == null || value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                return null;
              },
            ),
            _buildTextFormField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              obscureText: !_confirmPasswordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _confirmPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () => setState(
                  () => _confirmPasswordVisible = !_confirmPasswordVisible,
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitForm,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for creating consistently styled text form fields
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          obscureText: obscureText,
          decoration: InputDecoration(hintText: hint, suffixIcon: suffixIcon),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
