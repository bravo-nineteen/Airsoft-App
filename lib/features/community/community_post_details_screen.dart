import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import 'community_comment_model.dart';
import 'community_comment_repository.dart';
import 'community_model.dart';
import 'community_rich_text.dart';

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
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).t('failedSendComment', args: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _categoryLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'meetups':
        return l10n.t('meetupsLabel');
      case 'tech-talk':
        return l10n.t('techTalk');
      case 'troubleshooting':
        return l10n.t('troubleshooting');
      case 'events':
        return l10n.events;
      case 'off-topic':
        return l10n.t('offTopic');
      case 'memes':
        return l10n.t('memes');
      case 'buy-sell':
        return l10n.t('buySell');
      case 'gear-showcase':
        return l10n.t('gearShowcase');
      case 'field-talk':
        return l10n.t('fieldTalk');
      default:
        return value;
    }
  }

  String _languageLabel(AppLocalizations l10n, String code) {
    return code == 'ja' ? l10n.t('japanese') : l10n.t('english');
  }

  String _timeLabel(AppLocalizations l10n, DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);

    if (diff.inMinutes < 1) return l10n.t('justNow');
    if (diff.inMinutes < 60) {
      return l10n.t('minutesAgoShort', args: {'value': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return l10n.t('hoursAgoShort', args: {'value': '${diff.inHours}'});
    }
    return l10n.t('daysAgoShort', args: {'value': '${diff.inDays}'});
  }

  Widget _avatar({
    required String displayName,
    required String? avatarUrl,
  }) {
    if ((avatarUrl ?? '').trim().isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }

    return CircleAvatar(
      child: Text(
        displayName.isEmpty ? '?' : displayName.characters.first.toUpperCase(),
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
    final l10n = AppLocalizations.of(context);
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
                              Row(
                                children: [
                                  _avatar(
                                    displayName: post.displayName,
                                    avatarUrl: post.avatarUrl,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          post.displayName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _timeLabel(l10n, post.updatedAt),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(label: Text(_categoryLabel(l10n, post.category))),
                                  Chip(label: Text(_languageLabel(l10n, post.languageCode))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              CommunityRichText(text: post.body),
                              if (post.hasImage) ...[
                                const SizedBox(height: 14),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Image.network(
                                      post.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) {
                                        return Container(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.image_not_supported),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.t('comments'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (comments.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text(l10n.t('noCommentsYet'))),
                        ),
                      ...comments.map(
                        (comment) => Card(
                          child: ListTile(
                            leading: _avatar(
                              displayName: comment.displayName,
                              avatarUrl: comment.avatarUrl,
                            ),
                            title: Text(comment.displayName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                CommunityRichText(text: comment.body),
                                const SizedBox(height: 6),
                                Text(
                                  _timeLabel(l10n, comment.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
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
                      decoration: InputDecoration(
                        hintText: l10n.t('writeComment'),
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
                        : Text(l10n.t('send')),
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