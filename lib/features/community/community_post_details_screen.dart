import 'package:flutter/material.dart';

import 'community_comment_model.dart';
import 'community_comment_repository.dart';
import 'community_model.dart';

class CommunityPostDetailsScreen extends StatefulWidget {
  const CommunityPostDetailsScreen({
    super.key,
    required this.post,
  });

  final CommunityModel post;

  @override
  State<CommunityPostDetailsScreen> createState() =>
      _CommunityPostDetailsScreenState();
}

class _CommunityPostDetailsScreenState
    extends State<CommunityPostDetailsScreen> {
  final CommunityCommentRepository _repository = CommunityCommentRepository();
  final TextEditingController _commentController = TextEditingController();

  late Future<List<CommunityCommentModel>> _futureComments;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _futureComments = _repository.getComments(widget.post.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _futureComments = _repository.getComments(widget.post.id);
    });
    await _futureComments;
  }

  Future<void> _sendComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) {
      return;
    }

    setState(() => _isSending = true);

    try {
      await _repository.addComment(
        postId: widget.post.id,
        body: body,
      );
      _commentController.clear();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send comment: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _categoryLabel(String value) {
    switch (value) {
      case 'meetups':
        return 'Meetups';
      case 'tech-talk':
        return 'Tech Talk';
      case 'troubleshooting':
        return 'Troubleshooting';
      case 'events':
        return 'Events';
      case 'off-topic':
        return 'Off-topic';
      case 'memes':
        return 'Memes';
      case 'buy-sell':
        return 'Buy / Sell';
      case 'gear-showcase':
        return 'Gear Showcase';
      case 'field-talk':
        return 'Field Talk';
      default:
        return value;
    }
  }

  String _languageLabel(String code) {
    return code == 'ja' ? '日本語' : 'English';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Scaffold(
      appBar: AppBar(title: Text(post.title)),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<CommunityCommentModel>>(
                future: _futureComments,
                builder: (context, snapshot) {
                  final comments = snapshot.data ?? [];

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(label: Text(_categoryLabel(post.category))),
                                  Chip(label: Text(_languageLabel(post.languageCode))),
                                  if ((post.callSign ?? '').isNotEmpty)
                                    Chip(label: Text(post.callSign!)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(post.body),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Comments',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (comments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No comments yet.')),
                        ),
                      ...comments.map(
                        (comment) => Card(
                          child: ListTile(
                            title: Text(comment.callSign ?? 'Operator'),
                            subtitle: Text(comment.body),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSending ? null : _sendComment,
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
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
}