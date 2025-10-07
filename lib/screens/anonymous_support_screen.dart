import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'anonymous_chat_screen.dart';

class AnonymousSupportScreen extends StatefulWidget {
  const AnonymousSupportScreen({super.key});

  @override
  State<AnonymousSupportScreen> createState() => _AnonymousSupportScreenState();
}

class _AnonymousSupportScreenState extends State<AnonymousSupportScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _availableSupportersFuture;
  late Future<List<Map<String, dynamic>>> _activeAnonymousChatsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _availableSupportersFuture = _fetchAvailableSupporters();
    _activeAnonymousChatsFuture = _fetchActiveAnonymousChats();
  }

  Future<List<Map<String, dynamic>>> _fetchAvailableSupporters() async {
    try {
      // Fetch mentors who are currently online
      final response = await _supabase
          .from('user_presence')
          .select('user_id, users!inner(id, full_name, role, bio, profession)')
          .eq('is_online', true)
          .eq('users.role', 'MENTOR')
          .limit(20);

      final rows = List<Map<String, dynamic>>.from(response as List);
      return rows.map((row) {
        final user = row['users'] as Map<String, dynamic>;
        return {
          'id': user['id'],
          'full_name': user['full_name'],
          'bio': user['bio'],
          'profession': user['profession'],
        };
      }).toList();
    } catch (e) {
      print('[v0] Error fetching supporters: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchActiveAnonymousChats() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // Fetch recent anonymous messages
      final response = await _supabase
          .from('messages')
          .select('sender_id, receiver_id, body, created_at, is_anonymous')
          .eq('is_anonymous', true)
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(50);

      final rows = List<Map<String, dynamic>>.from(response as List);
      
      // Group by conversation partner
      final Map<String, Map<String, dynamic>> conversations = {};
      for (final msg in rows) {
        final otherId = msg['sender_id'] == userId 
            ? msg['receiver_id'] 
            : msg['sender_id'];
        
        if (!conversations.containsKey(otherId)) {
          conversations[otherId] = {
            'other_id': otherId,
            'last_message': msg['body'],
            'last_timestamp': msg['created_at'],
            'is_anonymous': true,
          };
        }
      }

      return conversations.values.toList();
    } catch (e) {
      print('[v0] Error fetching anonymous chats: $e');
      return [];
    }
  }

  void _startAnonymousChat(String supporterId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnonymousChatScreen(
          otherUserId: supporterId,
        ),
      ),
    ).then((_) => setState(() => _loadData()));
  }

  void _openAnonymousChat(String otherId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnonymousChatScreen(
          otherUserId: otherId,
        ),
      ),
    ).then((_) => setState(() => _loadData()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anonymous Support'),
        backgroundColor: const Color(0xFF6A5AE0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _loadData());
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info card
            Card(
              color: const Color(0xFFF0EDFF),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A5AE0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.shield,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Privacy Matters',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Chat anonymously with trained supporters. Your identity stays private.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6A5AE0),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Active anonymous chats
            const Text(
              'Your Anonymous Conversations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _activeAnonymousChatsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final chats = snapshot.data ?? [];
                if (chats.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No active anonymous chats',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: chats.map((chat) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          child: const Icon(
                            Icons.person_off,
                            color: Colors.grey,
                          ),
                        ),
                        title: const Text(
                          'Anonymous Conversation',
                          style: TextStyle(fontFamily: 'Inter'),
                        ),
                        subtitle: Text(
                          chat['last_message'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Inter'),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openAnonymousChat(chat['other_id']),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            
            // Available supporters
            const Text(
              'Available Supporters',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _availableSupportersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final supporters = snapshot.data ?? [];
                if (supporters.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No supporters online right now',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Check back later',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: supporters.map((supporter) {
                    final name = supporter['full_name'] ?? 'Supporter';
                    final bio = supporter['bio'] ?? '';
                    final profession = supporter['profession'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1,
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
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: const Color(0xFF6A5AE0),
                                      child: Text(
                                        name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      if (profession.isNotEmpty)
                                        Text(
                                          profession,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
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
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _startAnonymousChat(supporter['id']),
                                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                label: const Text('Start Anonymous Chat'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6A5AE0),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
