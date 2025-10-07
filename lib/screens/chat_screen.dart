import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_main_bar.dart';
import 'anonymous_support_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _conversations = [];
  String? _activeConversationUserId;
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _messagesChannel;
  List<Map<String, dynamic>> _onlineUsers = [];
  final _sendAnonymously = false;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadPresence();
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
          'full_name': u != null ? u['full_name'] : null,
          'avatar_url': u != null ? u['avatar_url'] : null,
        };
      }).toList();
      if (mounted) {
        setState(() {
          _onlineUsers = List<Map<String, dynamic>>.from(users);
        });
      }
    } catch (_) {
      // ignore errors
    }
  }

  Future<void> _loadConversations() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    // Query recent messages involving the user and build a conversation list
    final res = await _supabase
        .from('messages')
        .select('sender_id, receiver_id, body, created_at')
        .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
        .order('created_at', ascending: false)
        .limit(200);

    final rows = List<Map<String, dynamic>>.from(res as List);
    final Map<String, Map<String, dynamic>> map = {};
    for (final r in rows) {
      final other = r['sender_id'] == user.id
          ? r['receiver_id']
          : r['sender_id'];
      if (!map.containsKey(other)) {
        map[other] = {
          'other_id': other,
          'last_message': r['body'],
          'last_ts': r['created_at'],
        };
      }
    }
    setState(() {
      _conversations = map.values.toList();
    });
  }

  Future<void> _openConversation(String otherUserId) async {
    setState(() {
      _activeConversationUserId = otherUserId;
      _messages = [];
    });
    await _loadMessages(otherUserId);
    _subscribeToMessages(otherUserId);
  }

  Future<void> _loadMessages(String otherUserId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final res = await _supabase
        .from('messages')
        .select()
        .or(
          'and(sender_id.eq.${user.id},receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.${user.id})',
        )
        .order('created_at', ascending: true);
    setState(() {
      _messages = List<Map<String, dynamic>>.from(res as List);
    });
  }

  void _subscribeToMessages(String otherUserId) {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    // Unsubscribe previous
    if (_messagesChannel != null) {
      _supabase.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
    final channel = _supabase.channel('messages:${user.id}');
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
            // If message pertains to the active conversation, append
            final newRecord = payload.newRecord;
            final senderId = newRecord['sender_id'];
            if (senderId == otherUserId) {
              setState(() {
                _messages.add(Map<String, dynamic>.from(newRecord));
              });
            }
            // Also refresh conversations list quickly
            _loadConversations();
          },
        )
        .subscribe();
    _messagesChannel = channel;
  }

  Future<void> _sendMessage() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _activeConversationUserId == null) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final payload = {
      'sender_id': user.id,
      'receiver_id': _activeConversationUserId,
      'is_anonymous': _sendAnonymously,
      'body': text,
    };

    // Optimistic append
    setState(() {
      _messages.add({
        ...payload,
        'created_at': DateTime.now().toIso8601String(),
      });
      _textController.clear();
    });

    try {
      await _supabase.from('messages').insert(payload);
      _loadConversations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Send failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
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
      body: Row(
        children: [
          SizedBox(
            width: 300,
            child: Column(
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
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Chats',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_onlineUsers.isNotEmpty)
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _onlineUsers.length,
                      itemBuilder: (context, index) {
                        final u = _onlineUsers[index];
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                child: Text(
                                  (u['full_name'] ?? 'U').toString().isNotEmpty
                                      ? (u['full_name'] ?? 'U').toString()[0]
                                      : 'U',
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  (u['full_name'] ?? ''),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final c = _conversations[index];
                      return ListTile(
                        title: Text(
                          c['full_name'] ?? c['other_id'] ?? 'Unknown',
                        ),
                        subtitle: Text(c['last_message'] ?? ''),
                        onTap: () => _openConversation(c['other_id']),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _activeConversationUserId == null
                ? const Center(child: Text('Select a conversation'))
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final m = _messages[index];
                            final user = _supabase.auth.currentUser;
                            final isMe =
                                user != null && m['sender_id'] == user.id;
                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.blue[100]
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(m['body'] ?? ''),
                              ),
                            );
                          },
                        ),
                      ),
                      SafeArea(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                decoration: const InputDecoration(
                                  hintText: 'Type a message',
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _sendMessage,
                              icon: const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
