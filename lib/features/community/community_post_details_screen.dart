import 'package:extended_image/extended_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
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
  RealtimeChannel? _postChannel;
  RealtimeChannel? _commentsChannel;

  CommunityPostModel? _post;
  List<CommunityCommentModel> _comments = <CommunityCommentModel>[];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSendingComment = false;
  bool _isTogglingPostLike = false;
  bool _showAllComments = false;
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
    _subscribeRealtime();
    _load(incrementView: true);
  }

  void _subscribeRealtime() {
    _postChannel = Supabase.instance.client.channel(
      'community-post-${widget.postId}',
    );
    _commentsChannel = Supabase.instance.client.channel(
      'community-comments-${widget.postId}',
    );

    _postChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'community_posts',
          callback: (payload) {
            final String id = payload.newRecord['id']?.toString() ?? '';
            if (id == widget.postId) {
              _applyRealtimePost(payload.newRecord);
            }
          },
        )
        .subscribe();

    _commentsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'community_comments',
          callback: (payload) {
            _applyRealtimeComment(payload.newRecord, isInsert: true);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'community_comments',
          callback: (payload) {
            _applyRealtimeComment(payload.newRecord, isInsert: false);
          },
        )
        .subscribe();
  }

  void _applyRealtimePost(Map<String, dynamic> row) {
    if (!mounted || _post == null) {
      return;
    }

    final CommunityPostModel parsed = CommunityPostModel.fromJson(row);
    setState(() {
      _post = _post!.copyWith(
        title: parsed.title,
        bodyText: parsed.bodyText,
        plainText: parsed.plainText,
        imageUrl: parsed.imageUrl,
        imageUrls: parsed.imageUrls,
        category: parsed.category,
        likeCount: parsed.likeCount,
        commentCount: parsed.commentCount,
        viewCount: parsed.viewCount,
        updatedAt: parsed.updatedAt,
      );
    });
  }

  void _applyRealtimeComment(Map<String, dynamic> row, {required bool isInsert}) {
    if (!mounted) {
      return;
    }

    final String postId = row['post_id']?.toString() ?? '';
    if (postId != widget.postId) {
      return;
    }

    final CommunityCommentModel incoming = CommunityCommentModel.fromJson(row);
    final bool isDeleted = row['is_deleted'] == true;

    setState(() {
      final int existingIndex = _comments.indexWhere(
        (CommunityCommentModel c) => c.id == incoming.id,
      );

      if (isDeleted) {
        _comments = _comments
            .where((CommunityCommentModel c) => c.id != incoming.id)
            .toList();
        return;
      }

      if (existingIndex != -1) {
        _comments[existingIndex] = _comments[existingIndex].copyWith(
          message: incoming.message,
          likeCount: incoming.likeCount,
          likedByMe: _comments[existingIndex].likedByMe,
          parentCommentId: incoming.parentCommentId,
        );
        return;
      }

      if (!isInsert) {
        return;
      }

      final int tempIndex = _comments.indexWhere(
        (CommunityCommentModel c) =>
            c.id.startsWith('temp-') &&
            c.parentCommentId == incoming.parentCommentId &&
            c.message.trim() == incoming.message.trim(),
      );

      if (tempIndex != -1) {
        _comments[tempIndex] = incoming;
      } else {
        _comments = <CommunityCommentModel>[..._comments, incoming];
      }
    });
  }

  Future<void> _load({bool incrementView = false, bool preserveContent = true}) async {
    setState(() {
      if (_post == null || !preserveContent) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
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
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
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

    final String tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    final CommunityCommentModel optimistic = CommunityCommentModel(
      id: tempId,
      postId: _post!.id,
      authorId: user.id,
      authorName: 'You',
      authorAvatarUrl: null,
      message: message,
      likeCount: 0,
      likedByMe: false,
      createdAt: DateTime.now(),
      parentCommentId: _replyToCommentId,
    );

    setState(() {
      _isSendingComment = true;
      _comments = <CommunityCommentModel>[..._comments, optimistic];
      _post = _post?.copyWith(commentCount: (_post?.commentCount ?? 0) + 1);
      _commentController.clear();
      _replyToCommentId = null;
      _replyToCommentAuthor = null;
    });

    try {
      await _repository.addComment(
        postId: _post!.id,
        message: message,
        parentCommentId: optimistic.parentCommentId,
      );

      if (!mounted) {
        return;
      }

      // Background reconcile to pick up canonical author/ids without blocking UI.
      _load(preserveContent: true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _comments = _comments
            .where((CommunityCommentModel c) => c.id != tempId)
            .toList();
        final int currentCount = _post?.commentCount ?? 1;
        _post = _post?.copyWith(
          commentCount: currentCount > 0 ? currentCount - 1 : 0,
        );
      });

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
    final _ = fallbackName;
    if (userId == null || userId.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile not available')));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityUserProfileScreen(
          userId: userId,
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
                          _formatDateTime(comment.createdAt),
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
    if (_postChannel != null) {
      Supabase.instance.client.removeChannel(_postChannel!);
    }
    if (_commentsChannel != null) {
      Supabase.instance.client.removeChannel(_commentsChannel!);
    }
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final bool hasMediaTab = post != null && post.imageUrls.isNotEmpty;
    final Widget body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : post == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Post not found'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  if (_isRefreshing)
                    const LinearProgressIndicator(minHeight: 2),
                  if (hasMediaTab)
                    const TabBar(
                      tabs: <Tab>[Tab(text: 'Discussion'), Tab(text: 'Media')],
                    ),
                  Expanded(
                    child: hasMediaTab
                        ? TabBarView(
                            children: <Widget>[
                              _buildDiscussionTab(post),
                              _buildMediaTab(post),
                            ],
                          )
                        : _buildDiscussionTab(post),
                  ),
                  _buildCommentComposer(),
                ],
              );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          IconButton(
            tooltip: 'Copy post',
            onPressed: post == null ? null : () => _copyPost(post),
            icon: const Icon(Icons.copy_all_outlined),
          ),
          if (post != null && _isPostOwner(post))
            PopupMenuButton<String>(
              onSelected: (String value) {
                if (value == 'edit') {
                  _editPost(post);
                } else if (value == 'delete') {
                  _deletePost(post);
                }
              },
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: hasMediaTab
          ? DefaultTabController(length: 2, child: body)
          : body,
    );
  }

  Widget _buildDiscussionTab(CommunityPostModel post) {
    final ThemeData theme = Theme.of(context);
    final List<CommunityCommentModel> topLevelComments = _topLevelComments;
    final List<CommunityCommentModel> visibleTopLevel = _showAllComments
        ? topLevelComments
        : topLevelComments.take(10).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: <Widget>[
          _PostHeader(
            post: post,
            onAuthorTap: () => _openProfile(post.authorId, post.authorName),
            timeLabel: _formatDateTime(post.createdAt),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    post.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(_postBody(post), style: theme.textTheme.bodyLarge),
                  if (post.imageUrls.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        DefaultTabController.of(context).animateTo(1);
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text('Open media (${post.imageUrls.length})'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: <Widget>[
                      _MetricPill(
                        icon: Icons.mode_comment_outlined,
                        value: '${post.commentCount}',
                      ),
                      _MetricPill(
                        icon: Icons.visibility_outlined,
                        value: '${post.viewCount}',
                      ),
                      TextButton.icon(
                        onPressed: _isTogglingPostLike ? null : _togglePostLike,
                        icon: Icon(
                          post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                        ),
                        label: Text('${post.likeCount}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Comments (${_comments.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (_comments.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text('No comments yet', style: theme.textTheme.bodyMedium),
              ),
            )
          else ...<Widget>[
            ...visibleTopLevel.map((CommunityCommentModel comment) {
              final List<CommunityCommentModel> replies = _childRepliesFor(comment.id);
              return Column(
                children: <Widget>[
                  _buildCommentCard(context, theme, comment),
                  ...replies.map(
                    (CommunityCommentModel reply) => Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: _buildCommentCard(
                        context,
                        theme,
                        reply,
                        isReply: true,
                      ),
                    ),
                  ),
                ],
              );
            }),
            if (topLevelComments.length > visibleTopLevel.length)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAllComments = true;
                    });
                  },
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Show all threads'),
                ),
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMediaTab(CommunityPostModel post) {
    if (post.imageUrls.isEmpty) {
      return const Center(child: Text('No images attached to this post.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      itemCount: post.imageUrls.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (BuildContext context, int index) {
        final String imageUrl = post.imageUrls[index];
        return InkWell(
          onTap: () => _openImageLightbox(imageUrl),
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ExtendedImage.network(
              imageUrl,
              fit: BoxFit.cover,
              cache: true,
              loadStateChanged: (state) {
                if (state.extendedImageLoadState == LoadState.completed) {
                  return ExtendedRawImage(
                    image: state.extendedImageInfo?.image,
                    fit: BoxFit.cover,
                  );
                }

                if (state.extendedImageLoadState == LoadState.failed) {
                  return Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  );
                }

                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_replyToCommentId != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Replying to ${_replyToCommentAuthor ?? 'comment'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: _clearReplyTarget,
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel reply',
                    ),
                  ],
                ),
              ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'Write a comment'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSendingComment ? null : _submitComment,
                  child: _isSendingComment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _postBody(CommunityPostModel post) {
    final body = post.bodyText.trim();
    if (body.isNotEmpty) {
      return body;
    }
    final plain = post.plainText.trim();
    if (plain.isNotEmpty) {
      return plain;
    }
    return 'No content available.';
  }

  String _formatDateTime(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }

  Future<void> _copyPost(CommunityPostModel post) async {
    final text = StringBuffer()
      ..writeln(post.title)
      ..writeln()
      ..writeln(_postBody(post))
      ..writeln()
      ..writeln('Author: ${post.authorName}')
      ..writeln('Posted: ${_formatDateTime(post.createdAt)}');

    await Clipboard.setData(ClipboardData(text: text.toString().trim()));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Full post copied to clipboard')),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({
    required this.post,
    required this.onAuthorTap,
    required this.timeLabel,
  });

  final CommunityPostModel post;
  final VoidCallback onAuthorTap;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAuthorTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundImage: post.authorAvatarUrl != null &&
                      post.authorAvatarUrl!.trim().isNotEmpty
                  ? NetworkImage(post.authorAvatarUrl!)
                  : null,
              child: post.authorAvatarUrl == null ||
                      post.authorAvatarUrl!.trim().isEmpty
                  ? Text(
                      post.authorName.isEmpty
                          ? '?'
                          : post.authorName.substring(0, 1).toUpperCase(),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                post.authorName,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Text(
              timeLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

}

