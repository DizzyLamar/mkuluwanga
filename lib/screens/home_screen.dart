import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mentor_dashboard_screen.dart';
import 'profile_screen.dart';
import 'conversations_list_screen.dart';
import 'home_feed_screen.dart';
import 'resources_feed_screen.dart';
import 'vault_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? userRole;
  const HomeScreen({super.key, this.userRole});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  int _selectedIndex = 0;
  int _unreadMessagesCount = 0;
  RealtimeChannel? _messagesChannel;

  late final List<Widget> _widgetOptions;
  late final List<BottomNavigationBarItem> _navItems;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _widgetOptions = [];
    _navItems = [];
    _buildNavForRole(widget.userRole);
    _loadUnreadMessagesCount();
    _subscribeToMessages();
  }

  Future<void> _loadUnreadMessagesCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await _supabase
          .from('messages')
          .select('id')
          .eq('receiver_id', user.id)
          .eq('is_read', false);

      if (mounted) {
        setState(() {
          _unreadMessagesCount = res.length;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  void _subscribeToMessages() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final channel = _supabase.channel('home_messages:${user.id}');
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
        _loadUnreadMessagesCount();
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        _loadUnreadMessagesCount();
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

  void _buildNavForRole(String? role) {
    _widgetOptions.clear();
    _navItems.clear();

    if (role == 'MENTEE') {
      _widgetOptions.add(const HomeFeedScreen());
      _navItems.add(
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      );
      _widgetOptions.add(const ResourcesFeedScreen());
      _navItems.add(
        const BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Resources'),
      );
    } else if (role == 'MENTOR') {
      _widgetOptions.add(const MentorDashboardScreen());
      _navItems.add(
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
      );
      _widgetOptions.add(const ResourcesFeedScreen());
      _navItems.add(
        const BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Resources'),
      );
    } else {
      _widgetOptions.add(const Center(child: Text('No role assigned.')));
      _navItems.add(
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      );
    }

    _widgetOptions.add(const ConversationsListScreen());
    _navItems.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.chat_bubble),
        label: 'Chat',
      ),
    );

    _widgetOptions.add(const VaultScreen());
    _navItems.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.business_center),
        label: 'Vault',
      ),
    );

    _widgetOptions.add(const ProfileScreen());
    _navItems.add(
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_widgetOptions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: _navItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          final isChatTab = item.label == 'Chat';
          if (isChatTab && _unreadMessagesCount > 0) {
            return BottomNavigationBarItem(
              icon: Badge(
                label: Text(
                  _unreadMessagesCount > 99 ? '99+' : '$_unreadMessagesCount',
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: const Color(0xFF6A5AE0),
                child: item.icon,
              ),
              label: item.label,
            );
          }

          return item;
        }).toList(),
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF6A5AE0),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }
}