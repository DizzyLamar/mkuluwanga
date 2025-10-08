import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import '../widgets/app_main_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  List<String> _interests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _profile = null;
        _loading = false;
      });
      return;
    }

    try {
      final res = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      setState(
        () => _profile = res != null
            ? Map<String, dynamic>.from(res as Map)
            : null,
      );

      final interestsRes = await supabase
          .from('user_interests')
          .select('interest')
          .eq('user_id', user.id);
      if (interestsRes != null) {
        setState(() {
          _interests = (interestsRes as List)
              .map((e) => e['interest'].toString())
              .toList();
        });
      }
    } catch (e) {
      setState(() => _profile = null);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.auth.signOut();
      
      // Explicitly navigate to login screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_profile == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No profile found. You might not be logged in.'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadProfile, child: const Text('Retry')),
          ],
        ),
      );
    }

    final avatar = _profile!['avatar_url'] as String?;
    final bio = _profile!['bio'] as String?;

    return Scaffold(
      appBar: const AppMainBar(title: 'Profile'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: avatar != null
                          ? NetworkImage(avatar)
                          : null,
                      child: avatar == null
                          ? const Icon(Icons.person, size: 48)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _profile!['full_name'] ?? 'Unnamed',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final updated = await Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const EditProfileScreen(),
                                        ),
                                      );
                                  if (updated == true) _loadProfile();
                                },
                                icon: const Icon(Icons.edit),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _profile!['profession'] ?? '',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (bio != null && bio.isNotEmpty)
                            Text(
                              bio,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontFamily: 'Inter',
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Chip(label: Text(_profile!['role'] ?? '')),
                              const SizedBox(width: 8),
                              Text(
                                'District: ${_profile!['district'] ?? '-'}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Email'),
                      subtitle: Text(_profile!['email'] ?? '-'),
                    ),
                    ListTile(
                      title: const Text('Phone'),
                      subtitle: Text(_profile!['phone_number'] ?? '-'),
                    ),
                    ListTile(
                      title: const Text('Member since'),
                      subtitle: Text(
                        (_profile!['created_at'] ?? '').toString(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_interests.isNotEmpty)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Interests',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _interests.map((interest) {
                          return Chip(
                            label: Text(interest),
                            backgroundColor: const Color(0xFF6A5AE0).withOpacity(0.1),
                            labelStyle: const TextStyle(
                              color: Color(0xFF6A5AE0),
                              fontFamily: 'Inter',
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _logout,
                child: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
