// home_feed_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_main_bar.dart';
import '../widgets/post_card.dart';
import 'create_post_screen.dart';
import 'interest_matching_screen.dart';
import 'all_posts_screen.dart';
import 'resource_detail_screen.dart';
import 'user_profile_view_screen.dart';
import '../services/cache_service.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  final _cache = CacheService();
  late Future<List<Map<String, dynamic>>> _postsFuture;
  late Future<List<Map<String, dynamic>>> _resourcesFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (_supabase.auth.currentUser == null) {
      _postsFuture = Future.value([]);
      _resourcesFuture = _fetchResources();
      return;
    }

    _postsFuture = _fetchPosts();
    _resourcesFuture = _fetchResources();
  }

  Future<List<Map<String, dynamic>>> _fetchPosts() async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      return [];
    }

    try {
      final friendsResponse = await _supabase
          .from('friendships')
          .select('requester_id, addressee_id')
          .eq('status', 'ACCEPTED')
          .or('requester_id.eq.$userId,addressee_id.eq.$userId');

      final friendIds = <String>{};
      for (final row in friendsResponse as List) {
        if (row['requester_id'] == userId) {
          friendIds.add(row['addressee_id'] as String);
        } else {
          friendIds.add(row['requester_id'] as String);
        }
      }

      final postsResponse = await _supabase
          .from('posts')
          .select('''
            *,
            author:users!author_id(id, full_name, avatar_url),
            post_media(id, media_url, media_type)
          ''')
          .order('created_at', ascending: false)
          .limit(50);

      final posts = List<Map<String, dynamic>>.from(postsResponse as List);

      final filteredPosts = posts.where((post) {
        final visibility = post['visibility'];
        final authorId = post['author_id'];

        if (authorId == userId) return true;
        if (visibility == 'PUBLIC') return true;
        if (visibility == 'FRIENDS' && friendIds.contains(authorId)) return true;

        return false;
      }).toList();

      final postIds = filteredPosts.map((p) => p['id'] as String).toList();
      if (postIds.isNotEmpty) {
        final likesResponse = await _supabase
            .from('post_likes')
            .select('post_id')
            .inFilter('post_id', postIds);

        final likesMap = <String, int>{};
        for (final like in likesResponse as List) {
          final postId = like['post_id'] as String;
          likesMap[postId] = (likesMap[postId] ?? 0) + 1;
        }

        for (final post in filteredPosts) {
          post['likes_count'] = likesMap[post['id']] ?? 0;
        }
      }

      return filteredPosts;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchResources() async {
    const cacheKey = 'resources_preview';

    if (_cache.has(cacheKey)) {
      return _cache.get<List<Map<String, dynamic>>>(cacheKey) ?? [];
    }

    try {
      final response = await _supabase
          .from('resources')
          .select('id, title, summary, cover_image_url, author_id, created_at, author:users!author_id(id, full_name)')
          .order('created_at', ascending: false)
          .limit(3);

      final resources = List<Map<String, dynamic>>.from(response as List).map((r) {
        return {
          ...r,
          'author_name': r['author']?['full_name'],
          'author_id': r['author']?['id'],
        };
      }).toList();
      _cache.set(cacheKey, resources, durationMinutes: 10);
      return resources;
    } catch (e) {
      print('Error fetching resources: $e');
      return [];
    }
  }

  Future<void> _loadPosts() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      _cache.remove('posts_$userId');
    }
    setState(() {
      _loadData();
    });
  }

  Future<void> _navigateToCreatePost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreatePostScreen(),
      ),
    );

    if (result == true) {
      _loadPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppMainBar(title: 'Home'),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFindMatchCard(isSmallScreen),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Text(
                    'Resources',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 10 : 12),
                  _buildResourcesFutureBuilder(isSmallScreen),

                  SizedBox(height: isSmallScreen ? 20 : 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Posts',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _loadPosts,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 10 : 12),
                ],
              ),
            ),

            FutureBuilder<List<String, dynamic>>>(
              future: _postsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Error loading posts: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  );
                }

                final posts = snapshot.data ?? [];

                if (posts.isEmpty) {
                  return _buildNoPostsPlaceholder();
                }

                final displayPosts = posts.take(3).toList();
                final hasMorePosts = posts.length > 3;

                return Column(
                  children: [
                    ...displayPosts.map((post) {
                      return PostCard(
                        post: post,
                        onLikeChanged: _loadPosts,
                        onDeleted: _loadPosts,
                      );
                    }),

                    if (hasMorePosts)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AllPostsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.grid_view),
                          label: Text('View All ${posts.length} Posts'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6A5AE0),
                            side: const BorderSide(color: Color(0xFF6A5AE0)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreatePost,
        backgroundColor: const Color(0xFF6A5AE0),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- Extracted Widget Methods for Readability ---

  Widget _buildFindMatchCard(bool isSmallScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InterestMatchingScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EDFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.people,
                  color: const Color(0xFF6A5AE0),
                  size: isSmallScreen ? 28 : 32,
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find Your Match',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connect with mentors who share your interests',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        color: Colors.grey,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourcesFutureBuilder(bool isSmallScreen) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _resourcesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final resources = snapshot.data ?? [];
        if (resources.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No resources available yet',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        }

        return Column(
          children: resources.map((resource) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () async {
                  final fullResource = await _supabase
                      .from('resources')
                      .select('*, author:users!author_id(id, full_name)')
                      .eq('id', resource['id'])
                      .single();
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResourceDetailScreen(
                          resource: Map<String, dynamic>.from({
                            ...fullResource,
                            'author_name': fullResource['author']?['full_name'],
                            'author_id': fullResource['author']?['id'],
                          }),
                        ),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.article,
                            color: Color(0xFF6A5AE0),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              resource['title'] ?? '',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: isSmallScreen ? 15 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        resource['summary'] ?? '',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (resource['author_name'] != null) ..[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            if (resource['author_id'] != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserProfileViewScreen(
                                    userId: resource['author_id'],
                                  ),
                                ),
                              );
                            }
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: const Color(0xFF6A5AE0).withOpacity(0.1),
                                child: Text(
                                  resource['author_name'][0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6A5AE0),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'By ${resource['author_name']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                  fontFamily: 'Inter',
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildNoPostsPlaceholder() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.post_add,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No posts yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to share something!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}