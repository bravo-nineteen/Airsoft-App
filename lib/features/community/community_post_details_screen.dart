import 'package:extended_image/extended_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_model.dart';
import 'community_user_profile_screen.dart';
import 'community_repository.dart';

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
    final _ = fallbackName;
    if (userId == null || userId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile not available')),
      );
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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          IconButton(
            tooltip: 'Copy post',
            onPressed: post == null ? null : () => _copyPost(post),
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: _isLoading
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
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          children: [
                            _PostHeader(
                              post: post,
                              onAuthorTap: () =>
                                  _openProfile(post.authorId, post.authorName),
                              timeLabel: _formatDateTime(post.createdAt),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _postBody(post),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge,
                                    ),
                                    if (post.imageUrls.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      ...post.imageUrls.map(
                                        (imageUrl) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: AspectRatio(
                                              aspectRatio: 16 / 9,
                                              child: ExtendedImage.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                cache: true,
                                                loadStateChanged: (state) {
                                                  if (state
                                                          .extendedImageLoadState ==
                                                      LoadState.completed) {
                                                    return ExtendedRawImage(
                                                      image: state
                                                          .extendedImageInfo
                                                          ?.image,
                                                      fit: BoxFit.cover,
                                                    );
                                                  }

                                                  if (state
                                                          .extendedImageLoadState ==
                                                      LoadState.failed) {
                                                    return Container(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainerHighest,
                                                      alignment: Alignment.center,
                                                      child: const Icon(Icons
                                                          .broken_image_outlined),
                                                    );
                                                  }

                                                  return const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 6,
                                      children: [
                                        _MetricPill(
                                          icon: Icons
                                              .mode_comment_outlined,
                                          value: '${post.commentCount}',
                                        ),
                                        _MetricPill(
                                          icon: Icons.visibility_outlined,
                                          value: '${post.viewCount}',
                                        ),
                                        TextButton.icon(
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
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Comments (${_comments.length})',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            if (_comments.isEmpty)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Text(
                                    'No comments yet',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              )
                            else
                              ..._comments.map((comment) {
                                final isToggling =
                                    _togglingCommentLikes.contains(comment.id);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        InkWell(
                                          onTap: () => _openProfile(
                                            comment.authorId,
                                            comment.authorName,
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundImage: comment
                                                            .authorAvatarUrl !=
                                                        null
                                                    ? NetworkImage(comment
                                                        .authorAvatarUrl!)
                                                    : null,
                                                child: comment.authorAvatarUrl ==
                                                            null ||
                                                        comment.authorAvatarUrl!
                                                            .trim()
                                                            .isEmpty
                                                    ? Text(comment.authorName
                                                            .isEmpty
                                                        ? '?'
                                                        : comment.authorName[0]
                                                            .toUpperCase())
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  comment.authorName,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelLarge,
                                                ),
                                              ),
                                              Text(
                                                _formatDateTime(
                                                  comment.createdAt,
                                                ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(comment.message),
                                        const SizedBox(height: 6),
                                        TextButton.icon(
                                          onPressed: isToggling
                                              ? null
                                              : () => _toggleCommentLike(
                                                    comment.id,
                                                  ),
                                          icon: Icon(
                                            comment.likedByMe
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            size: 18,
                                          ),
                                          label: Text('${comment.likeCount}'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                minLines: 1,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  hintText: 'Write a comment',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed:
                                  _isSendingComment ? null : _submitComment,
                              child: _isSendingComment
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : const Text('Send'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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

