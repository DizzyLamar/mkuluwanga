import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'messages_screen.dart';
import 'user_profile_view_screen.dart';

class InterestMatchingScreen extends StatefulWidget {
  const InterestMatchingScreen({super.key});

  @override
  State<InterestMatchingScreen> createState() => _InterestMatchingScreenState();
}

class _InterestMatchingScreenState extends State<InterestMatchingScreen> {
  final _supabase = Supabase.instance.client;
  List<String> _myInterests = [];
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  List<String> _availableInterests = [];
  bool _isLoading = true;

  String _roleFilter = 'All'; // All, Mentors, Mentees
  Set<String> _selectedInterestFilters = {};
  String? _districtFilter;
  List<String> _districts = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadAvailableInterests(),
      _loadMyInterests(),
      _loadDistricts(),
    ]);
    await _loadAllUsers();
    _applyFilters();
    setState(() => _isLoading = false);
  }

  Future<void> _loadAvailableInterests() async {
    try {
      final response = await _supabase
          .from('interests')
          .select('name')
          .order('name');

      final rows = List<Map<String, dynamic>>.from(response as List);
      if (mounted) {
        setState(() {
          _availableInterests = rows.map((r) => r['name'] as String).toList();
        });
      }
    } catch (e) {
      print('[v0] Error loading available interests: $e');
    }
  }

  Future<void> _loadMyInterests() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('user_interests')
          .select('interest')
          .eq('user_id', userId);

      final rows = List<Map<String, dynamic>>.from(response as List);
      if (mounted) {
        setState(() {
          _myInterests = rows.map((r) => r['interest'] as String).toList();
        });
      }
    } catch (e) {
      print('[v0] Error loading interests: $e');
    }
  }

  Future<void> _loadDistricts() async {
    try {
      final response = await _supabase
          .from('users')
          .select('district')
          .not('district', 'is', null);

      final rows = List<Map<String, dynamic>>.from(response as List);
      final districtSet = <String>{};
      for (final row in rows) {
        final district = row['district'];
        if (district != null && district.toString().isNotEmpty) {
          districtSet.add(district.toString());
        }
      }

      if (mounted) {
        setState(() {
          _districts = districtSet.toList()..sort();
        });
      }
    } catch (e) {
      print('[v0] Error loading districts: $e');
    }
  }

  Future<void> _loadAllUsers() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch all users except current user
      final usersResponse = await _supabase
          .from('users')
          .select('id, full_name, bio, profession, role, district')
          .neq('id', userId)
          .order('full_name');

      final users = List<Map<String, dynamic>>.from(usersResponse as List);

      // Fetch all user interests in one query
      final userIds = users.map((u) => u['id'] as String).toList();

      if (userIds.isEmpty) {
        setState(() => _allUsers = []);
        return;
      }

      final interestsResponse = await _supabase
          .from('user_interests')
          .select('user_id, interest')
          .inFilter('user_id', userIds);

      final interests = List<Map<String, dynamic>>.from(interestsResponse as List);

      // Group interests by user_id
      final interestsMap = <String, List<String>>{};
      for (final interest in interests) {
        final uid = interest['user_id'] as String;
        final interestName = interest['interest'] as String;
        interestsMap.putIfAbsent(uid, () => []).add(interestName);
      }

      // Attach interests to users and calculate match score
      for (final user in users) {
        final uid = user['id'] as String;
        final userInterests = interestsMap[uid] ?? [];
        user['interests'] = userInterests;

        // Calculate shared interests
        final sharedInterests = _myInterests
            .where((interest) => userInterests.contains(interest))
            .toList();
        user['shared_interests'] = sharedInterests;
        user['match_score'] = sharedInterests.length;
      }

      await _loadRelationshipStatuses(users);

      if (mounted) {
        setState(() {
          _allUsers = users;
        });
      }
    } catch (e) {
      print('[v0] Error loading users: $e');
    }
  }

  Future<void> _loadRelationshipStatuses(List<Map<String, dynamic>> users) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final userIds = users.map((u) => u['id'] as String).toList();

      // Check friendships
      final friendshipsResponse = await _supabase
          .from('friendships')
          .select('requester_id, addressee_id, status')
          .or('requester_id.in.(${userIds.join(',')}),addressee_id.in.(${userIds.join(',')})');

      final friendships = List<Map<String, dynamic>>.from(friendshipsResponse as List);

      // Check mentorship requests
      final mentorshipsResponse = await _supabase
          .from('mentorship_requests')
          .select('mentee_id, mentor_id, status')
          .or('mentee_id.in.(${userIds.join(',')}),mentor_id.in.(${userIds.join(',')})');

      final mentorships = List<Map<String, dynamic>>.from(mentorshipsResponse as List);

      // Map statuses to users
      for (final user in users) {
        final uid = user['id'] as String;

        // Check friendship status
        final friendship = friendships.firstWhere(
              (f) => (f['requester_id'] == userId && f['addressee_id'] == uid) ||
              (f['addressee_id'] == userId && f['requester_id'] == uid),
          orElse: () => {},
        );
        user['friendship_status'] = friendship['status'];

        // Check mentorship status
        final mentorship = mentorships.firstWhere(
              (m) => (m['mentee_id'] == userId && m['mentor_id'] == uid) ||
              (m['mentor_id'] == userId && m['mentee_id'] == uid),
          orElse: () => {},
        );
        user['mentorship_status'] = mentorship['status'];
      }
    } catch (e) {
      print('[v0] Error loading relationship statuses: $e');
    }
  }

  void _applyFilters() {
    final searchQuery = _searchController.text.toLowerCase();

    setState(() {
      _filteredUsers = _allUsers.where((user) {
        // Role filter
        if (_roleFilter == 'Mentors' && user['role'] != 'MENTOR') return false;
        if (_roleFilter == 'Mentees' && user['role'] != 'MENTEE') return false;

        // District filter
        if (_districtFilter != null && user['district'] != _districtFilter) {
          return false;
        }

        // Interest filter
        if (_selectedInterestFilters.isNotEmpty) {
          final userInterests = List<String>.from(user['interests'] as List);
          final hasMatchingInterest = _selectedInterestFilters.any(
                (filter) => userInterests.contains(filter),
          );
          if (!hasMatchingInterest) return false;
        }

        // Search filter
        if (searchQuery.isNotEmpty) {
          final name = (user['full_name'] ?? '').toLowerCase();
          final bio = (user['bio'] ?? '').toLowerCase();
          final profession = (user['profession'] ?? '').toLowerCase();
          if (!name.contains(searchQuery) &&
              !bio.contains(searchQuery) &&
              !profession.contains(searchQuery)) {
            return false;
          }
        }

        return true;
      }).toList();

      // Sort by match score (highest first)
      _filteredUsers.sort((a, b) =>
          (b['match_score'] as int).compareTo(a['match_score'] as int));
    });
  }

  Future<void> _toggleInterest(String interest) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (_myInterests.contains(interest)) {
        await _supabase
            .from('user_interests')
            .delete()
            .eq('user_id', userId)
            .eq('interest', interest);

        setState(() => _myInterests.remove(interest));
      } else {
        await _supabase.from('user_interests').insert({
          'user_id': userId,
          'interest': interest,
        });

        setState(() => _myInterests.add(interest));
      }

      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(String addresseeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('friendships').insert({
        'requester_id': userId,
        'addressee_id': addresseeId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _sendMentorshipRequest(String mentorId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('mentorship_requests').insert({
        'mentee_id': userId,
        'mentor_id': mentorId,
        'status': 'PENDING',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mentorship request sent!')),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showInterestSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Your Interests',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _availableInterests.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _availableInterests.map((interest) {
                  final isSelected = _myInterests.contains(interest);
                  return CheckboxListTile(
                    title: Text(
                      interest,
                      style: const TextStyle(fontFamily: 'Inter'),
                    ),
                    value: isSelected,
                    onChanged: (_) {
                      _toggleInterest(interest);
                      Navigator.pop(context);
                    },
                    activeColor: const Color(0xFF6A5AE0),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _roleFilter = 'All';
                              _selectedInterestFilters.clear();
                              _districtFilter = null;
                            });
                            setState(() {});
                            _applyFilters();
                          },
                          child: const Text('Clear All'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Role filter
                    const Text(
                      'User Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['All', 'Mentors', 'Mentees'].map((role) {
                        return ChoiceChip(
                          label: Text(role),
                          selected: _roleFilter == role,
                          onSelected: (selected) {
                            setModalState(() => _roleFilter = role);
                            setState(() {});
                            _applyFilters();
                          },
                          selectedColor: const Color(0xFF6A5AE0),
                          labelStyle: TextStyle(
                            color: _roleFilter == role ? Colors.white : Colors.black,
                            fontFamily: 'Inter',
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // District filter
                    const Text(
                      'District',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _districtFilter,
                      decoration: const InputDecoration(
                        hintText: 'All Districts',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Districts'),
                        ),
                        ..._districts.map((district) => DropdownMenuItem(
                          value: district,
                          child: Text(district),
                        )),
                      ],
                      onChanged: (value) {
                        setModalState(() => _districtFilter = value);
                        setState(() {});
                        _applyFilters();
                      },
                    ),
                    const SizedBox(height: 24),

                    // Interest filters
                    const Text(
                      'Interests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableInterests.map((interest) {
                        final isSelected = _selectedInterestFilters.contains(interest);
                        return FilterChip(
                          label: Text(interest),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                _selectedInterestFilters.add(interest);
                              } else {
                                _selectedInterestFilters.remove(interest);
                              }
                            });
                            setState(() {});
                            _applyFilters();
                          },
                          selectedColor: const Color(0xFFF0EDFF),
                          checkmarkColor: const Color(0xFF6A5AE0),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFF6A5AE0) : Colors.black,
                            fontFamily: 'Inter',
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A5AE0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Show ${_filteredUsers.length} Results',
                      style: const TextStyle(fontFamily: 'Inter'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find People'),
        backgroundColor: const Color(0xFF6A5AE0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, bio, or profession...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onChanged: (_) => _applyFilters(),
              ),
            ),

            // My interests section
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Interests',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showInterestSelector,
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_myInterests.isEmpty)
                      Text(
                        'Add interests to find better matches',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontFamily: 'Inter',
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _myInterests.map((interest) {
                          return Chip(
                            label: Text(interest),
                            backgroundColor: const Color(0xFFF0EDFF),
                            labelStyle: const TextStyle(
                              color: Color(0xFF6A5AE0),
                              fontFamily: 'Inter',
                              fontSize: 12,
                            ),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => _toggleInterest(interest),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Active filters display
            if (_roleFilter != 'All' ||
                _selectedInterestFilters.isNotEmpty ||
                _districtFilter != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_roleFilter != 'All')
                      Chip(
                        label: Text(_roleFilter),
                        onDeleted: () {
                          setState(() => _roleFilter = 'All');
                          _applyFilters();
                        },
                      ),
                    if (_districtFilter != null)
                      Chip(
                        label: Text(_districtFilter!),
                        onDeleted: () {
                          setState(() => _districtFilter = null);
                          _applyFilters();
                        },
                      ),
                    ..._selectedInterestFilters.map((interest) => Chip(
                      label: Text(interest),
                      onDeleted: () {
                        setState(() => _selectedInterestFilters.remove(interest));
                        _applyFilters();
                      },
                    )),
                  ],
                ),
              ),

            // Results header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredUsers.length} People Found',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),

            // Users list
            Expanded(
              child: _filteredUsers.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No people found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _roleFilter = 'All';
                          _selectedInterestFilters.clear();
                          _districtFilter = null;
                          _searchController.clear();
                        });
                        _applyFilters();
                      },
                      child: const Text('Clear Filters'),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  return _buildUserCard(user);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final name = user['full_name'] ?? 'User';
    final bio = user['bio'] ?? '';
    final profession = user['profession'] ?? '';
    final role = user['role'] ?? '';
    final district = user['district'] ?? '';
    final matchScore = user['match_score'] as int;
    final sharedInterests = List<String>.from(user['shared_interests'] as List);
    final friendshipStatus = user['friendship_status'];
    final mentorshipStatus = user['mentorship_status'];
    final isMentor = role == 'MENTOR';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileViewScreen(
                userId: user['id'],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF6A5AE0),
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isMentor
                                    ? Colors.blue[50]
                                    : Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isMentor ? 'Mentor' : 'Mentee',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isMentor
                                      ? Colors.blue[700]
                                      : Colors.green[700],
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (profession.isNotEmpty)
                          Text(
                            profession,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontFamily: 'Inter',
                            ),
                          ),
                        if (district.isNotEmpty)
                          Text(
                            district,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                              fontFamily: 'Inter',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (matchScore > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$matchScore',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  bio,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontFamily: 'Inter',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (sharedInterests.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Shared interests:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: sharedInterests.map((interest) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EDFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        interest,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6A5AE0),
                          fontFamily: 'Inter',
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  // Message button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MessagesScreen(
                              otherUserId: user['id'],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.message, size: 18),
                      label: const Text('Message'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6A5AE0),
                        side: const BorderSide(color: Color(0xFF6A5AE0)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Friend/Mentor request button
                  Expanded(
                    child: _buildActionButton(
                      user,
                      isMentor,
                      friendshipStatus,
                      mentorshipStatus,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      Map<String, dynamic> user,
      bool isMentor,
      String? friendshipStatus,
      String? mentorshipStatus,
      ) {
    final currentUserRole = _supabase.auth.currentUser?.userMetadata?['role'] ?? 'MENTEE';

    if (isMentor) {
      // For mentors, only show mentorship request button if current user is a mentee
      if (currentUserRole != 'MENTEE') {
        // Current user is also a mentor, no action button
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.info_outline, size: 18),
          label: const Text('Fellow Mentor'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[200],
            foregroundColor: Colors.grey[600],
          ),
        );
      }

      // Current user is mentee, show mentorship request button
      if (mentorshipStatus == 'PENDING') {
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_empty, size: 18),
          label: const Text('Pending'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            foregroundColor: Colors.grey[700],
          ),
        );
      } else if (mentorshipStatus == 'ACCEPTED') {
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Mentoring'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[100],
            foregroundColor: Colors.green[700],
          ),
        );
      } else {
        return ElevatedButton.icon(
          onPressed: () => _sendMentorshipRequest(user['id']),
          icon: const Icon(Icons.school, size: 18),
          label: const Text('Request Mentor'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A5AE0),
            foregroundColor: Colors.white,
          ),
        );
      }
    } else {
      // For mentees, only show friend request button if current user is also a mentee
      if (currentUserRole != 'MENTEE') {
        // Current user is a mentor, no friend request button
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.info_outline, size: 18),
          label: const Text('Mentee'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[200],
            foregroundColor: Colors.grey[600],
          ),
        );
      }

      // Both are mentees, show friend request button
      if (friendshipStatus == 'PENDING') {
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_empty, size: 18),
          label: const Text('Pending'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            foregroundColor: Colors.grey[700],
          ),
        );
      } else if (friendshipStatus == 'ACCEPTED') {
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Friends'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[100],
            foregroundColor: Colors.green[700],
          ),
        );
      } else {
        return ElevatedButton.icon(
          onPressed: () => _sendFriendRequest(user['id']),
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Add Friend'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A5AE0),
            foregroundColor: Colors.white,
          ),
        );
      }
    }
  }
}
