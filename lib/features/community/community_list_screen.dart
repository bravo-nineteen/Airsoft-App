import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/localization/app_localizations.dart';
import 'community_create_post_screen.dart';
import 'community_model.dart';
import 'community_post_categories.dart';
import 'community_post_details_screen.dart';
import 'community_repository.dart';
import 'community_user_profile_screen.dart';

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
  String _selectedCategory = CommunityPostCategories.all;
  String _selectedLanguagePreference = 'english';
  bool _didInitLanguagePreference = false;

  static const List<String> _categories =
      CommunityPostCategories.communityCategoriesWithAll;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitLanguagePreference) {
      return;
    }
    _didInitLanguagePreference = true;
    _selectedLanguagePreference =
        AppLocalizations.of(context).locale.languageCode == 'ja'
            ? 'japanese'
            : 'english';
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
        preferredLanguage: _selectedLanguagePreference,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _posts = posts
            .map(
              (CommunityPostModel post) => post.copyWith(
                category: CommunityPostCategories.normalizeCommunityCategory(
                  post.category,
                ),
              ),
            )
            .toList();
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
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).t('failedLoadPosts', args: {'error': '$error'}),
          ),
        ),
      );
    }
  }

  Future<void> _openCreateScreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const CommunityCreatePostScreen(),
      ),
    );

    await _loadPosts();
  }

  Future<void> _openPostDetails(CommunityPostModel post) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailsScreen(postId: post.id),
      ),
    );

    await _loadPosts();
  }

  void _openProfile(String? userId, String fallbackName) {
    if (userId == null || userId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('profileNotAvailable'))),
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
    _searchController.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime dateTime) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) {
      return l10n.t('now');
    }
    if (difference.inHours < 1) {
      return l10n.t('minutesShort', args: {'value': '${difference.inMinutes}'});
    }
    if (difference.inDays < 1) {
      return l10n.t('hoursShort', args: {'value': '${difference.inHours}'});
    }
    if (difference.inDays < 7) {
      return l10n.t('daysShort', args: {'value': '${difference.inDays}'});
    }
    return DateFormat('dd MMM', l10n.locale.languageCode).format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Map<String, String> languageLabels = <String, String>{
      'english': l10n.t('preferEnglishPosts'),
      'japanese': l10n.t('preferJapanesePosts'),
      'bilingual': l10n.t('preferBilingualPosts'),
    };
    final String languageSummary = switch (_selectedLanguagePreference) {
      'english' => l10n.t('preferEnglishPosts'),
      'japanese' => l10n.t('preferJapanesePosts'),
      'bilingual' => l10n.t('preferBilingualPosts'),
      _ => l10n.t('allLanguages'),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('boards')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateScreen,
        icon: const Icon(Icons.edit_outlined),
        label: Text(l10n.t('newPost')),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _loadPosts(),
                    decoration: InputDecoration(
                      hintText: l10n.t('searchPosts'),
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
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLanguagePreference,
                    decoration: InputDecoration(
                      labelText: l10n.t('viewLanguage'),
                    ),
                    items: languageLabels.entries
                        .map(
                          (MapEntry<String, String> entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedLanguagePreference = value;
                      });
                      _loadPosts();
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final String category = _categories[index];
                        final bool isSelected = category == _selectedCategory;

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
                  const SizedBox(height: 10),
                  Text(
                    _selectedCategory == CommunityPostCategories.all
                        ? l10n.t('showingAllBoardCategories')
                        : l10n.t(
                            'showingCategoryPosts',
                            args: {'category': _selectedCategory.toLowerCase()},
                          ),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.t(
                      'showingPostsForLanguage',
                      args: {'language': languageSummary},
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _posts.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: <Widget>[
                            const SizedBox(height: 120),
                            Center(child: Text(l10n.t('noPostsFound'))),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                          itemCount: _posts.length,
                          itemBuilder: (BuildContext context, int index) {
                            final CommunityPostModel post = _posts[index];

                            return _CompactPostCard(
                              post: post,
                              timeAgo: _timeAgo(post.createdAt),
                              languageLabel: switch (post.language) {
                                'japanese' => l10n.t('japanese'),
                                'bilingual' => l10n.t('bilingual'),
                                _ => l10n.t('english'),
                              },
                              onTap: () => _openPostDetails(post),
                              onAuthorTap: () =>
                                  _openProfile(post.authorId, post.authorName),
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
    required this.timeAgo,
    required this.languageLabel,
    required this.onTap,
    required this.onAuthorTap,
  });

  final CommunityPostModel post;
  final String timeAgo;
  final String languageLabel;
  final VoidCallback onTap;
  final VoidCallback onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? imageUrl = post.primaryImageUrl;
    final bool hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    final String normalizedCategory =
        CommunityPostCategories.normalizeCommunityCategory(post.category);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.dividerColor.withOpacity(0.18),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
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
                                child: CircularProgressIndicator(strokeWidth: 2),
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
                    InkWell(
                      onTap: onAuthorTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: post.authorAvatarUrl != null &&
                                      post.authorAvatarUrl!.trim().isNotEmpty
                                  ? NetworkImage(post.authorAvatarUrl!)
                                  : null,
                              child: post.authorAvatarUrl == null ||
                                      post.authorAvatarUrl!.trim().isEmpty
                                  ? Text(
                                      post.authorName.isEmpty
                                          ? '?'
                                          : post.authorName
                                              .substring(0, 1)
                                              .toUpperCase(),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                post.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            Text(
                              timeAgo,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        if (post.isPinned)
                          _MiniBadge(
                            text: AppLocalizations.of(context).t('pinned'),
                            color: theme.colorScheme.primary.withOpacity(0.14),
                            textColor: theme.colorScheme.primary,
                          ),
                        _MiniBadge(
                          text: normalizedCategory,
                          color: theme.colorScheme.secondary.withOpacity(0.14),
                          textColor: theme.colorScheme.secondary,
                        ),
                        _MiniBadge(
                          text: languageLabel,
                          color: theme.colorScheme.tertiary.withOpacity(0.14),
                          textColor: theme.colorScheme.tertiary,
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
                      post.excerpt.isEmpty
                          ? AppLocalizations.of(context).t('noPreviewTextAvailable')
                          : post.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _MetaPill(
                          icon: Icons.mode_comment_outlined,
                          label: post.commentCount.toString(),
                        ),
                        _MetaPill(
                          icon: Icons.visibility_outlined,
                          label: post.viewCount.toString(),
                        ),
                        _MetaPill(
                          icon: Icons.favorite_border,
                          label: post.likeCount.toString(),
                        ),
                        if (post.imageUrls.isNotEmpty)
                          _MetaPill(
                            icon: Icons.image_outlined,
                            label: post.imageUrls.length.toString(),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: textColor,
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
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
