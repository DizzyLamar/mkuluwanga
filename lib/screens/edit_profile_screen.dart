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
  String? _avatarUrl;
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
      setState(() {
        _avatarUrl = map['avatar_url']?.toString();
      });
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
    });
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('users')
          .update({
        'full_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'district': _districtController.text.trim(),
        'profession': _professionController.text.trim(),
      })
          .eq('id', user.id);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_avatarUrl != null)
                CircleAvatar(
                  radius: 48,
                  backgroundImage: NetworkImage(_avatarUrl!),
                )
              else
                const CircleAvatar(
                  radius: 48,
                  child: Icon(Icons.person, size: 48),
                ),
              TextButton.icon(
                onPressed: _loading ? null : _pickAndUploadAvatar,
                icon: const Icon(Icons.upload_file),
                label: const Text('Change Avatar'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextFormField(
                controller: _districtController,
                decoration: const InputDecoration(labelText: 'District'),
              ),
              TextFormField(
                controller: _professionController,
                decoration: const InputDecoration(labelText: 'Profession'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveProfile,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
