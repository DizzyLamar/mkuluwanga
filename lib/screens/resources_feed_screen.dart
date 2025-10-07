import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/resource_card.dart';
import 'resource_detail_screen.dart';
import '../widgets/app_main_bar.dart';
import '../services/cache_service.dart';

class ResourcesFeedScreen extends StatefulWidget {
  const ResourcesFeedScreen({super.key});

  @override
  State<ResourcesFeedScreen> createState() => _ResourcesFeedScreenState();
}

class _ResourcesFeedScreenState extends State<ResourcesFeedScreen> with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Career', 'Skills', 'Personal', 'Business'];
  final _cache = CacheService();
  List<Map<String, dynamic>>? _cachedResources;

  @override
  bool get wantKeepAlive => true;

  Future<List<Map<String, dynamic>>> fetchResources() async {
    const cacheKey = 'resources_all';
    
    if (_cache.has(cacheKey)) {
      return _cache.get<List<Map<String, dynamic>>>(cacheKey) ?? [];
    }

    final response = await Supabase.instance.client
        .from('resources')
        .select('*, author:users(id, full_name)')
        .order('created_at', ascending: false);
    
    final resources = List<Map<String, dynamic>>.from(response).map((r) {
      r['author_name'] = r['author']?['full_name'] ?? '';
      return r;
    }).toList();
    
    _cache.set(cacheKey, resources, durationMinutes: 10);
    return resources;
  }

  void _refreshResources() {
    _cache.remove('resources_all');
    setState(() {
      _cachedResources = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const AppMainBar(title: 'Resources'),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search resources...',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontFamily: 'Inter',
                      fontSize: isSmallScreen ? 14 : 15,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF6A5AE0)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 12 : 14,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
                SizedBox(height: isSmallScreen ? 10 : 12),
                SizedBox(
                  height: isSmallScreen ? 36 : 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          backgroundColor: Colors.grey[100],
                          selectedColor: const Color(0xFF6A5AE0),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontFamily: 'Inter',
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                          checkmarkColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 10 : 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchResources(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading resources',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  );
                }
                var resources = snapshot.data ?? [];
                
                if (_searchQuery.isNotEmpty) {
                  resources = resources.where((r) =>
                    (r['title'] ?? '').toLowerCase().contains(_searchQuery) ||
                    (r['author_name'] ?? '').toLowerCase().contains(_searchQuery) ||
                    (r['summary'] ?? '').toLowerCase().contains(_searchQuery)
                  ).toList();
                }
                
                if (resources.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty 
                              ? 'No resources available yet'
                              : 'No resources found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Check back later for new content'
                              : 'Try a different search term',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return RefreshIndicator(
                  onRefresh: () async {
                    _refreshResources();
                  },
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 8 : 12,
                    ),
                    itemCount: resources.length,
                    itemBuilder: (context, index) {
                      final resource = resources[index];
                      return ResourceCard(
                        resource: resource,
                        onReadMore: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResourceDetailScreen(resource: resource),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
