import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;

   