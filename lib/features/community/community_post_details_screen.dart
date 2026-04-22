import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../safety/safety_repository.dart';
import 'community_model.dart';
import 'community_image_service.dart';
import 'community_repository.dart';
import 'community_user_profile_screen.dart';

enum _CommentSortMode { mostRecent, allComments, popularComments }

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
  final SafetyRepository _safetyRepository = SafetyRepository();
  final CommunityImageService _imageService = CommunityImageService();
  final TextEditingController _commentController = TextEditingController();
  Timer? _commentDraftSaveDebounce;
  RealtimeChannel? _postChannel;
  RealtimeChannel? _commentsChannel;

  CommunityPostModel? _post;
  List<CommunityCommentModel> _comments = <CommunityCommentModel>[];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSendingComment = false;
  bool _isTogglingPostLike = false;
  bool _isVotingPoll = false;
  bool _showAllComments = false;
  _CommentSortMode _commentSortMode = _CommentSortMode.mostRecent;
  final Set<String> _togglingCommentLikes = <String>{};
  String? _replyToCommentId;
  String? _replyToCommentAuthor;
  String? _pendingCommentImageUrl;
  CommunityPostPoll? _postPoll;
  Set<String> _pendingPollSelections = <String>{};
  bool _isHydratingCommentDraft = false;

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

  List<CommunityCommentModel> get _sortedTopLevelComments {
    final List<CommunityCommentModel> comments = _topLevelComments.toList();
    final Map<String, List<CommunityCommentModel>> descendantsById =
        <String, List<CommunityCommentModel>>{
          for (final CommunityCommentModel comment in comments)
            comment.id: _descendantsFor(comment.id),
        };

    comments.sort((CommunityCommentModel left, CommunityCommentModel right) {
      final List<CommunityCommentModel> leftDescendants =
          descendantsById[left.id] ?? <CommunityCommentModel>[];
      final List<CommunityCommentModel> rightDescendants =
          descendantsById[right.id] ?? <CommunityCommentModel>[];

      switch (_commentSortMode) {
        case _CommentSortMode.mostRecent:
          return _threadLatestActivity(right, rightDescendants).compareTo(
            _threadLatestActivity(left, leftDescendants),
          );
        case _CommentSortMode.allComments:
          return left.createdAt.compareTo(right.createdAt);
        case _CommentSortMode.popularComments:
          final int popularityDelta =
              _threadPopularity(right, rightDescendants) -
              _threadPopularity(left, leftDescendants);
          if (popularityDelta != 0) {
            return popularityDelta;
          }
          return _threadLatestActivity(right, rightDescendants).compareTo(
            _threadLatestActivity(left, leftDescendants),
          );
      }
    });

    return comments;
  }

  List<CommunityCommentModel> _childRepliesFor(String parentCommentId) {
    return _comments
        .where((CommunityCommentModel comment) {
          final String? parentId = comment.parentCommentId?.trim();
          return parentId != null && parentId == parentCommentId;
        })
        .toList();
  }

  List<CommunityCommentModel> _sortedRepliesFor(String parentCommentId) {
    final List<CommunityCommentModel> replies =
        _childRepliesFor(parentCommentId).toList();
    replies.sort(
      (CommunityCommentModel left, CommunityCommentModel right) =>
          left.createdAt.compareTo(right.createdAt),
    );
    return replies;
  }

  List<CommunityCommentModel> _descendantsFor(String rootCommentId) {
    final List<CommunityCommentModel> descendants = <CommunityCommentModel>[];
    final List<String> pendingIds = <String>[rootCommentId];

    while (pendingIds.isNotEmpty) {
      final String parentId = pendingIds.removeLast();
      final List<CommunityCommentModel> directReplies =
          _sortedRepliesFor(parentId);
      descendants.addAll(directReplies);
      pendingIds.addAll(
        directReplies.map((CommunityCommentModel reply) => reply.id),
      );
    }

    return descendants;
  }

  CommunityCommentModel? _commentById(String commentId) {
    for (final CommunityCommentModel comment in _comments) {
      if (comment.id == commentId) {
        return comment;
      }
    }
    return null;
  }

  String? _parentAuthorNameFor(CommunityCommentModel comment) {
    final String? parentCommentId = comment.parentCommentId?.trim();
    if (parentCommentId == null || parentCommentId.isEmpty) {
      return null;
    }

    return _commentById(parentCommentId)?.authorName;
  }

  DateTime _threadLatestActivity(
    CommunityCommentModel rootComment,
    List<CommunityCommentModel> descendants,
  ) {
    DateTime latest = rootComment.createdAt;
    for (final CommunityCommentModel reply in descendants) {
      if (reply.createdAt.isAfter(latest)) {
        latest = reply.createdAt;
      }
    }
    return latest;
  }

  int _threadPopularity(
    CommunityCommentModel rootComment,
    List<CommunityCommentModel> descendants,
  ) {
    final int replyLikes = descendants.fold<int>(
      0,
      (int total, CommunityCommentModel reply) => total + reply.likeCount,
    );
    return rootComment.likeCount + replyLikes + (descendants.length * 2);
  }

  void _setCommentSortMode(_CommentSortMode mode) {
    if (_commentSortMode == mode) {
      return;
    }

    setState(() {
      _commentSortMode = mode;
      _showAllComments = false;
    });
  }

  String _commentSortLabel(_CommentSortMode mode, AppLocalizations l10n) {
    switch (mode) {
      case _CommentSortMode.mostRecent:
        return l10n.t('mostRecentComments');
      case _CommentSortMode.allComments:
        return l10n.t('allComments');
      case _CommentSortMode.popularComments:
        return l10n.t('popularComments');
    }
  }

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_scheduleCommentDraftSave);
    _subscribeRealtime();
    _hydrateCommentDraft();
    _load(incrementView: true);
  }

  Future<void> _hydrateCommentDraft() async {
    _isHydratingCommentDraft = true;
    try {
      final Map<String, dynamic>? draft = await _repository.getCommentDraft(
        threadType: 'community_post',
        threadId: widget.postId,
      );
      if (!mounted || draft == null) {
        return;
      }

      final String bodyText = (draft['body_text'] ?? '').toString();
      final String? parentCommentId = draft['parent_comment_id']?.toString();
      _commentController.text = bodyText;
      if ((parentCommentId ?? '').trim().isNotEmpty) {
        _replyToCommentId = parentCommentId;
        final CommunityCommentModel? parent = _commentById(parentCommentId!);
        _replyToCommentAuthor = parent?.authorName;
      }
      setState(() {});
    } catch (_) {
      // Keep compose usable even if draft hydration fails.
    } finally {
      _isHydratingCommentDraft = false;
    }
  }

  void _scheduleCommentDraftSave() {
    if (_isHydratingCommentDraft) {
      return;
    }

    _commentDraftSaveDebounce?.cancel();
    _commentDraftSaveDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_saveCommentDraft());
    });
  }

  Future<void> _saveCommentDraft() async {
    if (_isSendingComment) {
      return;
    }

    final String bodyText = _commentController.text.trim();
    final bool hasContent =
        bodyText.isNotEmpty || (_replyToCommentId ?? '').trim().isNotEmpty;

    if (!hasContent) {
      await _repository.clearCommentDraft(
        threadType: 'community_post',
        threadId: widget.postId,
      );
      return;
    }

    await _repository.saveCommentDraft(
      threadType: 'community_post',
      threadId: widget.postId,
      bodyText: bodyText,
      parentCommentId: _replyToCommentId,
    );
  }

  Future<void> _clearCommentDraft() {
    return _repository.clearCommentDraft(
      threadType: 'community_post',
      threadId: widget.postId,
    );
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
          imageUrl: incoming.imageUrl,
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
    final AppLocalizations l10n = AppLocalizations.of(context);
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

      final List<dynamic> loaded = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.fetchPostById(widget.postId),
        _repository.fetchComments(widget.postId),
        _repository.fetchPostPoll(widget.postId),
      ]);
      final CommunityPostModel post = loaded[0] as CommunityPostModel;
      final List<CommunityCommentModel> comments =
          loaded[1] as List<CommunityCommentModel>;
      final CommunityPostPoll? poll = loaded[2] as CommunityPostPoll?;

      if (!mounted) {
        return;
      }

      setState(() {
        _post = post;
        _comments = comments;
        _postPoll = poll;
        _pendingPollSelections = poll == null
            ? <String>{}
            : Set<String>.from(poll.selectedOptionIds);
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
      ).showSnackBar(
        SnackBar(content: Text(l10n.t('failedLoadPost', args: {'error': '$error'}))),
      );
    }
  }

  Future<void> _submitComment() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final message = _commentController.text.trim();
    final String? pendingImageUrl = _pendingCommentImageUrl?.trim();
    if ((message.isEmpty && (pendingImageUrl == null || pendingImageUrl.isEmpty)) ||
        _post == null ||
        _isSendingComment) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('mustBeLoggedInToComment'))),
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
      imageUrl: pendingImageUrl,
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
      _pendingCommentImageUrl = null;
      _replyToCommentId = null;
      _replyToCommentAuthor = null;
    });
    unawaited(_clearCommentDraft());

    try {
      await _repository.addComment(
        postId: _post!.id,
        message: message,
        parentCommentId: optimistic.parentCommentId,
        imageUrl: pendingImageUrl,
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
        _pendingCommentImageUrl = pendingImageUrl;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(l10n.t('failedPostComment', args: {'error': '$error'}))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingComment = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadCommentImage() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_isSendingComment) {
      return;
    }

    try {
      final String? imageUrl = await _imageService.pickCropAndUploadCommunityImage(
        folder: 'comments',
      );
      if (!mounted || imageUrl == null || imageUrl.trim().isEmpty) {
        return;
      }

      setState(() {
        _pendingCommentImageUrl = imageUrl;
      });
      _scheduleCommentDraftSave();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(l10n.t('failedUploadImage', args: {'error': '$error'}))),
      );
    }
  }

  void _removePendingCommentImage() {
    final String? imageUrl = _pendingCommentImageUrl;
    setState(() {
      _pendingCommentImageUrl = null;
    });
    _scheduleCommentDraftSave();
    _imageService.deleteUploadedImageByPublicUrl(imageUrl);
  }

  Future<void> _togglePostLike() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
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
      ).showSnackBar(
        SnackBar(content: Text(l10n.t('failedUpdateLike', args: {'error': '$error'}))),
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
    final AppLocalizations l10n = AppLocalizations.of(context);
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
        SnackBar(
          content: Text(l10n.t('failedUpdateCommentLike', args: {'error': '$error'})),
        ),
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final titleController = TextEditingController(text: post.title);
    final bodyController = TextEditingController(text: post.bodyText);

    try {
      final bool? shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(l10n.t('editPost')),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: l10n.t('title')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bodyController,
                    minLines: 5,
                    maxLines: 10,
                    decoration: InputDecoration(labelText: l10n.t('content')),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.t('save')),
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
      ).showSnackBar(
        SnackBar(content: Text(l10n.t('failedUpdatePost', args: {'error': '$error'}))),
      );
    } finally {
      titleController.dispose();
      bodyController.dispose();
    }
  }

  Future<void> _deletePost(CommunityPostModel post) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.t('deletePostTitle')),
          content: Text(l10n.t('deletePostBody')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('delete')),
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
      ).showSnackBar(
        SnackBar(content: Text(l10n.t('failedDeletePost', args: {'error': '$error'}))),
      );
    }
  }

  Future<void> _editComment(CommunityCommentModel comment) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: comment.message);

    try {
      final bool? shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(l10n.t('editComment')),
            content: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(labelText: l10n.t('comment')),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.t('save')),
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
        SnackBar(content: Text(l10n.t('failedUpdateComment', args: {'error': '$error'}))),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteComment(CommunityCommentModel comment) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.t('deleteCommentTitle')),
          content: Text(l10n.t('deleteCommentBody')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('delete')),
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
        SnackBar(content: Text(l10n.t('failedDeleteComment', args: {'error': '$error'}))),
      );
    }
  }

  Future<void> _reportTarget({
    required String targetType,
    required String targetId,
  }) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('mustBeLoggedInToReport'))),
      );
      return;
    }

    String selectedReason = 'other';
    final TextEditingController detailsController = TextEditingController();
    final bool? shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(l10n.t('reportContent')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'spam', child: Text(l10n.t('reportReasonSpam'))),
                      DropdownMenuItem(value: 'harassment', child: Text(l10n.t('reportReasonHarassment'))),
                      DropdownMenuItem(value: 'hate', child: Text(l10n.t('reportReasonHate'))),
                      DropdownMenuItem(value: 'scam', child: Text(l10n.t('reportReasonScam'))),
                      DropdownMenuItem(value: 'other', child: Text(l10n.t('other'))),
                    ],
                    onChanged: (String? value) {
                      setState(() {
                        selectedReason = value ?? 'other';
                      });
                    },
                    decoration: InputDecoration(labelText: l10n.t('reason')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(labelText: l10n.t('detailsOptional')),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.t('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.t('submitReport')),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSubmit != true) {
      detailsController.dispose();
      return;
    }

    try {
      await _safetyRepository.submitReport(
        targetType: targetType,
        targetId: targetId,
        reasonCategory: selectedReason,
        details: detailsController.text,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('reportSubmitted'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('actionFailed', args: {'error': '$error'}))),
      );
    } finally {
      detailsController.dispose();
    }
  }

  Future<void> _blockUser(String userId) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('mustBeLoggedInToReport'))),
      );
      return;
    }
    try {
      await _safetyRepository.blockUser(userId);
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('userBlocked'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('actionFailed', args: {'error': '$error'}))),
      );
    }
  }

  Future<void> _muteUser(String userId) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('mustBeLoggedInToReport'))),
      );
      return;
    }
    try {
      await _safetyRepository.muteUser(userId);
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('userMuted'))),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('actionFailed', args: {'error': '$error'}))),
      );
    }
  }

  void _muteUserIfPresent(String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return;
    }
    _muteUser(userId);
  }

  void _blockUserIfPresent(String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return;
    }
    _blockUser(userId);
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
    _scheduleCommentDraftSave();
  }

  void _clearReplyTarget() {
    setState(() {
      _replyToCommentId = null;
      _replyToCommentAuthor = null;
    });
    _scheduleCommentDraftSave();
  }

  void _openProfile(String? userId, String fallbackName) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final _ = fallbackName;
    if (userId == null || userId.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('profileNotAvailable'))));
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

  void _openImageLightbox(List<String> imageUrls, {int initialIndex = 0}) {
    if (imageUrls.isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) {
        final int startIndex = initialIndex.clamp(0, imageUrls.length - 1);
        final PageController pageController = PageController(
          initialPage: startIndex,
        );

        return Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: <Widget>[
              ColoredBox(
                color: Colors.black,
                child: PageView.builder(
                  controller: pageController,
                  itemCount: imageUrls.length,
                  itemBuilder: (BuildContext context, int index) {
                    return InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: Center(
                        child: ExtendedImage.network(
                          imageUrls[index],
                          fit: BoxFit.contain,
                          cache: true,
                        ),
                      ),
                    );
                  },
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
              if (imageUrls.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        AppLocalizations.of(context).t('swipeForMore'),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isBusy = _togglingCommentLikes.contains(comment.id);
    final bool isOwner = _isCommentOwner(comment);
    final String? parentAuthorName =
        isReply ? _parentAuthorNameFor(comment) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReply
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: isReply
            ? Border(
                left: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.35),
                  width: 3,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (parentAuthorName != null) ...<Widget>[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 16,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.t('inReplyTo', args: {'name': parentAuthorName}),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                  PopupMenuButton<String>(
                    onSelected: (String value) {
                      if (value == 'edit') {
                        _editComment(comment);
                      } else if (value == 'delete') {
                        _deleteComment(comment);
                      } else if (value == 'report') {
                        _reportTarget(targetType: 'comment', targetId: comment.id);
                      } else if (value == 'block') {
                        _blockUserIfPresent(comment.authorId);
                      } else if (value == 'mute') {
                        _muteUserIfPresent(comment.authorId);
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      final List<PopupMenuEntry<String>> items = <PopupMenuEntry<String>>[];
                      if (isOwner) {
                        items.add(
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text(l10n.t('edit')),
                          ),
                        );
                        items.add(
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text(l10n.t('delete')),
                          ),
                        );
                      }
                      if (!isOwner) {
                        items.add(
                          PopupMenuItem<String>(
                            value: 'report',
                            child: Text(l10n.t('report')),
                          ),
                        );
                        items.add(
                          PopupMenuItem<String>(
                            value: 'mute',
                            child: Text(l10n.t('muteUser')),
                          ),
                        );
                        items.add(
                          PopupMenuItem<String>(
                            value: 'block',
                            child: Text(l10n.t('blockUser')),
                          ),
                        );
                      }
                      return items;
                    },
                  ),
                  IconButton(
                    tooltip: l10n.t('copyComment'),
                    onPressed: () =>
                        _copyToClipboard(comment.message, l10n.t('commentCopied')),
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
          if ((comment.imageUrl ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _openImageLightbox(
                <String>[comment.imageUrl!.trim()],
              ),
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: ExtendedImage.network(
                    comment.imageUrl!.trim(),
                    fit: BoxFit.cover,
                    cache: true,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _setReplyTarget(comment),
              icon: const Icon(Icons.reply_outlined),
              label: Text(l10n.t('reply')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentThread(
    BuildContext context,
    ThemeData theme,
    CommunityCommentModel comment, {
    int depth = 0,
  }) {
    final List<CommunityCommentModel> replies = _sortedRepliesFor(comment.id);
    final double leftInset = depth <= 0
        ? 0
        : depth >= 3
            ? 42
            : depth * 14;

    return Padding(
      padding: EdgeInsets.only(left: leftInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildCommentCard(
            context,
            theme,
            comment,
            isReply: depth > 0,
          ),
          ...replies.map(
            (CommunityCommentModel reply) => _buildCommentThread(
              context,
              theme,
              reply,
              depth: depth + 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSortChips(AppLocalizations l10n) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _CommentSortMode.values.map(( _CommentSortMode mode) {
        return ChoiceChip(
          label: Text(_commentSortLabel(mode, l10n)),
          selected: _commentSortMode == mode,
          onSelected: (_) => _setCommentSortMode(mode),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _commentDraftSaveDebounce?.cancel();
    _commentController.removeListener(_scheduleCommentDraftSave);
    unawaited(_saveCommentDraft());
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final post = _post;
    final bool hasMediaTab = post != null && post.imageUrls.isNotEmpty;
    final Widget body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : post == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.t('postNotFound')),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _load,
                      child: Text(l10n.t('retry')),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  if (_isRefreshing)
                    const LinearProgressIndicator(minHeight: 2),
                  if (hasMediaTab)
                    TabBar(
                      tabs: <Tab>[
                        Tab(text: l10n.t('discussion')),
                        Tab(text: l10n.t('media')),
                      ],
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
        title: Text(l10n.t('post')),
        actions: [
          IconButton(
            tooltip: l10n.t('copyPost'),
            onPressed: post == null ? null : () => _copyPost(post),
            icon: const Icon(Icons.copy_all_outlined),
          ),
          if (post != null)
            PopupMenuButton<String>(
              onSelected: (String value) {
                if (value == 'edit') {
                  _editPost(post);
                } else if (value == 'delete') {
                  _deletePost(post);
                } else if (value == 'report') {
                  _reportTarget(targetType: 'post', targetId: post.id);
                } else if (value == 'mute') {
                  _muteUserIfPresent(post.authorId);
                } else if (value == 'block') {
                  _blockUserIfPresent(post.authorId);
                }
              },
              itemBuilder: (_) {
                final bool isOwner = _isPostOwner(post);
                final List<PopupMenuEntry<String>> items = <PopupMenuEntry<String>>[];
                if (isOwner) {
                  items.add(
                    PopupMenuItem<String>(value: 'edit', child: Text(l10n.t('edit'))),
                  );
                  items.add(
                    PopupMenuItem<String>(value: 'delete', child: Text(l10n.t('delete'))),
                  );
                }
                if (!isOwner) {
                  items.add(
                    PopupMenuItem<String>(value: 'report', child: Text(l10n.t('report'))),
                  );
                  items.add(
                    PopupMenuItem<String>(value: 'mute', child: Text(l10n.t('muteUser'))),
                  );
                  items.add(
                    PopupMenuItem<String>(value: 'block', child: Text(l10n.t('blockUser'))),
                  );
                }
                return items;
              },
            ),
        ],
      ),
      body: hasMediaTab
          ? DefaultTabController(length: 2, child: body)
          : body,
    );
  }

  void _togglePollSelection(CommunityPostPoll poll, String optionId) {
    if (_isVotingPoll || poll.isExpired) {
      return;
    }

    setState(() {
      if (poll.allowMultiple) {
        if (_pendingPollSelections.contains(optionId)) {
          _pendingPollSelections.remove(optionId);
        } else {
          _pendingPollSelections.add(optionId);
        }
      } else {
        if (_pendingPollSelections.contains(optionId)) {
          _pendingPollSelections.clear();
        } else {
          _pendingPollSelections = <String>{optionId};
        }
      }
    });
  }

  Future<void> _submitPollVote(CommunityPostPoll poll) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_isVotingPoll || poll.isExpired) {
      return;
    }

    setState(() {
      _isVotingPoll = true;
    });

    try {
      await _repository.voteOnPostPoll(
        poll: poll,
        optionIds: _pendingPollSelections,
      );
      await _load(preserveContent: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('actionFailed', args: {'error': '$error'}))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVotingPoll = false;
        });
      }
    }
  }

  Widget _buildPollCard(CommunityPostPoll poll) {
    final ThemeData theme = Theme.of(context);
    final int totalVotes = poll.totalVotes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.poll_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poll.question,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...poll.options.map((CommunityPostPollOption option) {
              final bool selected = _pendingPollSelections.contains(option.id);
              final double percent = totalVotes == 0
                  ? 0
                  : option.voteCount / totalVotes;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _togglePollSelection(poll, option.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                      color: selected
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : theme.colorScheme.surface,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(child: Text(option.optionText)),
                            const SizedBox(width: 8),
                            Text('${option.voteCount}'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: percent,
                          minHeight: 6,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Text(
                  '$totalVotes votes',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                if (poll.isExpired)
                  Text(
                    'Closed',
                    style: theme.textTheme.bodySmall,
                  )
                else
                  FilledButton(
                    onPressed: _isVotingPoll ? null : () => _submitPollVote(poll),
                    child: _isVotingPoll
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Vote'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscussionTab(CommunityPostModel post) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final List<CommunityCommentModel> topLevelComments = _sortedTopLevelComments;
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
                    Text(
                      l10n.t('mediaWithCount', args: {'count': '${post.imageUrls.length}'}),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: post.imageUrls.length,
                        separatorBuilder: (_, index) => const SizedBox(width: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final String imageUrl = post.imageUrls[index];
                          return InkWell(
                            onTap: () => _openImageLightbox(
                              post.imageUrls,
                              initialIndex: index,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 120,
                                child: ExtendedImage.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  cache: true,
                                  loadStateChanged: (state) {
                                    if (state.extendedImageLoadState ==
                                        LoadState.completed) {
                                      return ExtendedRawImage(
                                        image: state.extendedImageInfo?.image,
                                        fit: BoxFit.cover,
                                      );
                                    }

                                    if (state.extendedImageLoadState ==
                                        LoadState.failed) {
                                      return Container(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.broken_image_outlined),
                                      );
                                    }

                                    return Container(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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
          if (_postPoll != null) ...<Widget>[
            const SizedBox(height: 12),
            _buildPollCard(_postPoll!),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.t('commentsWithCount', args: {'count': '${_comments.length}'}),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildCommentSortChips(l10n),
          const SizedBox(height: 10),
          if (_comments.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(l10n.t('noCommentsYet'), style: theme.textTheme.bodyMedium),
              ),
            )
          else ...<Widget>[
            ...visibleTopLevel.map((CommunityCommentModel comment) {
              return _buildCommentThread(
                context,
                theme,
                comment,
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
                  label: Text(l10n.t('showAllThreads')),
                ),
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMediaTab(CommunityPostModel post) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (post.imageUrls.isEmpty) {
      return Center(child: Text(l10n.t('noImagesAttachedToPost')));
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
          onTap: () => _openImageLightbox(
            post.imageUrls,
            initialIndex: index,
          ),
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
    final AppLocalizations l10n = AppLocalizations.of(context);
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
                        l10n.t(
                          'replyingTo',
                          args: {'name': _replyToCommentAuthor ?? l10n.t('comment')},
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: _clearReplyTarget,
                      icon: const Icon(Icons.close),
                      tooltip: l10n.t('cancelReply'),
                    ),
                  ],
                ),
              ),
            if ((_pendingCommentImageUrl ?? '').trim().isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: ExtendedImage.network(
                          _pendingCommentImageUrl!.trim(),
                          fit: BoxFit.cover,
                          cache: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _isSendingComment ? null : _removePendingCommentImage,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.t('removeImage')),
                    ),
                  ],
                ),
              ),
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: _isSendingComment ? null : _pickAndUploadCommentImage,
                  tooltip: l10n.t('uploadImage'),
                  icon: const Icon(Icons.image_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(hintText: l10n.t('writeComment')),
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
                      : Text(l10n.t('send')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _postBody(CommunityPostModel post) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final body = post.bodyText.trim();
    if (body.isNotEmpty) {
      return body;
    }
    final plain = post.plainText.trim();
    if (plain.isNotEmpty) {
      return plain;
    }
    return l10n.t('noContentAvailable');
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final text = StringBuffer()
      ..writeln(post.title)
      ..writeln()
      ..writeln(_postBody(post))
      ..writeln()
      ..writeln('${l10n.t('author')}: ${post.authorName}')
      ..writeln('${l10n.t('posted')}: ${_formatDateTime(post.createdAt)}');

    await Clipboard.setData(ClipboardData(text: text.toString().trim()));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.t('fullPostCopied'))),
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
          .withValues(alpha: 0.65),
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

