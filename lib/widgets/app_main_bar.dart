import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cache_service.dart';
import 'notifications_popup.dart';

class AppMainBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;

  const AppMainBar({
    super.key,
    required this.title,
    this.actions,
    this.centerTitle = false,
    this.backgroundColor = const Color(0xFF6A5AE0),
    this.foregroundColor = Colors.white,
    this.elevation = 0,
  });

  @override
  State<AppMainBar> createState() => _AppMainBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AppMainBarState extends State<AppMainBar> {
  final _supabase = Supabase.instance.client;
  final _cache = CacheService();
  int _unreadNotificationsCount = 0;
  RealtimeChannel? _notificationsChannel;

  @override
  void initState() {
    super.initState();
    _loadUnreadNotificationsCount();
    _subscribeToNotifications();
  }

  Future<void> _loadUnreadNotificationsCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final cacheKey = 'unread_notifications_${user.id}';

    // Check cache first
    if (_cache.has(cacheKey)) {
      final cached = _cache.get<int>(cacheKey);
      if (cached != null) {
        setState(() {
          _unreadNotificationsCount = cached;
        });
        return;
      }
    }

    try {
      final res = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      final count = res.length;

      // Cache for 1 minute
      _cache.set(cacheKey, count, durationMinutes: 1);

      if (mounted) {
        setState(() {
          _unreadNotificationsCount = count;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  void _subscribeToNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final channel = _supabase.channel('appbar_notifications:${user.id}');
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
        _cache.remove('unread_notifications_${user.id}');
        _loadUnreadNotificationsCount();
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'notifications',
      callback: (payload) {
        _cache.remove('unread_notifications_${user.id}');
        _loadUnreadNotificationsCount();
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'notifications',
      callback: (payload) {
        _cache.remove('unread_notifications_${user.id}');
        _loadUnreadNotificationsCount();
      },
    )
        .subscribe();
    _notificationsChannel = channel;
  }

  @override
  void dispose() {
    if (_notificationsChannel != null) {
      _supabase.removeChannel(_notificationsChannel!);
      _notificationsChannel = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: widget.centerTitle,
      backgroundColor: widget.backgroundColor,
      foregroundColor: widget.foregroundColor,
      elevation: widget.elevation,
      actions: [
        IconButton(
          icon: Badge(
            isLabelVisible: _unreadNotificationsCount > 0,
            label: Text(
              _unreadNotificationsCount > 99 ? '99+' : '$_unreadNotificationsCount',
              style: const TextStyle(fontSize: 10),
            ),
            backgroundColor: Colors.red,
            child: const Icon(Icons.notifications),
          ),
          onPressed: () async {
            await showNotificationsDialog(context);
            // Reload count after closing popup
            _cache.remove('unread_notifications_${_supabase.auth.currentUser?.id}');
            _loadUnreadNotificationsCount();
          },
        ),
        ...?widget.actions,
      ],
    );
  }
}