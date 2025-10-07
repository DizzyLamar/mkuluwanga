import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/messages_screen.dart';

class FindPeoplePopup extends StatefulWidget {
  final VoidCallback onClose;
  const FindPeoplePopup({super.key, required this.onClose});

  @override
  State<FindPeoplePopup> createState() => _FindPeoplePopupState();
}

/// Helper to show the find-people popup as a full-screen dialog with blurred background.
Future<void> showFindPeopleDialog(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierLabel: 'Find people',
    barrierDismissible: true,
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, anim1, anim2) {
      return FindPeoplePopup(onClose: () => Navigator.of(ctx).pop());
    },
  );
}

class _FindPeoplePopupState extends State<FindPeoplePopup> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
    });
    final res = await _supabase
        .from('users')
        .select('id, full_name, profession, district, avatar_url')
        .ilike('full_name', '%$q%')
        .limit(20);
    setState(() {
      _results = List<Map<String, dynamic>>.from(res as List);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          color: Colors.black45,
          alignment: Alignment.center,
          child: FractionallySizedBox(
            widthFactor: 0.9,
            heightFactor: 0.7,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Find people',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
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
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _results.isEmpty
                          ? const Center(
                              child: Text('Search for mentors or friends'),
                            )
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final u = _results[index];
                                return ListTile(
                                  leading: u['avatar_url'] != null
                                      ? CircleAvatar(
                                          backgroundImage: NetworkImage(
                                            u['avatar_url'],
                                          ),
                                        )
                                      : const CircleAvatar(
                                          child: Icon(Icons.person),
                                        ),
                                  title: Text(u['full_name'] ?? 'Unnamed'),
                                  subtitle: Text(
                                    '${u['profession'] ?? ''} • ${u['district'] ?? ''}',
                                  ),
                                  trailing: IconButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => MessagesScreen(
                                            otherUserId: u['id'],
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.message),
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
        ),
      ),
    );
  }
}
