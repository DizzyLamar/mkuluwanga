import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'comments_bottom_sheet.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onLikeChanged;
  final VoidCallback? onDeleted;

  const PostCard({
    super.key,
    required this.post,
    this.onLikeChanged,
    this.onDeleted,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _isProcessing = false;
  bool _isExpanded = false;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post['likes_count'] ?? 0;
    _checkIfLiked();
    _fetchCommentsCount();

    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkIfLiked() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _supabase
          .from('post_likes')
          .select()
          .eq('post_id', widget.post['id'])
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isLiked = response != null;
        });
      }
    } catch (e) {
    }
  }

  Future<void> _fetchCommentsCount() async {
    try {
      final response = await _supabase
          .from('post_comments')
          .select('id')
          .eq('post_id', widget.post['id']);

      if (mounted) {
        setState(() {
          _commentsCount = (response as List).length;
        });
      }
    } catch (e) {
    }
  }

  Future<void> _toggleLike() async {
    if (_isProcessing) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      if (_isLiked) {
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', widget.post['id'])
            .eq('user_id', userId);

        setState(() {
          _isLiked = false;
          _likesCount = (_likesCount - 1).clamp(0, 999999);
        });
      } else {
        await _supabase.from('post_likes').insert({
          'post_id': widget.post['id'],
          'user_id': userId,
        });

        setState(() {
          _isLiked = true;
          _likesCount++;
        });

        _likeAnimationController.forward().then((_) {
          _likeAnimationController.reverse();
        });
      }

      widget.onLikeChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        postId: widget.post['id'],
        onCommentAdded: () {
          _fetchCommentsCount();
        },
      ),
    );
  }

  void _showPostOptions() {
    final userId = _supabase.auth.currentUser?.id;
    final isOwnPost = userId == widget.post['author_id'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwnPost)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete Post',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeletePost();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeletePost() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deletePost();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePost() async {
    try {
      await _supabase.from('posts').delete().eq('id', widget.post['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted')),
        );
        widget.onDeleted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting post: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.post['author'] as Map<String, dynamic>?;
    final authorName = author?['full_name'] ?? 'Unknown User';
    final avatarUrl = author?['avatar_url'];
    final content = widget.post['content'] ?? '';
    final createdAt = widget.post['created_at'] ?? '';
    final media = widget.post['post_media'] as List?;
    final visibility = widget.post['visibility'] ?? 'PUBLIC';

    // Format timestamp
    String timeAgo = '';
    try {
      final timestamp = DateTime.parse(createdAt);
      final difference = DateTime.now().difference(timestamp);
      if (difference.inDays > 0) {
        timeAgo = '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        timeAgo = '${difference.inMinutes}m';
      } else {
        timeAgo = 'now';
      }
    } catch (e) {
      timeAgo = '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with author info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF6A5AE0),
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '• $timeAgo',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  visibility == 'PUBLIC'
                      ? Icons.public
                      : visibility == 'FRIENDS'
                      ? Icons.people
                      : Icons.lock,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _showPostOptions,
                  icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[700]),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          if (media != null && media.isNotEmpty)
            GestureDetector(
              onDoubleTap: () {
                if (!_isLiked) {
                  _toggleLike();
                }
              },
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  media[0]['media_url'] ?? '',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
                      ),
                    );
                  },
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                ScaleTransition(
                  scale: _likeAnimation,
                  child: IconButton(
                    onPressed: _toggleLike,
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.black87,
                      size: 28,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _showComments,
                  icon: const Icon(
                    Icons.mode_comment_outlined,
                    color: Colors.black87,
                    size: 26,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {
                    // Share functionality
                  },
                  icon: const Icon(
                    Icons.send_outlined,
                    color: Colors.black87,
                    size: 26,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    // Bookmark functionality
                  },
                  icon: const Icon(
                    Icons.bookmark_border,
                    color: Colors.black87,
                    size: 26,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          if (_likesCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                _likesCount == 1 ? '1 like' : '$_likesCount likes',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
            ),

          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontFamily: 'Inter',
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: authorName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: content,
                        ),
                      ],
                    ),
                    maxLines: _isExpanded ? null : 3,
                    overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
                  if (content.length > 150)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _isExpanded ? 'Show less' : 'Show more',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          if (_commentsCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: GestureDetector(
                onTap: _showComments,
                child: Text(
                  _commentsCount == 1
                      ? 'View 1 comment'
                      : 'View all $_commentsCount comments',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey[300]),
        ],
      ),
    );
  }
}
