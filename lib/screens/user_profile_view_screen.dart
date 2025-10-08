import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'messages_screen.dart';

class UserProfileViewScreen extends StatefulWidget {
  final String userId;
  const UserProfileViewScreen({super.key, required this.userId});

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  List<String> _interests = [];
  bool _loading = true;
  String? _relationshipStatus;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadInterests();
    _checkRelationship();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('users')
          .select()
          .eq('id', widget.userId)
          .maybeSingle();

      if (res != null) {
        setState(() {
          _profile = Map<String, dynamic>.from(res as Map);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadInterests() async {
    try {
      final res = await _supabase
          .from('user_interests')
          .select('interest')
          .eq('user_id', widget.userId);

      final rows = List<Map<String, dynamic>>.from(res as List);
      setState(() {
        _interests = rows.map((r) => r['interest'] as String).toList();
      });
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _checkRelationship() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Check friendship status
      final friendshipRes = await _supabase
          .from('friendships')
          .select('status')
          .or(
        'and(requester_id.eq.${currentUser.id},addressee_id.eq.${widget.userId}),and(requester_id.eq.${widget.userId},addressee_id.eq.${currentUser.id})',
      )
          .maybeSingle();

      if (friendshipRes != null) {
        setState(() {
          _relationshipStatus = 'friend_${friendshipRes['status']}';
        });
        return;
      }

      // Check mentorship status
      final mentorshipRes = await _supabase
          .from('mentorships')
          .select()
          .or(
        'and(mentor_id.eq.${currentUser.id},mentee_id.eq.${widget.userId}),and(mentor_id.eq.${widget.userId},mentee_id.eq.${currentUser.id})',
      )
          .maybeSingle();

      if (mentorshipRes != null) {
        setState(() {
          _relationshipStatus = 'mentorship';
        });
        return;
      }

      setState(() {
        _relationshipStatus = 'none';
      });
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _sendFriendRequest() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      await _supabase.from('friendships').insert({
        'requester_id': currentUser.id,
        'addressee_id': widget.userId,
        'status': 'PENDING',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
        _checkRelationship();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _sendMentorshipRequest() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      await _supabase.from('mentorship_requests').insert({
        'mentee_id': currentUser.id,
        'mentor_id': widget.userId,
        'status': 'PENDING',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mentorship request sent!')),
        );
        _checkRelationship();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final avatar = _profile!['avatar_url'] as String?;
    final bio = _profile!['bio'] as String?;
    final role = _profile!['role'] as String?;
    final isMentor = role == 'MENTOR';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => MessagesScreen(
                    otherUserId: widget.userId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundImage: avatar != null
                          ? NetworkImage(avatar)
                          : null,
                      child: avatar == null
                          ? const Icon(Icons.person, size: 56)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _profile!['full_name'] ?? 'Unnamed',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (_profile!['profession'] != null)
                      Text(
                        _profile!['profession'],
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Chip(
                          label: Text(role ?? ''),
                          backgroundColor: isMentor
                              ? const Color(0xFF6A5AE0).withOpacity(0.1)
                              : Colors.blue.withOpacity(0.1),
                        ),
                        if (_profile!['district'] != null) ...[
                          const SizedBox(width: 8),
                          Chip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, size: 14),
                                const SizedBox(width: 4),
                                Text(_profile!['district']),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (bio != null && bio.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        bio,
                        style: const TextStyle(fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Interests Card
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _interests.map((interest) {
                          return Chip(
                            label: Text(interest),
                            backgroundColor: Colors.grey[100],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Contact Information Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    if (_profile!['email'] != null)
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: const Text('Email'),
                        subtitle: Text(_profile!['email']),
                      ),
                    if (_profile!['phone_number'] != null)
                      ListTile(
                        leading: const Icon(Icons.phone),
                        title: const Text('Phone'),
                        subtitle: Text(_profile!['phone_number']),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (_relationshipStatus == 'none') ...[
              if (isMentor)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sendMentorshipRequest,
                    icon: const Icon(Icons.school),
                    label: const Text('Request Mentorship'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A5AE0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _sendFriendRequest,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Send Friend Request'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ] else if (_relationshipStatus == 'friend_PENDING') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Friend request pending',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_relationshipStatus == 'friend_ACCEPTED') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You are friends',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_relationshipStatus == 'mentorship') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A5AE0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.school, color: Color(0xFF6A5AE0)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Mentorship active',
                        style: TextStyle(color: Color(0xFF6A5AE0)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
