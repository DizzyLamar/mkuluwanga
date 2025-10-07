import 'package:flutter/material.dart';

class ResourceCard extends StatelessWidget {
  final Map<String, dynamic> resource;
  final VoidCallback onReadMore;

  const ResourceCard({super.key, required this.resource, required this.onReadMore});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: 8,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onReadMore,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (resource['cover_image_url'] != null && 
                resource['cover_image_url'].toString().isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    resource['cover_image_url'],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource['title'] ?? '',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 17 : 19,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (resource['author_name'] != null) ...[
                        CircleAvatar(
                          radius: 12,
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
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            resource['author_name'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                              fontFamily: 'Inter',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (resource['created_at'] != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(resource['created_at']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontFamily: 'Inter',
                          ),
                        ),
                      ]
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    resource['summary'] ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey[700],
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: onReadMore,
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Read More'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6A5AE0),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
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

String _formatDate(dynamic date) {
  if (date == null) return '';
  final dt = DateTime.tryParse(date.toString());
  if (dt == null) return '';
  
  final now = DateTime.now();
  final diff = now.difference(dt);
  
  if (diff.inDays < 1) return 'Today';
  if (diff.inDays < 2) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  
  return '${dt.month}/${dt.day}/${dt.year}';
}
