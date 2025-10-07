import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InterestMatchingScreen extends StatefulWidget {
  const InterestMatchingScreen({super.key});

  @override
  State<InterestMatchingScreen> createState() => _InterestMatchingScreenState();
}

class _InterestMatchingScreenState extends State<InterestMatchingScreen> {
  final _supabase = Supabase.instance.client;
  List<String> _myInterests = [];
  List<Map<String, dynamic>> _recommendedMentors = [];
  List<String> _availableInterests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadAvailableInterests(),
      _loadMyInterests(),
    ]);
    await _loadRecommendedMentors();
    setState(() => _isLoading = false);
  }

  Future<void> _loadAvailableInterests() async {
    try {
      final response = await _supabase
          .from('interests')
          .select('name')
          .order('name');

      final rows = List<Map<String, dynamic>>.from(response as List);
      if (mounted) {
        setState(() {
          _availableInterests = rows.map((r) => r['name'] as String).toList();
        });
      }
    } catch (e) {
      print('[v0] Error loading available interests: $e');
      setState(() {
        _availableInterests = [
          'Anxiety',
          'Depression',
          'Stress Management',
          'Relationships',
          'Career',
          'Self-Esteem',
          'Grief',
          'Trauma',
          'Addiction',
          'Sleep Issues',
          'Eating Disorders',
          'LGBTQ+ Support',
          'Family Issues',
          'Anger Management',
          'Social Anxiety',
          'Mindfulness',
          'Life Transitions',
          'Academic Pressure',
        ];
      });
    }
  }

  Future<void> _loadMyInterests() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('user_interests')
          .select('interest')
          .eq('user_id', userId);

      final rows = List<Map<String, dynamic>>.from(response as List);
      if (mounted) {
        setState(() {
          _myInterests = rows.map((r) => r['interest'] as String).toList();
        });
      }
    } catch (e) {
      print('[v0] Error loading interests: $e');
    }
  }

  Future<void> _loadRecommendedMentors() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get all mentors with their interests
      final response = await _supabase
          .from('users')
          .select('id, full_name, bio, profession')
          .eq('role', 'MENTOR')
          .limit(50);

      final mentors = List<Map<String, dynamic>>.from(response as List);

      // For each mentor, get their interests and calculate match score
      final mentorsWithScores = <Map<String, dynamic>>[];

      for (final mentor in mentors) {
        final interestsResponse = await _supabase
            .from('user_interests')
            .select('interest')
            .eq('user_id', mentor['id']);

        final interests = List<Map<String, dynamic>>.from(interestsResponse as List);
        final mentorInterests = interests.map((i) => i['interest'] as String).toList();

        // Calculate match score (number of shared interests)
        final matchScore = _myInterests
            .where((interest) => mentorInterests.contains(interest))
            .length;

        if (matchScore > 0) {
          mentorsWithScores.add({
            ...mentor,
            'match_score': matchScore,
            'shared_interests': _myInterests
                .where((interest) => mentorInterests.contains(interest))
                .toList(),
          });
        }
      }

      // Sort by match score
      mentorsWithScores.sort((a, b) => 
        (b['match_score'] as int).compareTo(a['match_score'] as int));

      if (mounted) {
        setState(() {
          _recommendedMentors = mentorsWithScores;
        });
      }
    } catch (e) {
      print('[v0] Error loading mentors: $e');
    }
  }

  Future<void> _toggleInterest(String interest) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (_myInterests.contains(interest)) {
        // Remove interest
        await _supabase
            .from('user_interests')
            .delete()
            .eq('user_id', userId)
            .eq('interest', interest);
        
        setState(() {
          _myInterests.remove(interest);
        });
      } else {
        // Add interest
        await _supabase.from('user_interests').insert({
          'user_id': userId,
          'interest': interest,
        });
        
        setState(() {
          _myInterests.add(interest);
        });
      }

      // Reload recommendations
      _loadRecommendedMentors();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  void _showInterestSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Your Interests',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _availableInterests.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: _availableInterests.map((interest) {
                        final isSelected = _myInterests.contains(interest);
                        return CheckboxListTile(
                          title: Text(
                            interest,
                            style: const TextStyle(fontFamily: 'Inter'),
                          ),
                          value: isSelected,
                          onChanged: (_) {
                            _toggleInterest(interest);
                            Navigator.pop(context);
                          },
                          activeColor: const Color(0xFF6A5AE0),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Your Match'),
        backgroundColor: const Color(0xFF6A5AE0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // My interests section
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Your Interests',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _showInterestSelector,
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Edit'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_myInterests.isEmpty)
                            Text(
                              'Add interests to find matching mentors',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontFamily: 'Inter',
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _myInterests.map((interest) {
                                return Chip(
                                  label: Text(interest),
                                  backgroundColor: const Color(0xFFF0EDFF),
                                  labelStyle: const TextStyle(
                                    color: Color(0xFF6A5AE0),
                                    fontFamily: 'Inter',
                                  ),
                                  deleteIcon: const Icon(
                                    Icons.close,
                                    size: 18,
                                  ),
                                  onDeleted: () => _toggleInterest(interest),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Recommended mentors
                  const Text(
                    'Recommended Mentors',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  if (_myInterests.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.interests_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Add your interests first',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 4),
                            ElevatedButton(
                              onPressed: _showInterestSelector,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6A5AE0),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Select Interests'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_recommendedMentors.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No matching mentors found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try adding more interests',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._recommendedMentors.map((mentor) {
                      final name = mentor['full_name'] ?? 'Mentor';
                      final bio = mentor['bio'] ?? '';
                      final profession = mentor['profession'] ?? '';
                      final matchScore = mentor['match_score'] as int;
                      final sharedInterests = 
                          List<String>.from(mentor['shared_interests'] as List);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: const Color(0xFF6A5AE0),
                                    child: Text(
                                      name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
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
                                        if (profession.isNotEmpty)
                                          Text(
                                            profession,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.green[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$matchScore match${matchScore > 1 ? 'es' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (bio.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  bio,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontFamily: 'Inter',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 12),
                              const Text(
                                'Shared interests:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: sharedInterests.map((interest) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0EDFF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      interest,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6A5AE0),
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    // Navigate to mentor profile or start chat
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Connect with $name'),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6A5AE0),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text('Connect'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
      ),
    );
  }
}
