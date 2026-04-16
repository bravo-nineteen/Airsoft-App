import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import 'community_create_post_screen.dart';
import 'community_model.dart';
import 'community_post_details_screen.dart';
import 'community_repository.dart';
import 'community_rich_text.dart';

class CommunityListScreen extends StatefulWidget {
  const CommunityListScreen({super.key});

  @override
  State<CommunityListScreen> createState() => _CommunityListScreenState();
}

class _CommunityListScreenState extends State<CommunityListScreen> {
  final CommunityRepository _repository = CommunityRepository();
  final TextEditingController _searchController = TextEditingController();

  String _languageCode = 'en';
  String _category = 'all';

  late Future<List<CommunityModel>> _future;

  static const List<String> _categories = [
    'all',
    'meetups',
    'tech-talk',
    'troubleshooting',
    'events',
    'off-topic',
    'memes',
    'buy-sell',
    'gear-showcase',
    'field-talk',
  ];

  @override
  void initState() {
    super.initState();
    _future = _loadPosts();
  }

  Future<List<CommunityModel>> _loadPosts() {
    return _repository.getPosts(
      languageCode: _languageCode,
      category: _category,
      search: _searchController.text,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadPosts();
    });
    await _future;
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CommunityCreatePostScreen()),
    );
    if (created == true) {
      await _refresh();
    }
  }

  String _categoryLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'all':
        return l10n.t('all');
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _avatar(CommunityModel post) {
    if (post.hasAvatar) {
      return CircleAvatar(
        backgroundImage: NetworkImage(post.avatarUrl!),
      );
    }

    return CircleAvatar(
      child: Text(
        post.displayName.isEmpty ? '?' : post.displayName.characters.first.toUpperCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: SafeArea(
        minimum: const EdgeInsets.only(right: 16, bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: _openCreate,
          icon: const Icon(Icons.add),
          label: Text(l10n.t('post')),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(
                      value: 'en',
                      label: Text(l10n.t('english')),
                    ),
                    ButtonSegment<String>(
                      value: 'ja',
                      label: Text('日本語'),
                    ),
                  ],
                  selected: {_languageCode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _languageCode = selection.first;
                      _future = _loadPosts();
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.t('searchPosts'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                  onSubmitted: (_) => _refresh(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final value = _categories[index];
                      final selected = _category == value;

                      return ChoiceChip(
                        label: Text(_categoryLabel(l10n, value)),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _category = value;
                            _future = _loadPosts();
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<CommunityModel>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        const SizedBox(height: 160),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l10n.t(
                                'failedLoadBoard',
                                args: {'error': '${snapshot.error}'},
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  final posts = snapshot.data ?? [];
                  if (posts.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(height: 160),
                        Center(child: Text(l10n.t('noPostsFound'))),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: posts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CommunityPostDetailsScreen(post: post),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _avatar(post),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${post.displayName} • ${_timeLabel(l10n, post.updatedAt)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(_categoryLabel(l10n, post.category)),
                                    ),
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(_languageLabel(l10n, post.languageCode)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                CommunityRichText(
                                  text: post.body,
                                  maxLines: 3,
                                ),
                                if (post.hasImage) ...[
                                  const SizedBox(height: 12),
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
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}