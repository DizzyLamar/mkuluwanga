import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/image_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _supabase = Supabase.instance.client;
  final _contentController = TextEditingController();
  String _visibility = 'PUBLIC';
  bool _isSubmitting = false;
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _isAnonymous = false;

  final List<String> _visibilityOptions = [
    'PUBLIC',
    'FRIENDS',
    'PRIVATE',
  ];

  Future<void> _pickImage() async {
    final imageFile = await ImageService.pickImage(context);
    if (imageFile != null) {
      setState(() {
        _selectedImage = imageFile;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _uploadedImageUrl = null;
    });
  }

  Future<void> _createPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = _supabase.auth.currentUser!.id;

      if (_selectedImage != null) {
        _uploadedImageUrl = await ImageService.uploadImage(_selectedImage!, userId);
        if (_uploadedImageUrl == null) {
          throw Exception('Failed to upload image');
        }
      }

      final postResponse = await _supabase
          .from('posts')
          .insert({
        'user_id': userId,
        'author_id': userId,
        'content': content,
        'visibility': _visibility,
        'is_anonymous': _isAnonymous,
      })
          .select()
          .single();

      if (_uploadedImageUrl != null) {
        await _supabase.from('post_media').insert({
          'post_id': postResponse['id'],
          'media_url': _uploadedImageUrl,
          'media_type': 'IMAGE',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userRole = _supabase.auth.currentUser?.userMetadata?['role'];
    final isMentor = userRole == 'MENTOR';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: const Color(0xFF6A5AE0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share your thoughts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _contentController,
                      maxLines: 8,
                      decoration: InputDecoration(
                        hintText: 'What\'s on your mind?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedImage == null)
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Add Photo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6A5AE0),
                          side: const BorderSide(color: Color(0xFF6A5AE0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    else
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImage!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                onPressed: _removeImage,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Who can see this?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: _visibilityOptions.map((option) {
                        IconData icon;
                        switch (option) {
                          case 'PUBLIC':
                            icon = Icons.public;
                            break;
                          case 'FRIENDS':
                            icon = Icons.people;
                            break;
                          case 'PRIVATE':
                            icon = Icons.lock;
                            break;
                          default:
                            icon = Icons.public;
                        }
                        return ButtonSegment<String>(
                          value: option,
                          label: Text(option),
                          icon: Icon(icon),
                        );
                      }).toList(),
                      selected: {_visibility},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _visibility = newSelection.first;
                        });
                      },
                    ),
                    if (isMentor) ...[
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        value: _isAnonymous,
                        onChanged: (value) {
                          setState(() {
                            _isAnonymous = value ?? false;
                          });
                        },
                        title: const Text(
                          'Post anonymously',
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'Inter',
                          ),
                        ),
                        subtitle: const Text(
                          'Your name will be hidden from this post',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                        activeColor: const Color(0xFF6A5AE0),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _createPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A5AE0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                            : const Text(
                          'Post',
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
          ],
        ),
      ),
    );
  }
}
