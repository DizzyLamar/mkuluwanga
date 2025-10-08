import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> showNotificationsDialog(BuildContext context) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return;

  // Fetch notifications
  final notifications = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', ascending: false);

  // Mark as read
  await supabase
      .from('notifications')
      .update({'is_read': true})
      .eq('user_id', user.id)
      .eq('is_read', false);

  await showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Material(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(
                  child: Text('No notifications'),
                )
                    : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return ListTile(
                      leading: const Icon(Icons.notifications),
                      title: Text(notification['title'] ?? 'Notification'),
                      subtitle: Text(notification['message'] ?? ''),
                      trailing: Text(
                        _formatDate(notification['created_at']),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () {
                        // Handle notification tap
                        // You might want to navigate to specific screen
                      },
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

String _formatDate(String dateString) {
  try {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  } catch (e) {
    return 'Unknown';
  }
}