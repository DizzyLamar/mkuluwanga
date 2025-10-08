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
  List<String> _categories = ['All'];
  final _cache = CacheService();
  List<Map<String, dynamic>>? _cachedResources;
  bool _isLoadingCategories = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('interests')
          .select('name')
          .order('name');

      final interests = List<Map<String, dynamic>>.from(response as List);
      final categoryNames = interests.map((i) => i['name'] as String).toList();

      setState(() {
        _categories = ['All', ...categoryNames];
        _isLoadingCategories = false;
      });
    } catch (e) {
      print('[v0] Error loading categories: $e');
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

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

  void _showCreateResourceModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateResourceModal(
        categories: _categories.where((c) => c != 'All').toList(),
        onResourceCreated: () {
          _refreshResources();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    final userRole = Supabase.instance.client.auth.currentUser?.userMetadata?['role'];
    final isMentor = userRole == 'MENTOR';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const AppMainBar(title: 'Resources'),
      floatingActionButton: isMentor
          ? FloatingActionButton.extended(
        onPressed: _showCreateResourceModal,
        backgroundColor: const Color(0xFF6A5AE0),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Create Resource',
          style: TextStyle(color: Colors.white),
        ),
      )
          : null,
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
                if (_isLoadingCategories)
                  const Center(child: CircularProgressIndicator())
                else
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

                if (_selectedCategory != 'All') {
                  resources = resources.where((r) =>
                  (r['category'] ?? '').toLowerCase() == _selectedCategory.toLowerCase()
                  ).toList();
                }

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
                          _searchQuery.isNotEmpty || _selectedCategory != 'All'
                              ? 'No resources found'
                              : 'No resources available yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty || _selectedCategory != 'All'
                              ? 'Try a different filter'
                              : 'Check back later for new content',
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

class _CreateResourceModal extends StatefulWidget {
  final List<String> categories;
  final VoidCallback onResourceCreated;

  const _CreateResourceModal({
    required this.categories,
    required this.onResourceCreated,
  });

  @override
  State<_CreateResourceModal> createState() => _CreateResourceModalState();
}

class _CreateResourceModalState extends State<_CreateResourceModal> {
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  final _coverImageController = TextEditingController();
  String? _selectedCategory;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _coverImageController.dispose();
    super.dispose();
  }

  Future<void> _createResource() async {
    if (_titleController.text.trim().isEmpty ||
        _summaryController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authorId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('resources').insert({
        'title': _titleController.text.trim(),
        'summary': _summaryController.text.trim(),
        'content': _contentController.text.trim(),
        'cover_image_url': _coverImageController.text.trim().isEmpty
            ? null
            : _coverImageController.text.trim(),
        'category': _selectedCategory,
        'author_id': authorId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resource published!')),
        );
        widget.onResourceCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                  'Create Resource',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title *',
                      hintText: 'Enter resource title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _summaryController,
                    decoration: InputDecoration(
                      labelText: 'Summary *',
                      hintText: 'Brief description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contentController,
                    decoration: InputDecoration(
                      labelText: 'Content *',
                      hintText: 'Full resource content',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      hintText: 'Select a category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('No category'),
                      ),
                      ...widget.categories.map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _coverImageController,
                    decoration: InputDecoration(
                      labelText: 'Cover Image URL (Optional)',
                      hintText: 'https://example.com/image.jpg',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _createResource,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A5AE0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Publish Resource',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
