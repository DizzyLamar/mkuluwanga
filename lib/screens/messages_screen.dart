import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessagesScreen extends StatefulWidget {
  final String otherUserId;
  const MessagesScreen({super.key, required this.otherUserId});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribe();
  }

  Future<void> _loadMessages() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final res = await _supabase
        .from('messages')
        .select()
        .or(
          'and(sender_id.eq.${user.id},receiver_id.eq.${widget.otherUserId}),and(sender_id.eq.${widget.otherUserId},receiver_id.eq.${user.id})',
        )
        .order('created_at', ascending: true);
    setState(() {
      _messages = List<Map<String, dynamic>>.from(res as List);
    });
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
            // only reload relevant messages
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
      _channel = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final user = _supabase.auth.currentUser;
                final isMe = user != null && m['sender_id'] == user.id;
                return ListTile(
                  title: Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(m['body'] ?? ''),
                    ),
                  ),
                  subtitle: Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Text(m['created_at'] ?? ''),
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
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Write a message',
                    ),
                  ),
                ),
                IconButton(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
