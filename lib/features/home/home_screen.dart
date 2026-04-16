import 'package:flutter/material.dart';

import '../community/community_list_screen.dart';
import '../community/community_model.dart';
import '../community/community_post_details_screen.dart';
import '../community/community_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CommunityRepository _communityRepository = CommunityRepository();

  List<CommunityPostModel> _latestPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    try {
      final posts = await _communityRepository.fetchPosts();

      if (!mounted) return;

      setState(() {
        _latestPosts = posts.take(3).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openPost(CommunityPostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityPostDetailsScreen(postId: post.id),
      ),
    );
  }

  void _openBoards() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CommunityListScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FieldOps'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHomeData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ===== EVENTS SECTION (placeholder for now)
                  _SectionHeader(
                    title: 'Latest Events',
                    onViewAll: () {
                      // TODO: connect events screen
                    },
                  ),
                  const SizedBox(height: 12),

                  _EmptyBlock(
                    text: 'Events coming soon',
                  ),

                  const SizedBox(height: 24),

                  // ===== POSTS SECTION
                  _SectionHeader(
                    title: 'Latest Posts',
                    onViewAll: _openBoards,
                  ),
                  const SizedBox(height: 12),

                  if (_latestPosts.isEmpty)
                    const _EmptyBlock(text: 'No posts yet')
                  else
                    ..._latestPosts.map((post) {
                      return _HomePostCard(
                        post: post,
                        onTap: () => _openPost(post),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onViewAll,
  });

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // IMAGE
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.forum,
                          color: theme.colorScheme.primary,
                        ),
                      ),
              ),
            ),

            // CONTENT
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.mode_comment_outlined, size: 14),
                        const SizedBox(width: 4),
                        Text('${post.commentCount}'),
                        const SizedBox(width: 10),
                        const Icon(Icons.visibility_outlined, size: 14),
                        const SizedBox(width: 4),
                        Text('${post.viewCount}'),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(text),
    );
  }
}