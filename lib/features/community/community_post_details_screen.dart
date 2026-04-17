import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_model.dart';
import 'community_repository.dart';
import 'community_user_profile_screen.dart';

class CommunityPostDetailsScreen extends StatefulWidget {
  const CommunityPostDetailsScreen({
    super.key,
    required this.postId,
  });

  final String postId;

  @override
  State<CommunityPostDetailsScreen> createState() =>
      _CommunityPostDetailsScreenState();
}

class _CommunityPostDetailsScreenState extends State<CommunityPostDetailsScreen> {
  final CommunityRepository _repository = CommunityRepository();
  final TextEditingController _commentController = TextEditingController();

  CommunityPostModel? _post;
  List<CommunityCommentModel> _comments = <CommunityCommentModel>[];
  bool _isLoading = true;
  bool _isSendingComment = false;
  bool _isTogglingPostLike = false;
  final Set<String> _togglingCommentLikes = <String>{};

  @override
  void initState() {
    super.initState();
    _load(incrementView: true);
  }

  Future<void> _load({bool incrementView = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (incrementView) {
        await _repository.incrementPostView(widget.postId);
      }

      final post = await _repository.fetchPostById(widget.postId);
      final comments = await _repository.fetchComments(widget.postId);

      if (!mounted) {
        return;
      }

      setState(() {
        _post = post;
        _comments = comments;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load post: $error')),
      );
    }
  }

  Future<void> _submitComment() async {
    final message = _commentController.text.trim();
    if (message.isEmpty || _post == null || _isSendingComment) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to comment')),
      );
      return;
    }

    setState(() {
      _isSendingComment = true;
    });

    try {
      await _repository.addComment(
        postId: _post!.id,
        message: message,
      );

      _commentController.clear();
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingComment = false;
        });
      }
    }
  }

  Future<void> _togglePostLike() async {
    final post = _post;
    if (post == null || _isTogglingPostLike) {
      return;
    }

    setState(() {
      _isTogglingPostLike = true;
    });

    try {
      await _repository.toggleLikePost(post.id);
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingPostLike = false;
        });
      }
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    if (_togglingCommentLikes.contains(commentId)) {
      return;
    }

    setState(() {
      _togglingCommentLikes.add(commentId);
    });

    try {
      await _repository.toggleLikeComment(commentId);
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update comment like: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _togglingCommentLikes.remove(commentId);
        });
      }
    }
  }

  void _openProfile(String? userId, String fallbackName) {
    if (userId == null || userId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile not available')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPublicProfileScreen(
          userId: userId,
          fallbackName: fallbackName,
        ),
      ),
    );
  }

  void _openImageLightbox(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.black,
          child: Stack(
            children: <Widget>[
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ExtendedImage.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    cache: true,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy • HH:mm').format(dateTime);
  }

  Widget _buildAvatar({
    required String name,
    String? avatarUrl,
    double radius = 22,
  }) {
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      child: Text(initial),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : post == null
                ? const Center(child: Text('Post not found'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: <Widget>[
                        Material(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                InkWell(
                                  onTap: () =>
                                      _openProfile(post.authorId, post.authorName),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Row(
                                      children: <Widget>[
                                        _buildAvatar(
                                          name: post.authorName,
                                          avatarUrl: post.authorAvatarUrl,
                                          radius: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                post.authorName,
                                                style: theme.textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatTime(post.createdAt),
                                                style: theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if ((post.category ?? '').trim().isNotEmpty)
                                          Chip(label: Text(post.category!)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  post.title,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  post.bodyText.isNotEmpty
                                      ? post.bodyText
                                      : post.plainText,
                                  style: theme.textTheme.bodyLarge,
                                ),
                                if (post.imageUrls.isNotEmpty ||
                                    (post.primaryImageUrl?.isNotEmpty ?? false)) ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 220,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: post.imageUrls.isNotEmpty
                                          ? post.imageUrls.length
                                          : 1,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 10),
                                      itemBuilder: (context, index) {
                                        final imageUrl = post.imageUrls.isNotEmpty
                                            ? post.imageUrls[index]
                                            : post.primaryImageUrl!;
                                        return GestureDetector(
                                          onTap: () =>
                                              _openImageLightbox(imageUrl),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            child: SizedBox(
                                              width: 280,
                                              child: ExtendedImage.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                cache: true,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                Row(
                                  children: <Widget>[
                                    FilledButton.icon(
                                      onPressed: _isTogglingPostLike
                                          ? null
                                          : _togglePostLike,
                                      icon: Icon(
                                        post.isLikedByMe
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                      ),
                                      label: Text('${post.likeCount}'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: null,
                                      icon:
                                          const Icon(Icons.mode_comment_outlined),
                                      label: Text('${post.commentCount}'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: null,
                                      icon: const Icon(Icons.visibility_outlined),
                                      label: Text('${post.viewCount}'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Comments',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: <Widget>[
                              TextField(
                                controller: _commentController,
                                minLines: 3,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  hintText: 'Write a comment',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed:
                                      _isSendingComment ? null : _submitComment,
                                  icon: _isSendingComment
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.send),
                                  label: const Text('Post comment'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_comments.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Text('No comments yet.'),
                          )
                        else
                          ..._comments.map((CommunityCommentModel comment) {
                            final isBusy =
                                _togglingCommentLikes.contains(comment.id);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  InkWell(
                                    onTap: () => _openProfile(
                                      comment.authorId,
                                      comment.authorName,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Row(
                                        children: <Widget>[
                                          _buildAvatar(
                                            name: comment.authorName,
                                            avatarUrl: comment.authorAvatarUrl,
                                            radius: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text(
                                                  comment.authorName,
                                                  style: theme.textTheme.titleSmall
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                Text(
                                                  _formatTime(comment.createdAt),
                                                  style:
                                                      theme.textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: isBusy
                                                ? null
                                                : () => _toggleCommentLike(
                                                      comment.id,
                                                    ),
                                            icon: Icon(
                                              comment.likedByMe
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                            ),
                                          ),
                                          Text('${comment.likeCount}'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    comment.message,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
      ),
    );
  }
}
