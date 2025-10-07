import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'messages_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _incoming = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadIncomingRequests();
  }

  Future<void> _loadIncomingRequests() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final res = await _supabase
        .from('friendships')
        .select('id, requester_id, addressee_id, status, created_at')
        .eq('addressee_id', user.id)
        .eq('status', 'PENDING');
    setState(() {
      _incoming = List<Map<String, dynamic>>.from(res as List);
    });
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
    });

    final res = await _supabase
        .from('users')
        .select('id, full_name, profession, district')
        .ilike('full_name', '%$q%')
        .limit(20);
    setState(() {
      _results = List<Map<String, dynamic>>.from(res as List);
      _loading = false;
    });
  }

  Future<void> _sendRequest(String addresseeId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('friendships').insert({
        'requester_id': user.id,
        'addressee_id': addresseeId,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Friend request sent')));
      }
      _loadIncomingRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _acceptRequest(String id) async {
    try {
      await _supabase
          .from('friendships')
          .update({'status': 'ACCEPTED'})
          .eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted')),
        );
      }
      _loadIncomingRequests();
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Friends')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by name',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _loading ? null : _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  if (_incoming.isNotEmpty) ...[
                    const Text(
                      'Incoming requests',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ..._incoming.map(
                      (r) => ListTile(
                        title: Text(r['requester_id'].toString()),
                        subtitle: Text('Requested at ${r['created_at']}'),
                        trailing: ElevatedButton(
                          onPressed: () => _acceptRequest(r['id']),
                          child: const Text('Accept'),
                        ),
                      ),
                    ),
                  ],
                  if (_results.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Results',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ..._results.map(
                      (u) => ListTile(
                        title: Text(u['full_name'] ?? 'Unnamed'),
                        subtitle: Text(
                          '${u['profession'] ?? ''} • ${u['district'] ?? ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MessagesScreen(otherUserId: u['id']),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.message),
                            ),
                            ElevatedButton(
                              onPressed: () => _sendRequest(u['id']),
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
