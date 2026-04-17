import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

import '../community/community_list_screen.dart';
import '../community/community_model.dart';
import '../community/community_post_details_screen.dart';
import '../community/community_repository.dart';

enum HomeInterestFilter {
  all,
  posts,
  events,
  fields,
  blog,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CommunityRepository _communityRepository = CommunityRepository();

  List<CommunityPostModel> _latestPosts = <CommunityPostModel>[];
  bool _isLoading = true;
  HomeInterestFilter _selectedFilter = HomeInterestFilter.all;

  static const List<_HomeEventItem> _eventItems = <_HomeEventItem>[
    _HomeEventItem(
      title: 'Upcoming Skirmish Event',
      subtitle: 'Weekend game day and meet-up planning',
      meta: 'Events',
      icon: Icons.event_available,
    ),
    _HomeEventItem(
      title: 'Training Session',
      subtitle: 'Loadout prep, movement and team practice',
      meta: 'Training',
      icon: Icons.fitness_center,
    ),
  ];

  static const List<_HomeFieldUpdateItem> _fieldUpdateItems =
      <_HomeFieldUpdateItem>[
    _HomeFieldUpdateItem(
      title: 'Field Conditions Update',
      subtitle: 'Recent weather and playable area notes',
      meta: 'Field update',
      icon: Icons.terrain,
    ),
    _HomeFieldUpdateItem(
      title: 'Shop and Field Notices',
      subtitle: 'Check opening hours, stock and maintenance alerts',
      meta: 'Operations',
      icon: Icons.storefront,
    ),
  ];

  static const List<_HomeBlogItem> _blogItems = <_HomeBlogItem>[
    _HomeBlogItem(
      title: 'Airsoft Blog',
      subtitle: 'Guides, opinion pieces and longer-form reads',
      meta: 'Blog',
      icon: Icons.menu_book_outlined,
    ),
    _HomeBlogItem(
      title: 'Featured Articles',
      subtitle: 'Recommended reading for members and newcomers',
      meta: 'Featured',
      icon: Icons.article_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final posts = await _communityRepository.fetchPosts();

      if (!mounted) {
        return;
      }

      setState(() {
        _latestPosts = posts.take(6).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openPost(CommunityPostModel post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailsScreen(postId: post.id),
      ),
    );
  }

  void _openBoards() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CommunityListScreen(),
      ),
    );
  }

  void _setFilter(HomeInterestFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  String _filterTitle() {
    switch (_selectedFilter) {
      case HomeInterestFilter.all:
        return 'Member Feed';
      case HomeInterestFilter.posts:
        return 'Latest Posts';
      case HomeInterestFilter.events:
        return 'Events';
      case HomeInterestFilter.fields:
        return 'Field Updates';
      case HomeInterestFilter.blog:
        return 'Airsoft Blog';
    }
  }

  String _filterSubtitle() {
    switch (_selectedFilter) {
      case HomeInterestFilter.all:
        return 'A live overview of community activity, events and updates.';
      case HomeInterestFilter.posts:
        return 'Recent discussion and community posts.';
      case HomeInterestFilter.events:
        return 'Upcoming activity and event-related updates.';
      case HomeInterestFilter.fields:
        return 'Field conditions, notices and operational updates.';
      case HomeInterestFilter.blog:
        return 'Longer-form articles, guides and featured reads.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FieldOps'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadHomeData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: <Widget>[
                    _HomeHeroCard(
                      title: _filterTitle(),
                      subtitle: _filterSubtitle(),
                      onPrimaryTap: _openBoards,
                    ),
                    const SizedBox(height: 16),
                    _InterestSelector(
                      selectedFilter: _selectedFilter,
                      onSelected: _setFilter,
                    ),
                    const SizedBox(height: 18),
                    if (_selectedFilter == HomeInterestFilter.all ||
                        _selectedFilter == HomeInterestFilter.posts) ...[
                      _SectionHeader(
                        title: 'Recent Posts',
                        subtitle: 'What members are talking about now',
                        onViewAll: _openBoards,
                      ),
                      const SizedBox(height: 12),
                      if (_latestPosts.isEmpty)
                        const _EmptyBlock(
                          icon: Icons.forum_outlined,
                          text: 'No posts yet',
                        )
                      else
                        ..._latestPosts.map((CommunityPostModel post) {
                          return _HomePostCard(
                            post: post,
                            onTap: () => _openPost(post),
                          );
                        }),
                      const SizedBox(height: 20),
                    ],
                    if (_selectedFilter == HomeInterestFilter.all ||
                        _selectedFilter == HomeInterestFilter.events) ...[
                      _SectionHeader(
                        title: 'Events',
                        subtitle: 'Upcoming activities and group plans',
                        onViewAll: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Events screen not connected yet'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ..._eventItems.map(
                        (_HomeEventItem item) => _InfoFeedCard(
                          title: item.title,
                          subtitle: item.subtitle,
                          meta: item.meta,
                          icon: item.icon,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(item.title)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_selectedFilter == HomeInterestFilter.all ||
                        _selectedFilter == HomeInterestFilter.fields) ...[
                      _SectionHeader(
                        title: 'Field Updates',
                        subtitle: 'Conditions, notices and operational info',
                        onViewAll: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Field updates screen not connected yet'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ..._fieldUpdateItems.map(
                        (_HomeFieldUpdateItem item) => _InfoFeedCard(
                          title: item.title,
                          subtitle: item.subtitle,
                          meta: item.meta,
                          icon: item.icon,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(item.title)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_selectedFilter == HomeInterestFilter.all ||
                        _selectedFilter == HomeInterestFilter.blog) ...[
                      _SectionHeader(
                        title: 'Airsoft Blog',
                        subtitle: 'Guides, opinion and longer reads',
                        onViewAll: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Blog screen not connected yet'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ..._blogItems.map(
                        (_HomeBlogItem item) => _InfoFeedCard(
                          title: item.title,
                          subtitle: item.subtitle,
                          meta: item.meta,
                          icon: item.icon,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(item.title)),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _QuickAccessStrip(
                      theme: theme,
                      onBoardsTap: _openBoards,
                      onEventsTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Events screen not connected yet'),
                          ),
                        );
                      },
                      onFieldsTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Field finder screen not connected yet'),
                          ),
                        );
                      },
                      onBlogTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Blog screen not connected yet'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HomeHeroCard extends StatelessWidget {
  const _HomeHeroCard({
    required this.title,
    required this.subtitle,
    required this.onPrimaryTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.primaryContainer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.dynamic_feed_outlined,
            size: 30,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onPrimaryTap,
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Open Boards'),
          ),
        ],
      ),
    );
  }
}

class _InterestSelector extends StatelessWidget {
  const _InterestSelector({
    required this.selectedFilter,
    required this.onSelected,
  });

  final HomeInterestFilter selectedFilter;
  final ValueChanged<HomeInterestFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _InterestChip(
            label: 'All',
            selected: selectedFilter == HomeInterestFilter.all,
            onTap: () => onSelected(HomeInterestFilter.all),
          ),
          _InterestChip(
            label: 'Posts',
            selected: selectedFilter == HomeInterestFilter.posts,
            onTap: () => onSelected(HomeInterestFilter.posts),
          ),
          _InterestChip(
            label: 'Events',
            selected: selectedFilter == HomeInterestFilter.events,
            onTap: () => onSelected(HomeInterestFilter.events),
          ),
          _InterestChip(
            label: 'Fields',
            selected: selectedFilter == HomeInterestFilter.fields,
            onTap: () => onSelected(HomeInterestFilter.fields),
          ),
          _InterestChip(
            label: 'Blog',
            selected: selectedFilter == HomeInterestFilter.blog,
            onTap: () => onSelected(HomeInterestFilter.blog),
          ),
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.onViewAll,
  });

  final String title;
  final String subtitle;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          child: const Text('View all'),
        ),
      ],
    );
  }
}

class _HomePostCard extends StatelessWidget {
  const _HomePostCard({
    required this.post,
    required this.onTap,
  });

  final CommunityPostModel post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = post.primaryImageUrl;
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.dividerColor.withOpacity(0.14),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: hasImage
                      ? ExtendedImage.network(
                          imageUrl!,
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
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.forum_outlined,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        if ((post.category ?? '').trim().isNotEmpty)
                          _MiniBadge(
                            text: post.category!,
                            color: theme.colorScheme.secondaryContainer,
                            textColor: theme.colorScheme.onSecondaryContainer,
                          ),
                        if (post.isPinned)
                          _MiniBadge(
                            text: 'Pinned',
                            color: theme.colorScheme.primaryContainer,
                            textColor: theme.colorScheme.onPrimaryContainer,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: <Widget>[
                        _MetaText(
                          icon: Icons.thumb_up_alt_outlined,
                          text: '${post.likeCount}',
                        ),
                        _MetaText(
                          icon: Icons.mode_comment_outlined,
                          text: '${post.commentCount}',
                        ),
                        _MetaText(
                          icon: Icons.visibility_outlined,
                          text: '${post.viewCount}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoFeedCard extends StatelessWidget {
  const _InfoFeedCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String meta;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.dividerColor.withOpacity(0.14),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _MiniBadge(
                      text: meta,
                      color: theme.colorScheme.tertiaryContainer,
                      textColor: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessStrip extends StatelessWidget {
  const _QuickAccessStrip({
    required this.theme,
    required this.onBoardsTap,
    required this.onEventsTap,
    required this.onFieldsTap,
    required this.onBlogTap,
  });

  final ThemeData theme;
  final VoidCallback onBoardsTap;
  final VoidCallback onEventsTap;
  final VoidCallback onFieldsTap;
  final VoidCallback onBlogTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _QuickActionButton(
              icon: Icons.forum_outlined,
              label: 'Boards',
              onTap: onBoardsTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.event_outlined,
              label: 'Events',
              onTap: onEventsTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.map_outlined,
              label: 'Fields',
              onTap: onFieldsTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.menu_book_outlined,
              label: 'Blog',
              onTap: onBlogTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(text),
      ],
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 112,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon),
          const SizedBox(height: 10),
          Text(text),
        ],
      ),
    );
  }
}

class _HomeEventItem {
  const _HomeEventItem({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String meta;
  final IconData icon;
}

class _HomeFieldUpdateItem {
  const _HomeFieldUpdateItem({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String meta;
  final IconData icon;
}

class _HomeBlogItem {
  const _HomeBlogItem({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String meta;
  final IconData icon;
}
