import 'package:flutter/material.dart';
import 'mentor_dashboard_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import 'home_feed_screen.dart';
import 'resources_feed_screen.dart';
import 'vault_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? userRole; // 'MENTOR' or 'MENTEE' (from users table)
  const HomeScreen({super.key, this.userRole});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  // popup will be triggered from the mentees screen on demand

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
    // The role is now guaranteed to be passed from AuthGate.
    _buildNavForRole(widget.userRole);
  }

  void _buildNavForRole(String? role) {
    _widgetOptions.clear();
    _navItems.clear();

    if (role == 'MENTEE') {
      // Use Home feed as the main landing for mentees
      _widgetOptions.add(const HomeFeedScreen());
      _navItems.add(
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      );
      // Add resources tab for mentees
      _widgetOptions.add(const ResourcesFeedScreen());
      _navItems.add(
        const BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Resources'),
      );
    } else if (role == 'MENTOR') {
      _widgetOptions.add(const MentorDashboardScreen());
      _navItems.add(
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
      );
      // Optionally add resources for mentors too
      _widgetOptions.add(const ResourcesFeedScreen());
      _navItems.add(
        const BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Resources'),
      );
    } else {
      // Fallback for null or other roles
      _widgetOptions.add(const Center(child: Text('No role assigned.')));
      _navItems.add(
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      );
    }

    _widgetOptions.add(const ChatScreen());
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
    // If for some reason the nav items aren't built yet, show a loader.
    if (_widgetOptions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: _navItems,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF6A5AE0),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        // This makes the background color of the nav bar visible.
        type: BottomNavigationBarType.fixed,
        // Show labels for all items.
        showUnselectedLabels: true,
      ),
    );
  }
}
