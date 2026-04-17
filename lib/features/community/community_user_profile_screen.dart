import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'community_model.dart';
import 'community_post_details_screen.dart';
import 'community_repository.dart';

class CommunityPublicProfileScreen extends StatefulWidget {
  const CommunityPublicProfileScreen({
    super.key,
    required this.userId,
    required this.fallbackName,
  });

  final String userId;
  final String fallbackName;

  @override
  State<CommunityPublicProfileScreen> createState() =>
      _CommunityPublicProfileScreenState();
}

class _CommunityPublicProfileScreenState
    extends State<CommunityPublicProfileScreen> {
  final CommunityRepository _repository = CommunityRepository();

  Map<String, dynamic>? _profile;
  List<CommunityPostModel> _posts = <CommunityPostModel>[];
  bool _isLoading = true;

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
      final profile = await _repository.fetchProfileByUserId(widget.userId);
      final posts = await _repository.fetchPostsByAuthor(widget.userId);

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _posts = posts;
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
        SnackBar(content: Text('Failed to load profile: $error')),
      );
    }
  }

  String get _displayName {
    final profileName = (_profile?['call_sign'] ?? '').toString().trim();
    if (profileName.isNotEmpty) {
      return profileName;
    }
    return widget.fallbackName;
  }

  String? get _avatarUrl {
    final value = (_profile?['avatar_url'] ?? '').toString().trim();
    if (value.isEmpty) {
      return null;
    }
    return value;
  }

  String? get _bio {
    final value = (_profile?['bio'] ?? '').toString().trim();
    if (value.isEmpty) {
      return null;
    }
    return value;
  }

  Widget _buildAvatar(double size) {
    final avatarUrl = _avatarUrl;
    if (avatarUrl != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    final initial =
        _displayName.trim().isEmpty ? '?' : _displayName.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: size / 2,
      child: Text(
        initial,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
    );
  }

  String _formatDate(DateTime value) {
    return DateFormat('dd MMM yyyy').format(value);
  }

  Future<void> _openPost(CommunityPostModel post) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailsScreen(postId: post.id),
      ),
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        children: <Widget>[
                          _buildAvatar(84),
                          const SizedBox(height: 12),
                          Text(
                            _displayName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_bio != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _bio!,
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: <Widget>[
                              Chip(label: Text('Posts ${_posts.length}')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Posts',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_posts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text('No posts yet.'),
                      )
                    else
                      ..._posts.map((CommunityPostModel post) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _openPost(post),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  if ((post.primaryImageUrl ?? '').isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: SizedBox(
                                        width: 84,
                                        height: 84,
                                        child: ExtendedImage.network(
                                          post.primaryImageUrl!,
                                          fit: BoxFit.cover,
                                          cache: true,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.article_outlined),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        if ((post.category ?? '').isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(bottom: 6),
                                            child: Chip(
                                              label: Text(post.category!),
                                            ),
                                          ),
                                        Text(
                                          post.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          post.excerpt.isEmpty
                                              ? 'No preview text available.'
                                              : post.excerpt,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatDate(post.createdAt),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}
