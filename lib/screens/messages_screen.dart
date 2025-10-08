import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_view_screen.dart';

class MessagesScreen extends StatefulWidget {
  final String otherUserId;
  const MessagesScreen({super.key, required this.otherUserId});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _otherUser;
  bool _isOnline = false;
  RealtimeChannel? _channel;
  RealtimeChannel? _presenceChannel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOtherUser();
    _loadMessages();
    _markMessagesAsRead();
    _subscribe();
    _subscribeToPresence();
  }

  Future<void> _loadOtherUser() async {
    try {
      final res = await _supabase
          .from('users')
          .select('id, full_name, avatar_url, role, profession, district')
          .eq('id', widget.otherUserId)
          .maybeSingle();

      if (res != null) {
        setState(() {
          _otherUser = Map<String, dynamic>.from(res as Map);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user: $e')),
        );
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('receiver_id', user.id)
          .eq('sender_id', widget.otherUserId)
          .eq('is_read', false);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final res = await _supabase
          .from('messages')
          .select()
          .or(
        'and(sender_id.eq.${user.id},receiver_id.eq.${widget.otherUserId}),and(sender_id.eq.${widget.otherUserId},receiver_id.eq.${user.id})',
      )
          .order('created_at', ascending: true);
      setState(() {
        _messages = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });

      // Scroll to bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });

      _markMessagesAsRead();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    }
  }

  void _subscribeToPresence() {
    final presenceChannel = _supabase.channel('presence:${widget.otherUserId}');
    presenceChannel
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'user_presence',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: widget.otherUserId,
      ),
      callback: (payload) {
        final newRecord = payload.newRecord;
        if (newRecord != null && mounted) {
          setState(() {
            _isOnline = newRecord['is_online'] == true;
          });
        }
      },
    )
        .subscribe();
    _presenceChannel = presenceChannel;

    // Load initial presence
    _loadPresence();
  }

  Future<void> _loadPresence() async {
    try {
      final res = await _supabase
          .from('user_presence')
          .select('is_online')
          .eq('user_id', widget.otherUserId)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _isOnline = res['is_online'] == true;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  void _subscribe() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final channel = _supabase.channel(
      'messages:${user.id}:${widget.otherUserId}',
    );
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
        _loadMessages();
      },
    )
        .subscribe();
    _channel = channel;
  }

  Future<void> _send() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    try {
      await _supabase.from('messages').insert({
        'sender_id': user.id,
        'receiver_id': widget.otherUserId,
        'body': text,
      });
      _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
      _channel = null;
    }
    if (_presenceChannel != null) {
      _supabase.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _otherUser?['full_name'] ?? 'User';
    final avatarUrl = _otherUser?['avatar_url'];

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileViewScreen(
                  userId: widget.otherUserId,
                ),
              ),
            );
          },
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                      fullName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 14),
                    )
                        : null,
                  ),
                  if (_isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
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
                      fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _isOnline ? 'Online' : (_otherUser?['profession'] ?? ''),
                      style: TextStyle(
                        fontSize: 12,
                        color: _isOnline ? Colors.green : Colors.grey,
                        fontWeight: _isOnline ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileViewScreen(
                    userId: widget.otherUserId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(
              child: Text(
                'No messages yet.\nSay hello!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final user = _supabase.auth.currentUser;
                final isMe = user != null && m['sender_id'] == user.id;
                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFF6A5AE0)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m['body'] ?? '',
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(m['created_at']),
                          style: TextStyle(
                            color: isMe
                                ? Colors.white70
                                : Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF6A5AE0),
                    child: IconButton(
                      onPressed: _send,
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }
}
