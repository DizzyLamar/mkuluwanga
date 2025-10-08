import 'package:flutter/material.dart';
import 'user_profile_view_screen.dart';

class ResourceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> resource;
  const ResourceDetailScreen({super.key, required this.resource});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(resource['title'] ?? 'Resource'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (resource['cover_image_url'] != null && resource['cover_image_url'].toString().isNotEmpty)
              Image.network(
                resource['cover_image_url'],
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 240,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource['title'] ?? '',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (resource['author_name'] != null)
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
                            radius: 20,
                            backgroundColor: const Color(0xFF6A5AE0).withOpacity(0.1),
                            child: Text(
                              resource['author_name'][0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6A5AE0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                resource['author_name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  fontFamily: 'Inter',
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              if (resource['created_at'] != null)
                                Text(
                                  _formatDate(resource['created_at']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontFamily: 'Inter',
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    resource['content'] ?? '',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                          fontFamily: 'Inter',
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function
String _formatDate(dynamic date) {
  if (date == null) return '';
  final dt = DateTime.tryParse(date.toString());
  if (dt == null) return '';
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
