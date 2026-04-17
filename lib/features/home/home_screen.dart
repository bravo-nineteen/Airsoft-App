import 'dart:convert';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../community/community_list_screen.dart';
import '../community/community_model.dart';
import '../community/community_post_details_screen.dart';
import '../community/community_repository.dart';

enum HomeInterestFilter {
  all,
  posts,
  events,
  blog,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenEventsTab,
    this.onOpenBoardsTab,
  });

  final VoidCallback? onOpenEventsTab;
  final VoidCallback? onOpenBoardsTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CommunityRepository _communityRepository = CommunityRepository();

  List<CommunityPostModel> _latestPosts = <CommunityPostModel>[];
  List<AojBlogPost> _blogPosts = <AojBlogPost>[];

  bool _isLoading = true;
  HomeInterestFilter _selectedFilter = HomeInterestFilter.all;

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
      final results = await Future.wait<dynamic>([
        _communityRepository.fetchPosts(),
        _fetchBlogPosts(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _latestPosts =
            (results[0] as List<CommunityPostModel>).take(6).toList();
        _blogPosts = results[1] as List<AojBlogPost>;
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

  Future<List<AojBlogPost>> _fetchBlogPosts() async {
    const endpoint =
        'https://airsoftonlinejapan.com/wp-json/wp/v2/posts?per_page=5&_embed';

    final response = await http.get(Uri.parse(endpoint));

    if (response.statusCode != 200) {
      throw Exception('Failed to load blog posts');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

    return data
        .map((dynamic item) => AojBlogPost.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  void _openPost(CommunityPostModel post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailsScreen(postId: post.id),
      ),
    );
  }

  void _openBoards() {
    if (widget.onOpenBoardsTab != null) {
      widget.onOpenBoardsTab!();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CommunityListScreen(),
      ),
    );
  }

  void _openEventsPage() {
    if (widget.onOpenEventsTab != null) {
      widget.onOpenEventsTab!();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Events tab is not connected'),
      ),
    );
  }

  Future<void> _openBlogPost(AojBlogPost post) async {
    final uri = Uri.tryParse(post.link);
    if (uri == null) {
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open blog post'),
        ),
      );
    }
  }

  Future<void> _openBlogIndex() async {
    final uri = Uri.parse('https://airsoftonlinejapan.com/blog/');

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open blog'),
        ),
      );
    }
  }

  void _setFilter(HomeInterestFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadHomeData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                children: <Widget>[
                  const _HomeTopBar(),
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
                      subtitle: 'Open your posted events page',
                      onViewAll: _openEventsPage,
                    ),
                    const SizedBox(height: 12),
                    _InfoFeedCard(
                      title: 'See Posted Events',
                      subtitle:
                          'Open the in-app events page to view current event listings.',
                      meta: 'Events',
                      icon: Icons.event_available,
                      onTap: _openEventsPage,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_selectedFilter == HomeInterestFilter.all ||
                      _selectedFilter == HomeInterestFilter.blog) ...[
                    _SectionHeader(
                      title: 'Airsoft Blog',
                      subtitle: 'Latest posts from airsoftonlinejapan.com/blog',
                      onViewAll: _openBlogIndex,
                    ),
                    const SizedBox(height: 12),
                    if (_blogPosts.isEmpty)
                      const _EmptyBlock(
                        icon: Icons.menu_book_outlined,
                        text: 'No blog posts found',
                      )
                    else
                      ..._blogPosts.map(
                        (AojBlogPost post) => _BlogPostCard(
                          post: post,
                          onTap: () => _openBlogPost(post),
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  _QuickAccessStrip(
                    onBoardsTap: _openBoards,
                    onEventsTap: _openEventsPage,
                    onBlogTap: _openBlogIndex,
                  ),
                ],
              ),
            ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'FieldOps News Feed',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
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
                        _MetaItem(
                          icon: Icons.thumb_up_alt_outlined,
                          text: '${post.likeCount}',
                        ),
                        _MetaItem(
                          icon: Icons.mode_comment_outlined,
                          text: '${post.commentCount}',
                        ),
                        _MetaItem(
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

class _BlogPostCard extends StatelessWidget {
  const _BlogPostCard({
    required this.post,
    required this.onTap,
  });

  final AojBlogPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = post.imageUrl != null && post.imageUrl!.trim().isNotEmpty;

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
                          post.imageUrl!,
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
                                child: const Icon(Icons.menu_book_outlined),
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
                            Icons.menu_book_outlined,
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
                    _MiniBadge(
                      text: 'Blog',
                      color: theme.colorScheme.tertiaryContainer,
                      textColor: theme.colorScheme.onTertiaryContainer,
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
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    const _MetaItem(
                      icon: Icons.open_in_new,
                      text: 'Open article',
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
    required this.onBoardsTap,
    required this.onEventsTap,
    required this.onBlogTap,
  });

  final VoidCallback onBoardsTap;
  final VoidCallback onEventsTap;
  final VoidCallback onBlogTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

class _MetaItem extends StatelessWidget {
  const _MetaItem({
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

class AojBlogPost {
  AojBlogPost({
    required this.title,
    required this.excerpt,
    required this.link,
    required this.imageUrl,
  });

  final String title;
  final String excerpt;
  final String link;
  final String? imageUrl;

  factory AojBlogPost.fromJson(Map<String, dynamic> json) {
    final embedded = json['_embedded'] as Map<String, dynamic>?;
    String? imageUrl;

    if (embedded != null && embedded['wp:featuredmedia'] is List) {
      final media = embedded['wp:featuredmedia'] as List<dynamic>;
      if (media.isNotEmpty && media.first is Map<String, dynamic>) {
        final mediaItem = media.first as Map<String, dynamic>;
        imageUrl = mediaItem['source_url'] as String?;
      }
    }

    return AojBlogPost(
      title: _stripHtml(
        ((json['title'] as Map<String, dynamic>?)?['rendered'] as String?) ?? '',
      ),
      excerpt: _stripHtml(
        ((json['excerpt'] as Map<String, dynamic>?)?['rendered'] as String?) ?? '',
      ).trim(),
      link: (json['link'] as String?) ?? '',
      imageUrl: imageUrl,
    );
  }

  static String _stripHtml(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#8217;', '\'')
        .replaceAll('&#8211;', '-')
        .replaceAll('&#038;', '&')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
