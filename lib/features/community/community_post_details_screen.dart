import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_model.dart';
import 'community_repository.dart';
import 'community_user_profile_screen.dart';

class CommunityPostDetailsScreen extends StatefulWidget {
  const CommunityPostDetailsScreen({super.key, required this.postId});

  final String postId;

  @override
  State<CommunityPostDetailsScreen> createState() =>
      _CommunityPostDetailsScreenState();
}

class _CommunityPostDetailsScreenState
    extends State<CommunityPostDetailsScreen> {
  final CommunityRepository _repository = CommunityRepository();
  final TextEditingController _commentController = TextEditingController();

  CommunityPostModel? _post;
  List<CommunityCommentModel> _comments = <CommunityCommentModel>[];
  bool _isLoading = true;
  bool _isSendingComment = false;
  bool _isTogglingPostLike = false;
  final Set<String> _togglingCommentLikes = <String>{};
  String? _replyToCommentId;
  String? _replyToCommentAuthor;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  bool _isPostOwner(CommunityPostModel post) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return false;
    }
    return post.authorId == currentUserId;
  }

  bool _isCommentOwner(CommunityCommentModel comment) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return false;
    }
    return comment.authorId == currentUserId;
  }

  List<CommunityCommentModel> get _topLevelComments {
    return _comments
        .where(
          (CommunityCommentModel comment) =>
              comment.parentCommentId == null ||
              comment.parentCommentId!.trim().isEmpty,
        )
        .toList();
  }

  List<CommunityCommentModel> _childRepliesFor(String parentCommentId) {
    return _comments
        .where((CommunityCommentModel comment) {
          final String? parentId = comment.parentCommentId?.trim();
          return parentId != null && parentId == parentCommentId;
        })
        .toList();
  }

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load post: $error')));
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
        parentCommentId: _replyToCommentId,
      );
      final List<CommunityCommentModel> comments = await _repository
          .fetchComments(widget.postId);

      _commentController.clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = comments;
        _post = _post?.copyWith(commentCount: comments.length);
        _replyToCommentId = null;
        _replyToCommentAuthor = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to post comment: $error')));
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

    final bool nextLiked = !post.isLikedByMe;
    final int nextCount = post.likeCount + (nextLiked ? 1 : -1);

    setState(() {
      _isTogglingPostLike = true;
      _post = post.copyWith(
        isLikedByMe: nextLiked,
        likeCount: nextCount < 0 ? 0 : nextCount,
      );
    });

    try {
      await _repository.toggleLikePost(post.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _post = post;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update like: $error')));
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

    final int index = _comments.indexWhere(
      (CommunityCommentModel comment) => comment.id == commentId,
    );
    if (index == -1) {
      return;
    }
    final CommunityCommentModel original = _comments[index];
    final bool nextLiked = !original.likedByMe;
    final int nextCount = original.likeCount + (nextLiked ? 1 : -1);

    setState(() {
      _togglingCommentLikes.add(commentId);
      _comments[index] = original.copyWith(
        likedByMe: nextLiked,
        likeCount: nextCount < 0 ? 0 : nextCount,
      );
    });

    try {
      await _repository.toggleLikeComment(commentId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _comments[index] = original;
      });

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

  Future<void> _editPost(CommunityPostModel post) async {
    final titleController = TextEditingController(text: post.title);
    final bodyController = TextEditingController(text: post.bodyText);

    try {
      final bool? shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Edit post'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bodyController,
                    minLines: 5,
                    maxLines: 10,
                    decoration: const InputDecoration(labelText: 'Content'),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (shouldSave != true) {
        return;
      }

      await _repository.updatePost(
        postId: post.id,
        title: titleController.text,
        bodyText: bodyController.text,
        language: post.language,
        category: post.category,
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update post: $error')));
    } finally {
      titleController.dispose();
      bodyController.dispose();
    }
  }

  Future<void> _deletePost(CommunityPostModel post) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete post?'),
          content: const Text('This will remove your post from the feed.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _repository.softDeletePost(post.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete post: $error')));
    }
  }

  Future<void> _editComment(CommunityCommentModel comment) async {
    final controller = TextEditingController(text: comment.message);

    try {
      final bool? shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Edit comment'),
            content: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Comment'),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (shouldSave != true) {
        return;
      }

      await _repository.updateComment(
        commentId: comment.id,
        message: controller.text,
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update comment: $error')),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteComment(CommunityCommentModel comment) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete comment?'),
          content: const Text('This will remove your comment.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _repository.softDeleteComment(
        commentId: comment.id,
        postId: comment.postId,
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete comment: $error')),
      );
    }
  }

  Future<void> _copyToClipboard(String value, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  }

  void _setReplyTarget(CommunityCommentModel comment) {
    setState(() {
      _replyToCommentId = comment.id;
      _replyToCommentAuthor = comment.authorName;
    });
  }

  void _clearReplyTarget() {
    setState(() {
      _replyToCommentId = null;
      _replyToCommentAuthor = null;
    });
  }

  void _openProfile(String? userId, String fallbackName) {
    if (userId == null || userId.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile not available')));
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
    return CircleAvatar(radius: radius, child: Text(initial));
  }

  Widget _buildCommentCard(
    BuildContext context,
    ThemeData theme,
    CommunityCommentModel comment, {
    bool isReply = false,
  }) {
    final bool isBusy = _togglingCommentLikes.contains(comment.id);
    final bool isOwner = _isCommentOwner(comment);

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
            onTap: () => _openProfile(comment.authorId, comment.authorName),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          comment.authorName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _formatTime(comment.createdAt),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (isOwner)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editComment(comment);
                        } else if (value == 'delete') {
                          _deleteComment(comment);
                        }
                      },
                      itemBuilder: (context) => const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  IconButton(
                    tooltip: 'Copy comment',
                    onPressed: () =>
                        _copyToClipboard(comment.message, 'Comment copied'),
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  IconButton(
                    onPressed: isBusy ? null : () => _toggleCommentLike(comment.id),
                    icon: Icon(
                      comment.likedByMe ? Icons.favorite : Icons.favorite_border,
                    ),
                  ),
                  Text('${comment.likeCount}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(comment.message, style: theme.textTheme.bodyMedium),
          if (!isReply) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _setReplyTarget(comment),
                icon: const Icon(Icons.reply_outlined),
                label: const Text('Reply'),
              ),
            ),
          ],
        ],
      ),
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
        actions: post == null || !_isPostOwner(post)
            ? null
            : <Widget>[
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editPost(post);
                    } else if (value == 'delete') {
                      _deletePost(post);
                    }
                  },
                  itemBuilder: (context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit post'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete post'),
                    ),
                  ],
                ),
              ],
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
                            SelectableText(
                              post.bodyText.isNotEmpty
                                  ? post.bodyText
                                  : post.plainText,
                              style: theme.textTheme.bodyLarge,
                            ),
                            if (post.imageUrls.isNotEmpty ||
                                (post.primaryImageUrl?.isNotEmpty ??
                                    false)) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 220,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: post.imageUrls.isNotEmpty
                                      ? post.imageUrls.length
                                      : 1,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final imageUrl = post.imageUrls.isNotEmpty
                                        ? post.imageUrls[index]
                                        : post.primaryImageUrl!;
                                    return GestureDetector(
                                      onTap: () => _openImageLightbox(imageUrl),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
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
                                  icon: const Icon(Icons.mode_comment_outlined),
                                  label: Text('${post.commentCount}'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: null,
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: Text('${post.viewCount}'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _copyToClipboard(
                                    post.bodyText.isNotEmpty
                                        ? post.bodyText
                                        : post.plainText,
                                    'Post copied',
                                  ),
                                  icon: const Icon(Icons.copy_outlined),
                                  label: const Text('Copy'),
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
                          if (_replyToCommentId != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'Replying to ${_replyToCommentAuthor ?? 'comment'}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _clearReplyTarget,
                                    icon: const Icon(Icons.close, size: 18),
                                    tooltip: 'Cancel reply',
                                  ),
                                ],
                              ),
                            ),
                          TextField(
                            controller: _commentController,
                            enableInteractiveSelection: true,
                            minLines: 3,
                            maxLines: 6,
                            decoration: InputDecoration(
                              hintText: _replyToCommentId == null
                                  ? 'Write a comment'
                                  : 'Write a reply',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _isSendingComment
                                  ? null
                                  : _submitComment,
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
                      ..._topLevelComments.map((CommunityCommentModel comment) {
                        final List<CommunityCommentModel> replies =
                            _childRepliesFor(comment.id);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _buildCommentCard(context, theme, comment),
                            if (replies.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 22),
                                child: Column(
                                  children: replies
                                      .map(
                                        (CommunityCommentModel reply) =>
                                            _buildCommentCard(
                                              context,
                                              theme,
                                              reply,
                                              isReply: true,
                                            ),
                                      )
                                      .toList(),
                                ),
                              ),
                          ],
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}
