import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_main_bar.dart';

class MentorDashboardScreen extends StatefulWidget {
  const MentorDashboardScreen({super.key});

  @override
  State<MentorDashboardScreen> createState() => _MentorDashboardScreenState();
}

class _MentorDashboardScreenState extends State<MentorDashboardScreen> {
  late final Future<List<dynamic>> _requestsFuture;
  late Future<List<Map<String, dynamic>>> _activeMenteesFuture;
  late Future<Map<String, dynamic>> _analyticsFuture;
  final _supabase = Supabase.instance.client;

  // Resource creation form controllers
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  final _coverImageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _requestsFuture = _fetchRequests();
    _activeMenteesFuture = _fetchActiveMentees();
    _analyticsFuture = _fetchAnalytics();
  }

  Future<List<dynamic>> _fetchRequests() async {
    final mentorId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('mentorship_requests')
        .select('*, mentee:users!mentee_id(*)')
        .eq('mentor_id', mentorId)
        .eq('status', 'PENDING');
    return response;
  }

  Future<List<Map<String, dynamic>>> _fetchActiveMentees() async {
    final mentorId = _supabase.auth.currentUser!.id;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final mentees = await _supabase
        .from('mentorships')
        .select('mentee:users(*), presence:user_presence(last_seen)')
        .eq('mentor_id', mentorId);
    // Filter mentees active in last 7 days
    return List<Map<String, dynamic>>.from(mentees).where((m) {
      final lastSeen = m['presence']?['last_seen'];
      if (lastSeen == null) return false;
      return DateTime.parse(lastSeen).isAfter(DateTime.parse(sevenDaysAgo));
    }).toList();
  }

  Future<Map<String, dynamic>> _fetchAnalytics() async {
    try {
      final mentorId = _supabase.auth.currentUser!.id;

      // Get total mentees
      final menteesResponse = await _supabase
          .from('mentorships')
          .select('id')
          .eq('mentor_id', mentorId);
      final totalMentees = (menteesResponse as List).length;

      // Get active mentees (last 7 days)
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final activeMenteesResponse = await _supabase
          .from('mentorships')
          .select('mentee_id')
          .eq('mentor_id', mentorId);

      final menteeIds = (activeMenteesResponse as List)
          .map((m) => m['mentee_id'] as String)
          .toList();

      int activeMentees = 0;
      if (menteeIds.isNotEmpty) {
        final presenceResponse = await _supabase
            .from('user_presence')
            .select('user_id, last_seen')
            .inFilter('user_id', menteeIds)
            .gte('last_seen', sevenDaysAgo);
        activeMentees = (presenceResponse as List).length;
      }

      // Get pending requests
      final pendingRequestsResponse = await _supabase
          .from('mentorship_requests')
          .select('id')
          .eq('mentor_id', mentorId)
          .eq('status', 'PENDING');
      final pendingRequests = (pendingRequestsResponse as List).length;

      // Get total messages sent by mentor
      final messagesSentResponse = await _supabase
          .from('messages')
          .select('id')
          .eq('sender_id', mentorId);
      final messagesSent = (messagesSentResponse as List).length;

      // Get posts created
      final postsResponse = await _supabase
          .from('posts')
          .select('id')
          .eq('author_id', mentorId);
      final totalPosts = (postsResponse as List).length;

      // Get resources created
      final resourcesResponse = await _supabase
          .from('resources')
          .select('id')
          .eq('author_id', mentorId);
      final totalResources = (resourcesResponse as List).length;

      // Calculate average response time (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentMessages = await _supabase
          .from('messages')
          .select('created_at, receiver_id')
          .eq('sender_id', mentorId)
          .gte('created_at', thirtyDaysAgo.toIso8601String())
          .order('created_at', ascending: true);

      double avgResponseTime = 0;
      if (recentMessages.isNotEmpty) {
        final messages = List<Map<String, dynamic>>.from(recentMessages as List);
        final receiverIds = messages.map((m) => m['receiver_id']).toSet();

        int totalResponseTimes = 0;
        int responseCount = 0;

        for (final receiverId in receiverIds) {
          final convMessages = messages.where((m) => m['receiver_id'] == receiverId).toList();
          for (int i = 1; i < convMessages.length; i++) {
            final prevTime = DateTime.parse(convMessages[i - 1]['created_at']);
            final currTime = DateTime.parse(convMessages[i]['created_at']);
            final diff = currTime.difference(prevTime).inMinutes;
            if (diff < 1440) {
              totalResponseTimes += diff;
              responseCount++;
            }
          }
        }

        if (responseCount > 0) {
          avgResponseTime = totalResponseTimes / responseCount;
        }
      }

      // Get activity trend (last 7 days)
      final activityTrend = <Map<String, dynamic>>[];
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final dayMessages = await _supabase
            .from('messages')
            .select('id')
            .eq('sender_id', mentorId)
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String());

        activityTrend.add({
          'date': '${date.month}/${date.day}',
          'count': (dayMessages as List).length,
        });
      }

      // Calculate impact score (simplified without support_responses)
      final impactScore = (messagesSent * 2) +
          (totalResources * 10) +
          (totalPosts * 3) +
          (totalMentees * 15);

      return {
        'totalMentees': totalMentees,
        'activeMentees': activeMentees,
        'pendingRequests': pendingRequests,
        'messagesSent': messagesSent,
        'totalPosts': totalPosts,
        'totalResources': totalResources,
        'avgResponseTime': avgResponseTime,
        'activityTrend': activityTrend,
        'impactScore': impactScore,
      };
    } catch (e) {
      print('[v0] Error fetching analytics: $e');
      return {
        'totalMentees': 0,
        'activeMentees': 0,
        'pendingRequests': 0,
        'messagesSent': 0,
        'totalPosts': 0,
        'totalResources': 0,
        'avgResponseTime': 0.0,
        'activityTrend': [],
        'impactScore': 0,
      };
    }
  }

  Future<void> _handleRequest(String requestId, String newStatus) async {
    try {
      // Update the request status
      await _supabase
          .from('mentorship_requests')
          .update({'status': newStatus})
          .eq('id', requestId);

      // Get request details for notification and mentorship creation
      final request = await _supabase
          .from('mentorship_requests')
          .select()
          .eq('id', requestId)
          .single();

      final menteeId = request['mentee_id'];
      final mentorId = _supabase.auth.currentUser!.id;

      // If accepted, create mentorship entry
      if (newStatus == 'ACCEPTED') {
        await _supabase.from('mentorships').insert({
          'mentor_id': mentorId,
          'mentee_id': menteeId,
        });

        try {
          final mentorName = (await _supabase
              .from('users')
              .select('full_name')
              .eq('id', mentorId)
              .single())['full_name'];

          await _supabase.from('messages').insert({
            'sender_id': mentorId,
            'receiver_id': menteeId,
            'body': 'Hi! I\'m excited to be your mentor. Feel free to reach out anytime you need guidance or support. 😊',
          });
        } catch (e) {
          // Ignore message creation errors, mentorship is still created
          print('[v0] Error creating welcome message: $e');
        }
      }

      // Get mentor name for notification
      final mentorName = (await _supabase
          .from('users')
          .select('full_name')
          .eq('id', mentorId)
          .single())['full_name'];

      // Create notification for the mentee
      await _supabase.from('notifications').insert({
        'user_id': menteeId,
        'message':
        'Your mentorship request with $mentorName has been $newStatus.',
      });

      setState(() {
        _requestsFuture = _fetchRequests();
        _analyticsFuture = _fetchAnalytics();
        _activeMenteesFuture = _fetchActiveMentees();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing request: $e')),
        );
      }
    }
  }

  Future<void> _createResource() async {
    setState(() { _isSubmitting = true; });
    final authorId = _supabase.auth.currentUser!.id;
    await _supabase.from('resources').insert({
      'title': _titleController.text.trim(),
      'summary': _summaryController.text.trim(),
      'content': _contentController.text.trim(),
      'cover_image_url': _coverImageController.text.trim(),
      'author_id': authorId,
    });
    setState(() {
      _isSubmitting = false;
      _analyticsFuture = _fetchAnalytics();
    });
    _titleController.clear();
    _summaryController.clear();
    _contentController.clear();
    _coverImageController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resource published!')));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      appBar: const AppMainBar(title: 'Mentor Dashboard'),
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _analyticsFuture = _fetchAnalytics();
            _activeMenteesFuture = _fetchActiveMentees();
            _requestsFuture = _fetchRequests();
          });
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              FutureBuilder<Map<String, dynamic>>(
                future: _analyticsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final analytics = snapshot.data ?? {};
                  final totalMentees = analytics['totalMentees'] ?? 0;
                  final activeMentees = analytics['activeMentees'] ?? 0;
                  final pendingRequests = analytics['pendingRequests'] ?? 0;
                  final messagesSent = analytics['messagesSent'] ?? 0;
                  final totalPosts = analytics['totalPosts'] ?? 0;
                  final totalResources = analytics['totalResources'] ?? 0;
                  final avgResponseTime = analytics['avgResponseTime'] ?? 0.0;
                  final impactScore = analytics['impactScore'] ?? 0;
                  final activityTrend = analytics['activityTrend'] ?? [];

                  return Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Impact Score Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6A5AE0), Color(0xFF8B7AFF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Impact Score',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Your mentorship impact',
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 13,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        //color: Colors.white.withValues(255,255,255,0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.trending_up,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  impactScore.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Key Metrics Grid
                        GridView.count(
                          crossAxisCount: isSmallScreen ? 2 : 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: isSmallScreen ? 10 : 12,
                          crossAxisSpacing: isSmallScreen ? 10 : 12,
                          childAspectRatio: isSmallScreen ? 1.4 : 1.5,
                          children: [
                            _buildMetricCard(
                              'Total Mentees',
                              totalMentees.toString(),
                              Icons.people,
                              Colors.blue,
                              isSmallScreen,
                            ),
                            _buildMetricCard(
                              'Active Mentees',
                              activeMentees.toString(),
                              Icons.person_outline,
                              Colors.green,
                              isSmallScreen,
                            ),
                            _buildMetricCard(
                              'Pending Requests',
                              pendingRequests.toString(),
                              Icons.pending_actions,
                              Colors.orange,
                              isSmallScreen,
                            ),
                            _buildMetricCard(
                              'Messages Sent',
                              messagesSent.toString(),
                              Icons.message,
                              Colors.purple,
                              isSmallScreen,
                            ),
                            _buildMetricCard(
                              'Posts Created',
                              totalPosts.toString(),
                              Icons.article,
                              Colors.teal,
                              isSmallScreen,
                            ),
                            _buildMetricCard(
                              'Resources Shared',
                              totalResources.toString(),
                              Icons.library_books,
                              Colors.indigo,
                              isSmallScreen,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Response Time Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.teal[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.timer,
                                    color: Colors.teal[700],
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Avg Response Time',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        avgResponseTime < 60
                                            ? '${avgResponseTime.toStringAsFixed(0)} min'
                                            : '${(avgResponseTime / 60).toStringAsFixed(1)} hrs',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  avgResponseTime < 60
                                      ? Icons.flash_on
                                      : Icons.schedule,
                                  color: avgResponseTime < 60
                                      ? Colors.green
                                      : Colors.orange,
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Activity Trend
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Activity Trend (Last 7 Days)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (activityTrend.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'No activity data yet',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    height: 120,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: activityTrend.map<Widget>((day) {
                                        final count = day['count'] as int;
                                        final maxCount = activityTrend
                                            .map((d) => d['count'] as int)
                                            .reduce((a, b) => a > b ? a : b);
                                        final height = maxCount > 0
                                            ? (count / maxCount) * 80 + 20
                                            : 20.0;

                                        return Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Text(
                                              count.toString(),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              width: 32,
                                              height: height,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6A5AE0),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              day['date'],
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('New Mentorship Requests'),
                    const SizedBox(height: 16),
                    FutureBuilder<List<dynamic>>(
                      future: _requestsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        final requests = snapshot.data!;
                        if (requests.isEmpty) {
                          return const Center(
                            child: Text('No new mentorship requests.'),
                          );
                        }
                        return Column(
                          children: requests
                              .map((request) => _buildRequestCard(request: request))
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Active Mentees (Last 7 Days)'),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _activeMenteesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const Center(child: Text('Error loading mentee activity'));
                        }
                        final mentees = snapshot.data ?? [];
                        if (mentees.isEmpty) {
                          return const Center(child: Text('No active mentees in the last 7 days.'));
                        }
                        return Column(
                          children: mentees.map((mentee) {
                            final user = mentee['mentee'] ?? {};
                            final lastSeen = mentee['presence']?['last_seen'];
                            return Column(
                              children: [
                                _buildMenteeActivityTile(
                                  name: user['full_name'] ?? '',
                                  lastSession: lastSeen != null ? lastSeen.substring(0, 10) : 'N/A',
                                  imageUrl: 'https://placehold.co/100x100/E6F7FF/1890FF?text=${user['full_name']?[0] ?? 'M'}',
                                ),
                                const Divider(height: 24, thickness: 1),
                              ],
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, bool isSmallScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Colors.grey[600],
                      fontFamily: 'Inter',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 24 : 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        fontFamily: 'Inter',
      ),
    );
  }

  Widget _buildRequestCard({required Map<String, dynamic> request}) {
    final mentee = request['mentee'] as Map<String, dynamic>;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(
                    'https://placehold.co/100x100/FFF0E5/FF9966?text=${mentee['full_name'][0]}',
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mentee['full_name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request['created_at'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleRequest(request['id'], 'ACCEPTED'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A5AE0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => _handleRequest(request['id'], 'REJECTED'),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenteeActivityTile({
    required String name,
    required String lastSession,
    required String imageUrl,
  }) {
    return Row(
      children: [
        CircleAvatar(radius: 28, backgroundImage: NetworkImage(imageUrl)),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Last session: $lastSession',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
