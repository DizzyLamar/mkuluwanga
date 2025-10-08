import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription<AuthState>? _authStateSubscription;
  RealtimeChannel? _notificationChannel;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToNotifications();

    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _loadNotifications();
        _subscribeToNotifications();
      } else if (event == AuthChangeEvent.signedOut) {
        if (_notificationChannel != null) {
          _supabase.removeChannel(_notificationChannel!);
          _notificationChannel = null;
        }
        setState(() {
          _notifications = [];
        });
      }
    });
  }

  Future<void> _loadNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(res as List);
      });
    } catch (e) {
      // ignore
    }
  }

  void _subscribeToNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (_notificationChannel != null) {
      _supabase.removeChannel(_notificationChannel!);
      _notificationChannel = null;
    }

    final channel = _supabase.channel('notifications:${user.id}');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            _loadNotifications();
          },
        )
        .subscribe();

    _notificationChannel = channel;
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
      _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting notification: $e')),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear All Notifications'),
          content: const Text('Are you sure you want to clear all notifications?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (shouldClear == true) {
      try {
        await _supabase.from('notifications').delete().eq('user_id', user.id);
        _loadNotifications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All notifications cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing notifications: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    if (_notificationChannel != null) {
      _supabase.removeChannel(_notificationChannel!);
      _notificationChannel = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              onPressed: _clearAllNotifications,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? const Center(child: Text('No notifications'))
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final n = _notifications[index];
                return Dismissible(
                  key: Key(n['id'].toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    _deleteNotification(n['id'].toString());
                  },
                  child: ListTile(
                    title: Text(n['message']?.toString() ?? 'Notification'),
                    subtitle: n['created_at'] != null
                        ? Text(_formatDate(n['created_at']))
                        : null,
                    trailing: n['is_read'] == true
                        ? null
                        : const Icon(Icons.circle, color: Colors.blue, size: 12),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays < 1) {
        if (diff.inHours < 1) {
          return '${diff.inMinutes}m ago';
        }
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return '${dt.month}/${dt.day}/${dt.year}';
      }
    } catch (e) {
      return '';
    }
  }
}
