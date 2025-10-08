import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications_popup.dart';
import '../services/cache_service.dart';

class NotificationIcon extends StatefulWidget {
  const NotificationIcon({super.key});

  @override
  State<NotificationIcon> createState() => _NotificationIconState();
}

class _NotificationIconState extends State<NotificationIcon> {
  StreamSubscription<AuthState>? _authStateSubscription;
  RealtimeChannel? _notificationSubscription;
  int _unreadCount = 0;
  final _supabase = Supabase.instance.client;
  final _cache = CacheService();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _getUnreadCount();
        _subscribeToNotifications();
      } else if (event == AuthChangeEvent.signedOut) {
        _unreadCount = 0;
        if (_notificationSubscription != null) {
          _supabase.removeChannel(_notificationSubscription!);
          _notificationSubscription = null;
        }
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> _getUnreadCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final cacheKey = 'unread_notifications_${user.id}';

    // Check cache first
    if (_cache.has(cacheKey)) {
      final cachedCount = _cache.get<int>(cacheKey);
      if (cachedCount != null && mounted) {
        setState(() {
          _unreadCount = cachedCount;
        });
        return;
      }
    }

    try {
      // Use the correct variable '_supabase' here
      final data = await _supabase
          .from('notifications')
          .select('id')
          .eq('is_read', false) as List<dynamic>;

      final int count = data.length;

      // Cache the result for 1 minute
      _cache.set(cacheKey, count, durationMinutes: 1);

      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (e) {
      // Silently fail, keep existing count
    }
  }

  void _debouncedGetUnreadCount() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _getUnreadCount();
    });
  }

  void _subscribeToNotifications() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (_notificationSubscription != null) {
      _supabase.removeChannel(_notificationSubscription!);
      _notificationSubscription = null;
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
            final userId = _supabase.auth.currentUser?.id;
            if (userId != null) {
              _cache.remove('unread_notifications_$userId');
            }
            _debouncedGetUnreadCount();
          },
        )
        .subscribe();
    _notificationSubscription = channel;
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _debounceTimer?.cancel();
    if (_notificationSubscription != null) {
      _supabase.removeChannel(_notificationSubscription!);
      _notificationSubscription = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () async {
            await showNotificationsDialog(context);
            final userId = _supabase.auth.currentUser?.id;
            if (userId != null) {
              _cache.remove('unread_notifications_$userId');
            }
            _getUnreadCount();
          },
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
