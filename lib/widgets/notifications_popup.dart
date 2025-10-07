import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cache_service.dart';

Future<void> showNotificationsDialog(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notifications',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, a1, a2) {
      return _NotificationsPopup();
    },
    transitionBuilder: (ctx, a1, a2, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: a1,
          child: child,
        ),
      );
    },
  );
}

class _NotificationsPopup extends StatefulWidget {
  @override
  State<_NotificationsPopup> createState() => _NotificationsPopupState();
}

class _NotificationsPopupState extends State<_NotificationsPopup> {
  final _supabase = Supabase.instance.client;
  final _cache = CacheService();
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    final cacheKey = 'notifications_list_${user.id}';
    
    // Check cache first
    if (_cache.has(cacheKey)) {
      final cached = _cache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cached != null) {
        setState(() {
          _notifications = cached;
          _loading = false;
        });
      }
    }
    
    try {
      final res = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50); // Limit to 50 most recent for performance
      
      final notifications = List<Map<String, dynamic>>.from(res as List);
      
      // Cache for 2 minutes
      _cache.set(cacheKey, notifications, durationMinutes: 2);
      
      setState(() {
        _notifications = notifications;
        _loading = false;
      });
      
      _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false)
          .then((_) {
            // Invalidate unread count cache
            _cache.remove('unread_notifications_${user.id}');
          });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        _cache.remove('notifications_list_$userId');
        _cache.remove('unread_notifications_$userId');
      }
      
      setState(() {
        _notifications.removeWhere((n) => n['id'] == notificationId);
      });
    } catch (e) {
      // Handle error
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.tryParse(timestamp);
    if (dt == null) return '';
    
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    return Align(
      alignment: Alignment.bottomCenter,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            height: screenHeight * (isSmallScreen ? 0.75 : 0.65),
            margin: EdgeInsets.only(
              left: isSmallScreen ? 0 : 16,
              right: isSmallScreen ? 0 : 16,
              bottom: isSmallScreen ? 0 : 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(24),
                topRight: const Radius.circular(24),
                bottomLeft: Radius.circular(isSmallScreen ? 0 : 24),
                bottomRight: Radius.circular(isSmallScreen ? 0 : 24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 20,
                    vertical: isSmallScreen ? 14 : 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: const Color(0xFF6A5AE0),
                        size: isSmallScreen ? 24 : 28,
                      ),
                      SizedBox(width: isSmallScreen ? 10 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                            if (_notifications.isNotEmpty)
                              Text(
                                '${_notifications.length} notification${_notifications.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 13,
                                  color: Colors.grey[600],
                                  fontFamily: 'Inter',
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_none,
                                size: isSmallScreen ? 64 : 80,
                                color: Colors.grey[300],
                              ),
                              SizedBox(height: isSmallScreen ? 12 : 16),
                              Text(
                                'No notifications yet',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'We\'ll notify you when something arrives',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                  color: Colors.grey[500],
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 6 : 8,
                          ),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final n = _notifications[index];
                            final isRead = n['is_read'] == true;
                            
                            return Dismissible(
                              key: Key(n['id'].toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.only(
                                  right: isSmallScreen ? 16 : 20,
                                ),
                                color: Colors.red,
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (direction) {
                                _deleteNotification(n['id'].toString());
                              },
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 10 : 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isRead ? Colors.white : const Color(0xFFF5F3FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isRead ? Colors.grey[200]! : const Color(0xFFE0DBFF),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 12 : 16,
                                    vertical: isSmallScreen ? 6 : 8,
                                  ),
                                  leading: Container(
                                    padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6A5AE0).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _getNotificationIcon(n['title']?.toString() ?? ''),
                                      color: const Color(0xFF6A5AE0),
                                      size: isSmallScreen ? 20 : 24,
                                    ),
                                  ),
                                  title: Text(
                                    n['title']?.toString() ??
                                        n['message']?.toString() ??
                                        'Notification',
                                    style: TextStyle(
                                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      fontSize: isSmallScreen ? 14 : 15,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (n['body']?.toString().isNotEmpty ?? false) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          n['body'].toString(),
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 12 : 13,
                                            color: Colors.grey[600],
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatTimestamp(n['created_at']?.toString()),
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 11 : 12,
                                          color: Colors.grey[500],
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: !isRead
                                      ? Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF6A5AE0),
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('message') || lowerTitle.contains('chat')) {
      return Icons.message;
    } else if (lowerTitle.contains('mentor') || lowerTitle.contains('request')) {
      return Icons.person_add;
    } else if (lowerTitle.contains('resource')) {
      return Icons.menu_book;
    } else if (lowerTitle.contains('post') || lowerTitle.contains('like')) {
      return Icons.favorite;
    }
    return Icons.notifications;
  }
}
