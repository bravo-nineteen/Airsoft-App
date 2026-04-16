import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'community_create_post_screen.dart';
import 'community_model.dart';
import 'community_post_details_screen.dart';
import 'community_repository.dart';

class CommunityListScreen extends StatefulWidget {
  const CommunityListScreen({super.key});

  @override
  State<CommunityListScreen> createState() => _CommunityListScreenState();
}

class _CommunityListScreenState extends State<CommunityListScreen> {
  final CommunityRepository _repository = CommunityRepository();
  final TextEditingController _searchController = TextEditingController();

  List<CommunityPostModel> _posts = <CommunityPostModel>[];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  static const List<String> _categories = <String>[
    'All',
    'General',
    'Question',
    'Event',
    'Review',
    'Sale',
    'Guide',
  ];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final posts = await _repository.fetchPosts(
        query: _searchController.text,
        category: _selectedCategory,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load posts')),
      );
    }
  }

  Future<void> _openCreateScreen() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const CommunityCreatePostScreen(),
      ),
    );

    if (created == true) {
      await _loadPosts();
    }
  }

  Future<void> _openPostDetails(CommunityPostModel post) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailsScreen(postId: post.id),
      ),
    );

    await _loadPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }
    return DateFormat('dd MMM').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boards'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateScreen,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('New post'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _loadPosts(),
                    decoration: InputDecoration(
                      hintText: 'Search posts',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: _loadPosts,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final category = _categories[index];
                        final isSelected = category == _selectedCategory;

                        return ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = category;
                            });
                            _loadPosts();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: 6,
                      itemBuilder: (_, __) => const _PostCardSkeleton(),
                    )
                  : _posts.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const <Widget>[
                            SizedBox(height: 120),
                            Center(child: Text('No posts found')),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                          itemCount: _posts.length,
                          itemBuilder: (BuildContext context, int index) {
                            final post = _posts[index];

                            return _CompactPostCard(
                              post: post,
                              theme: theme,
                              timeAgo: _timeAgo(post.createdAt),
                              onTap: () => _openPostDetails(post),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPostCard extends StatelessWidget {
  const _CompactPostCard({
    required this.post,
    required this.theme,
    required this.timeAgo,
    required this.onTap,
  });

  final CommunityPostModel post;
  final ThemeData theme;
  final String timeAgo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = post.primaryImageUrl != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.dividerColor.withOpacity(0.18),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: <Widget>[
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: ExtendedImage.network(
                          post.primaryImageUrl!,
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
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined),
                              );
                            }

                            return Container(
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                        ),
                      ),
                      if (post.imageUrls.length > 1)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '+${post.imageUrls.length - 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.forum_outlined,
                    size: 30,
                    color: theme.colorScheme.primary,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 13,
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              post.authorName,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            timeAgo,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          if (post.isPinned)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Pinned',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          if ((post.category ?? '').isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                post.category!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          post.excerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          _MetaPill(
                            icon: Icons.mode_comment_outlined,
                            label: post.commentCount.toString(),
                          ),
                          const SizedBox(width: 8),
                          _MetaPill(
                            icon: Icons.visibility_outlined,
                            label: post.viewCount.toString(),
                          ),
                          const SizedBox(width: 8),
                          _MetaPill(
                            icon: Icons.favorite_border,
                            label: post.likeCount.toString(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PostCardSkeleton extends StatelessWidget {
  const _PostCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: <Widget>[
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List<Widget>.generate(
                    5,
                    (int index) => Padding(
                      padding: EdgeInsets.only(bottom: index == 4 ? 0 : 8),
                      child: Container(
                        height: index == 0 ? 14 : 12,
                        width: index.isEven ? 180 : 120,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}