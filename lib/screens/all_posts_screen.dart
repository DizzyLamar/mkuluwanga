import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/post_card.dart';

class AllPostsScreen extends StatefulWidget {
  const AllPostsScreen({super.key});

  @override
  State<AllPostsScreen> createState() => _AllPostsScreenState();
}

class _AllPostsScreenState extends State<AllPostsScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  void _loadPosts() {
    setState(() {
      _postsFuture = _fetchPosts();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchPosts() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final postsResponse = await _supabase
          .from('posts')
          .select('''
            *,
            users!posts_user_id_fkey(id, full_name)
          ''')
          .eq('visibility', 'PUBLIC')
          .order('created_at', ascending: false)
          .limit(100);

      final posts = List<Map<String, dynamic>>.from(postsResponse as List);

      final postIds = posts.map((p) => p['id']).toList();
      if (postIds.isNotEmpty) {
        final likesResponse = await _supabase
            .from('post_likes')
            .select('post_id')
            .inFilter('post_id', postIds);

        final likesMap = <String, int>{};
        for (final like in likesResponse as List) {
          final postId = like['post_id'];
          likesMap[postId] = (likesMap[postId] ?? 0) + 1;
        }

        for (final post in posts) {
          post['likes_count'] = likesMap[post['id']] ?? 0;
        }
      }

      return posts;
    } catch (e) {
      print('Error fetching posts: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'All Posts',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey[300],
            height: 1,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadPosts();
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _postsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error loading posts: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final posts = snapshot.data ?? [];
            if (posts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.post_add,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No posts yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                return PostCard(
                  post: posts[index],
                  onLikeChanged: _loadPosts,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
