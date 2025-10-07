import 'package:flutter/material.dart';

class ResourceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> resource;
  const ResourceDetailScreen({super.key, required this.resource});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(resource['title'] ?? 'Resource')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (resource['cover_image_url'] != null && resource['cover_image_url'].toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(resource['cover_image_url'], height: 200, width: double.infinity, fit: BoxFit.cover),
                ),
              const SizedBox(height: 16),
              Text(resource['title'] ?? '', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (resource['author_name'] != null)
                    Text('By ${resource['author_name']}', style: Theme.of(context).textTheme.bodySmall),
                  if (resource['created_at'] != null) ...[
                    const SizedBox(width: 8),
                    Text(_formatDate(resource['created_at']), style: Theme.of(context).textTheme.bodySmall),
                  ]
                ],
              ),
              const SizedBox(height: 16),
              Text(resource['content'] ?? '', style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
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
