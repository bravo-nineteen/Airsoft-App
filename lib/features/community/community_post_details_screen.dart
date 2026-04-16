import 'dart:convert';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_model.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _repository.incrementPostView(widget.postId);
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
      final profile = await _repository.fetchCurrentUserProfile();

      final displayName = (profile?['call_sign'] ??
        user.email ??
        'Unknown')
    .toString();

final avatarUrl = profile?['avatar_url']?.toString();

      await _repository.addComment(
        postId: _post!.id,
        authorId: user.id,
        authorName: displayName,
        authorAvatarUrl: avatarUrl,
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

  quill.QuillController _buildReadOnlyController(String bodyDeltaJson) {
    try {
      final decoded = jsonDecode(bodyDeltaJson) as Map<String, dynamic>;
      final document = quill.Document.fromJson(
        List<Map<String, dynamic>>.from(decoded['ops'] as List<dynamic>),
      );

      return quill.QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } catch (_) {
      final fallbackDoc = quill.Document()
        ..insert(0, 'Unable to display post body.');

      return quill.QuillController(
        document: fallbackDoc,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    }
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : post == null
              ? const Center(child: Text('Post not found'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: post.authorAvatarUrl != null &&
                                    post.authorAvatarUrl!.trim().isNotEmpty
                                ? NetworkImage(post.authorAvatarUrl!)
                                : null,
                            child: post.authorAvatarUrl == null ||
                                    post.authorAvatarUrl!.trim().isEmpty
                                ? Text(
                                    post.authorName.isEmpty
                                        ? '?'
                                        : post.authorName
                                            .substring(0, 1)
                                            .toUpperCase(),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  post.authorName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  DateFormat('dd MMM yyyy, HH:mm')
                                      .format(post.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if ((post.category ?? '').isNotEmpty)
                            Chip(
                              label: Text(post.category!),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        post.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 14),
                      if (post.imageUrls.isNotEmpty) ...<Widget>[
                        SizedBox(
                          height: 230,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: post.imageUrls.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (BuildContext context, int index) {
                              final imageUrl = post.imageUrls[index];

                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          CommunityImageViewerScreen(
                                        imageUrls: post.imageUrls,
                                        initialIndex: index,
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: SizedBox(
                                    width: 280,
                                    child: ExtendedImage.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      cache: true,
                                      loadStateChanged: (state) {
                                        if (state.extendedImageLoadState ==
                                            LoadState.completed) {
                                          return ExtendedRawImage(
                                            image:
                                                state.extendedImageInfo?.image,
                                            fit: BoxFit.cover,
                                          );
                                        }

                                        if (state.extendedImageLoadState ==
                                            LoadState.failed) {
                                          return Container(
                                            color: Colors.black12,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.broken_image_outlined,
                                            ),
                                          );
                                        }

                                        return Container(
                                          color: Colors.black12,
                                          alignment: Alignment.center,
                                          child:
                                              const CircularProgressIndicator(),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withOpacity(0.2),
                          ),
                        ),
                        child: quill.QuillEditor.basic(
                          controller:
                              _buildReadOnlyController(post.bodyDeltaJson),
                          config: const quill.QuillEditorConfig(
                            padding: EdgeInsets.zero,
                            enableInteractiveSelection: false,
                            scrollable: false,
                            showCursor: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: <Widget>[
                          _DetailsStat(
                            icon: Icons.mode_comment_outlined,
                            label: '${post.commentCount}',
                          ),
                          const SizedBox(width: 8),
                          _DetailsStat(
                            icon: Icons.visibility_outlined,
                            label: '${post.viewCount}',
                          ),
                          const SizedBox(width: 8),
                          _DetailsStat(
                            icon: Icons.favorite_border,
                            label: '${post.likeCount}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Comments',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Theme.of(context).colorScheme.surface,
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
                                    : const Icon(Icons.send_outlined),
                                label: const Text('Post comment'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_comments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('No comments yet'),
                        )
                      else
                        ..._comments.map((comment) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.18),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage:
                                      comment.authorAvatarUrl != null &&
                                              comment.authorAvatarUrl!
                                                  .trim()
                                                  .isNotEmpty
                                          ? NetworkImage(
                                              comment.authorAvatarUrl!,
                                            )
                                          : null,
                                  child: comment.authorAvatarUrl == null ||
                                          comment.authorAvatarUrl!
                                              .trim()
                                              .isEmpty
                                      ? Text(
                                          comment.authorName.isEmpty
                                              ? '?'
                                              : comment.authorName
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              comment.authorName,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                          Text(
                                            DateFormat('dd MMM HH:mm')
                                                .format(comment.createdAt),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(comment.message),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class _DetailsStat extends StatelessWidget {
  const _DetailsStat({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class CommunityImageViewerScreen extends StatefulWidget {
  const CommunityImageViewerScreen({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<CommunityImageViewerScreen> createState() =>
      _CommunityImageViewerScreenState();
}

class _CommunityImageViewerScreenState
    extends State<CommunityImageViewerScreen> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);

  late int _currentIndex = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1}/${widget.imageUrls.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (BuildContext context, int index) {
          return Center(
            child: ExtendedImage.network(
              widget.imageUrls[index],
              fit: BoxFit.contain,
              mode: ExtendedImageMode.gesture,
              cache: true,
            ),
          );
        },
      ),
    );
  }
}