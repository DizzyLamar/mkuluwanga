import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _districtController = TextEditingController();
  final _professionController = TextEditingController();
  final _bioController = TextEditingController();
  final _interestController = TextEditingController();
  String? _avatarUrl;
  List<String> _interests = [];
  bool _loading = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final res = await _supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (res != null) {
      final map = Map<String, dynamic>.from(res as Map);
      _nameController.text = map['full_name'] ?? '';
      _phoneController.text = map['phone_number'] ?? '';
      _districtController.text = map['district'] ?? '';
      _professionController.text = map['profession'] ?? '';
      _bioController.text = map['bio'] ?? '';
      setState(() {
        _avatarUrl = map['avatar_url']?.toString();
      });

      final interestsRes = await _supabase
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
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
    );
    if (xfile == null) return;

    setState(() {
      _loading = true;
    });

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final path =
        'avatars/${user.id}/${DateTime.now().millisecondsSinceEpoch}_${xfile.name}';

    try {
      final file = File(xfile.path);
      await _supabase.storage
          .from('avatars')
          .uploadBinary(path, await file.readAsBytes());
      final url = _supabase.storage.from('avatars').getPublicUrl(path);

      await _supabase
          .from('users')
          .update({'avatar_url': url})
          .eq('id', user.id);

      if (mounted) {
        setState(() {
          _avatarUrl = url;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  void _addInterest() {
    if (_interestController.text.trim().isEmpty) return;
    final newInterest = _interestController.text.trim();
    if (!_interests.contains(newInterest)) {
      setState(() {
        _interests.add(newInterest);
      });
      _interestController.clear();
    }
  }

  void _removeInterest(String interest) {
    setState(() {
      _interests.remove(interest);
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
    });
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('users').update({
        'full_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'district': _districtController.text.trim(),
        'profession': _professionController.text.trim(),
        'bio': _bioController.text.trim(),
      }).eq('id', user.id);

      await _supabase.from('user_interests').delete().eq('user_id', user.id);

      if (_interests.isNotEmpty) {
        await _supabase.from('user_interests').insert(
              _interests
                  .map((interest) => {
                        'user_id': user.id,
                        'interest': interest,
                      })
                  .toList(),
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _districtController.dispose();
    _professionController.dispose();
    _bioController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  if (_avatarUrl != null)
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(_avatarUrl!),
                    )
                  else
                    const CircleAvatar(
                      radius: 60,
                      child: Icon(Icons.person, size: 60),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFF6A5AE0),
                      radius: 20,
                      child: IconButton(
                        onPressed: _loading ? null : _pickAndUploadAvatar,
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _bioController,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  prefixIcon: const Icon(Icons.edit_note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                maxLines: 3,
                maxLength: 200,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _districtController,
                decoration: InputDecoration(
                  labelText: 'District',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _professionController,
                decoration: InputDecoration(
                  labelText: 'Profession',
                  prefixIcon: const Icon(Icons.work),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Interests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _interestController,
                      decoration: InputDecoration(
                        hintText: 'Add an interest',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onFieldSubmitted: (_) => _addInterest(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _addInterest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A5AE0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_interests.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _interests.map((interest) {
                    return Chip(
                      label: Text(interest),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () => _removeInterest(interest),
                      backgroundColor: const Color(0xFF6A5AE0).withOpacity(0.1),
                      labelStyle: const TextStyle(
                        color: Color(0xFF6A5AE0),
                        fontFamily: 'Inter',
                      ),
                    );
                  }).toList(),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'No interests added yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A5AE0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
