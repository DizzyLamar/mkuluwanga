import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/top_app_bar.dart';

class MenteesScreen extends StatefulWidget {
  const MenteesScreen({super.key});

  @override
  State<MenteesScreen> createState() => _MenteesScreenState();
}

class _MenteesScreenState extends State<MenteesScreen> {
  late final Future<List<Map<String, dynamic>>> _mentorsFuture;

  @override
  void initState() {
    super.initState();
    _mentorsFuture = _getMentors();
  }

  Future<List<Map<String, dynamic>>> _getMentors() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      // This should not happen if AuthGate is working correctly
      throw 'User not logged in';
    }

    // 1. Get the current user's district
    final userProfileRes = await supabase
        .from('users')
        .select('district')
        .eq('id', currentUser.id)
        .single();
    final userDistrict = userProfileRes['district'];

    // 2. Fetch all mentors, excluding the current user if they are also a mentor
    final mentorsRes = await supabase
        .from('users')
        .select('id, full_name, district, profession')
        .eq('role', 'MENTOR')
        .neq('id', currentUser.id);

    final mentors = List<Map<String, dynamic>>.from(mentorsRes);

    // 3. Sort mentors: those in the same district first
    mentors.sort((a, b) {
      final isAInDistrict = a['district'] == userDistrict;
      final isBInDistrict = b['district'] == userDistrict;
      if (isAInDistrict && !isBInDistrict) {
        return -1; // a comes first
      }
      if (!isAInDistrict && isBInDistrict) {
        return 1; // b comes first
      }
      return 0; // no change in order
    });

    return mentors;
  }

  Future<void> _sendMentorshipRequest(String mentorId) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to send a request.'),
          ),
        );
      }
      return;
    }

    try {
      await supabase.from('mentorship_requests').insert({
        'mentee_id': currentUser.id,
        'mentor_id': mentorId,
        'status': 'PENDING',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mentorship request sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on PostgrestException catch (e) {
      // Handle specific errors, like duplicate requests
      if (e.code == '23505') {
        // unique_violation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already sent a request to this mentor.'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const TopAppBar(title: 'Find a Mentor'),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _mentorsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final mentors = snapshot.data;
          if (mentors == null || mentors.isEmpty) {
            return const Center(
              child: Text('No mentors available at the moment.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: mentors.length,
            itemBuilder: (context, index) {
              final mentor = mentors[index];
              final name = mentor['full_name'] ?? 'N/A';
              // Generate initials for placeholder avatar
              final initials = name.isNotEmpty
                  ? name.split(' ').map((e) => e[0]).take(2).join()
                  : '';

              return Card(
                elevation: 0.5,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        // Using a placeholder for image. You can add an 'avatar_url' to your DB
                        child: Text(
                          initials,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Expertise: ${mentor['profession'] ?? 'Not specified'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'District: ${mentor['district'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.person_add_alt_1_outlined,
                          color: Color(0xFF6A5AE0),
                        ),
                        tooltip: 'Send mentorship request',
                        onPressed: () {
                          _sendMentorshipRequest(mentor['id']);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
