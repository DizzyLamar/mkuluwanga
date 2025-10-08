import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_main_bar.dart';
import 'messages_screen.dart';
import 'anonymous_support_screen.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() =>
      _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _onlineUsers = [];
  bool _loading = true;
  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadPresence();
    _subscribeToMessages();
  }

  Future<void> _loadPresence() async {
    try {
      final res = await _supabase
          .from('user_presence')
          .select('user_id,is_online,last_seen,users(full_name,avatar_url)')
          .eq('is_online', true)
          .limit(50);
      final rows = List<Map<String, dynamic>>.from(res as List);
      final users = rows.map((r) {
        final u = r['users'] as Map<String, dynamic>?;
        return {
          'id': r['user_id'],
          'full_name': u?['full_name'],
          'avatar_url': u?['avatar_url'],
        };
      }).toList();
      if (mounted) {
        setState(() {
          _onlineUsers = users;
        });
      }
    } catch (_) {
      // ignore errors
    }
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Get all messages involving the current user
      final res = await _supabase
          .from('messages')
          .select('sender_id, receiver_id, body, created_at, is_read')
          .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
          .order('created_at', ascending: false)
          .limit(200);

      final rows = List<Map<String, dynamic>>.from(res as List);

      final Map<String, Map<String, dynamic>> conversationMap = {};
      for (final r in rows) {
        final otherId = r['sender_id'] == user.id
            ? r['receiver_id']
            : r['sender_id'];

        if (!conversationMap.containsKey(otherId)) {
          conversationMap[otherId] = {
            'other_id': otherId,
            'last_message': r['body'],
            'last_ts': r['created_at'],
            'unread_count': 0,
          };
        }

        // Count unread messages from the other user
        if (r['receiver_id'] == user.id && r['is_read'] == false) {
          conversationMap[otherId]!['unread_count'] =
              (conversationMap[otherId]!['unread_count'] as int) + 1;
        }
      }

      // Fetch user details for all conversation participants
      if (conversationMap.isNotEmpty) {
        final userIds = conversationMap.keys.toList();
        final usersRes = await _supabase
            .from('users')
            .select('id, full_name, avatar_url, role, profession')
            .inFilter('id', userIds);

        final users = List<Map<String, dynamic>>.from(usersRes as List);

        final presenceRes = await _supabase
            .from('user_presence')
            .select('user_id, is_online')
            .inFilter('user_id', userIds);

        final presenceList = List<Map<String, dynamic>>.from(presenceRes as List);
        final presenceMap = {
          for (var p in presenceList) p['user_id']: p['is_online'] == true
        };

        // Merge user details into conversations
        for (final userInfo in users) {
          final userId = userInfo['id'];
          if (conversationMap.containsKey(userId)) {
            conversationMap[userId]!['full_name'] = userInfo['full_name'];
            conversationMap[userId]!['avatar_url'] = userInfo['avatar_url'];
            conversationMap[userId]!['role'] = userInfo['role'];
            conversationMap[userId]!['profession'] = userInfo['profession'];
            conversationMap[userId]!['is_online'] = presenceMap[userId] ?? false;
          }
        }
      }

      setState(() {
        _conversations = conversationMap.values.toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading conversations: $e')),
        );
      }
    }
  }

  void _subscribeToMessages() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final channel = _supabase.channel('conversations:${user.id}');
    channel
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'receiver_id',
        value: user.id,
      ),
      callback: (payload) {
        _loadConversations();
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        _loadConversations();
      },
    )
        .subscribe();
    _messagesChannel = channel;
  }

  @override
  void dispose() {
    if (_messagesChannel != null) {
      _supabase.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppMainBar(title: 'Chats'),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnonymousSupportScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.shield, size: 18),
              label: const Text('Anonymous Support'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A5AE0),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
          if (_onlineUsers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Online Now',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _onlineUsers.length,
                      itemBuilder: (context, index) {
                        final u = _onlineUsers[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MessagesScreen(
                                    otherUserId: u['id'],
                                  ),
                                ),
                              ).then((_) => _loadConversations());
                            },
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundImage: u['avatar_url'] != null
                                          ? NetworkImage(u['avatar_url'])
                                          : null,
                                      child: u['avatar_url'] == null
                                          ? Text(
                                        (u['full_name'] ?? 'U')
                                            .toString()
                                            .substring(0, 1)
                                            .toUpperCase(),
                                      )
                                          : null,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
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
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    u['full_name'] ?? 'User',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _conversations.isEmpty
                ? const Center(
              child: Text(
                'No conversations yet.\nStart chatting with mentors or friends!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final c = _conversations[index];
                final fullName = c['full_name'] ?? 'Unknown User';
                final avatarUrl = c['avatar_url'];
                final lastMessage = c['last_message'] ?? '';
                final unreadCount = c['unread_count'] as int? ?? 0;
                final isOnline = c['is_online'] == true;

                return ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(
                          fullName.substring(0, 1).toUpperCase(),
                        )
                            : null,
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
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
                  title: Text(
                    fullName,
                    style: TextStyle(
                      fontWeight: unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unreadCount > 0
                          ? Colors.black87
                          : Colors.grey,
                      fontWeight: unreadCount > 0
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6A5AE0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MessagesScreen(
                          otherUserId: c['other_id'],
                        ),
                      ),
                    ).then((_) => _loadConversations());
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
