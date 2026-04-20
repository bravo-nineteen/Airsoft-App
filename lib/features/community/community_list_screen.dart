import 'package:extended_image/extended_image.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _postsChannel;
  Timer? _backgroundSyncTimer;

  List<CommunityPostModel> _posts = <CommunityPostModel>[];
  final List<CommunityPostModel> _pendingPosts = <CommunityPostModel>[];
  final Set<String> _busyLikePostIds = <String>{};
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _didInitLanguagePreference = false;
  int _offset = 0;
  String _selectedLanguagePreference = 'all';
  String _selectedCategory = 'All';

  static const int _pageSize = 20;

  static const List<String> _categories =
      CommunityPostCategories.communityCategoriesWithAll;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _restoreCachedPosts();
    _subscribeRealtime();
    _startBackgroundSync();
  }

  void _startBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted || _isLoading || _isLoadingMore) {
        return;
      }
      _loadPosts();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) {
      return;
    }
    final double threshold = _scrollController.position.maxScrollExtent - 500;
    if (_scrollController.position.pixels >= threshold) {
      _loadMorePosts();
    }
  }

  void _subscribeRealtime() {
    _postsChannel = Supabase.instance.client.channel('community-feed-updates');

    _postsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'community_posts',
          callback: (payload) {
            _handleRealtimePost(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'community_posts',
          callback: (payload) {
            _handleRealtimePost(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _handleRealtimePost(Map<String, dynamic> row) {
    if (!mounted) {
      return;
    }

    final CommunityPostModel incoming = CommunityPostModel.fromJson(row);
    if (incoming.postContext != 'community') {
      return;
    }
    if (!_matchesCurrentFilters(incoming)) {
      return;
    }
    if (row['is_deleted'] == true) {
      setState(() {
        _posts = _posts
            .where((CommunityPostModel post) => post.id != incoming.id)
            .toList();
        _pendingPosts.removeWhere(
          (CommunityPostModel post) => post.id == incoming.id,
        );
      });
      return;
    }

    final int index = _posts.indexWhere(
      (CommunityPostModel post) => post.id == incoming.id,
    );
    final int pendingIndex = _pendingPosts.indexWhere(
      (CommunityPostModel post) => post.id == incoming.id,
    );

    if (index == -1) {
      if (pendingIndex != -1) {
        setState(() {
          _pendingPosts[pendingIndex] = incoming.copyWith(
            category: CommunityPostCategories.normalizeCommunityCategory(
              incoming.category,
            ),
          );
        });
        return;
      }

      // Do not jump the user's reading position. Queue new items and let the
      // user reveal them from a lightweight banner.
      setState(() {
        _pendingPosts.insert(
          0,
          incoming.copyWith(
            category: CommunityPostCategories.normalizeCommunityCategory(
              incoming.category,
            ),
          ),
        );
      });
      return;
    }

    final CommunityPostModel existing = _posts[index];
    final CommunityPostModel merged = incoming.copyWith(
      isLikedByMe: existing.isLikedByMe,
      category: CommunityPostCategories.normalizeCommunityCategory(
        incoming.category,
      ),
    );

    setState(() {
      _posts[index] = merged;
    });
    _cachePosts();
  }

  void _revealPendingPosts() {
    if (_pendingPosts.isEmpty) {
      return;
    }
    setState(() {
      _posts = <CommunityPostModel>[..._pendingPosts, ..._posts];
      _pendingPosts.clear();
    });
    _cachePosts();

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  bool _matchesCurrentFilters(CommunityPostModel post) {
    final String normalizedCategory =
        CommunityPostCategories.normalizeCommunityCategory(post.category);
    if (_selectedCategory != CommunityPostCategories.all &&
        normalizedCategory != _selectedCategory) {
      return false;
    }

    final String language = (post.language ?? '').trim().toLowerCase();
    if (_selectedLanguagePreference == 'english' &&
        language != 'english' &&
        language != 'bilingual') {
      return false;
    }
    if (_selectedLanguagePreference == 'japanese' &&
        language != 'japanese' &&
        language != 'bilingual') {
      return false;
    }

    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    final String haystack = <String>[
      post.title,
      post.bodyText,
      post.plainText,
      post.authorName,
      post.category ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitLanguagePreference) {
      return;
    }
    _didInitLanguagePreference = true;
    _selectedLanguagePreference = 'all';
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    if (!mounted) {
      return;
    }

    if (_posts.isEmpty) {
      setState(() {
        _isLoading = true;
        _isInitialLoading = true;
      });
    } else {
      setState(() {
        _isLoading = true;
        _isRefreshing = true;
      });
    }

    try {
      final CommunityPostsPage page = await _repository.fetchPostsPage(
        query: _searchController.text,
        category: _selectedCategory,
        preferredLanguage: _selectedLanguagePreference,
        offset: 0,
        limit: _pageSize,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _posts = page.items
            .map(
              (CommunityPostModel post) => post.copyWith(
                category: CommunityPostCategories.normalizeCommunityCategory(
                  post.category,
                ),
              ),
            )
            .toList();
        _offset = page.nextOffset;
        _hasMore = page.hasMore;
        _pendingPosts.clear();
        _isLoading = false;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
      _cachePosts();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isInitialLoading = false;
        _isRefreshing = false;
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

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore || _isLoading) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final CommunityPostsPage page = await _repository.fetchPostsPage(
        query: _searchController.text,
        category: _selectedCategory,
        preferredLanguage: _selectedLanguagePreference,
        offset: _offset,
        limit: _pageSize,
      );

      if (!mounted) {
        return;
      }

      final Set<String> existingIds = _posts
          .map((CommunityPostModel post) => post.id)
          .toSet();
      final List<CommunityPostModel> appended = page.items
          .where((CommunityPostModel post) => !existingIds.contains(post.id))
          .map(
            (CommunityPostModel post) => post.copyWith(
              category: CommunityPostCategories.normalizeCommunityCategory(
                post.category,
              ),
            ),
          )
          .toList();

      setState(() {
        _posts = <CommunityPostModel>[..._posts, ...appended];
        _offset = page.nextOffset;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
      _cachePosts();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  String get _cacheKey {
    return 'community-feed-v1-${_selectedCategory.toLowerCase()}-${_selectedLanguagePreference.toLowerCase()}';
  }

  Future<void> _cachePosts() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> payload = _posts
          .take(80)
          .map((CommunityPostModel post) => post.toJson())
          .toList();
      await prefs.setString(_cacheKey, jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> _restoreCachedPosts() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }

      final List<CommunityPostModel> cached = decoded
          .whereType<Map>()
          .map(
            (Map item) => CommunityPostModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
      if (!mounted || cached.isEmpty) {
        return;
      }

      setState(() {
        _posts = cached;
        _isLoading = false;
        _offset = cached.length;
        _pendingPosts.clear();
      });
    } catch (_) {}
  }

  Future<void> _openCreateScreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const CommunityCreatePostScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadPosts();
  }

  Future<void> _pickLanguagePreference() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(l10n.t('allLanguages')),
                onTap: () => Navigator.of(sheetContext).pop('all'),
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(l10n.t('english')),
                onTap: () => Navigator.of(sheetContext).pop('english'),
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(l10n.t('japanese')),
                onTap: () => Navigator.of(sheetContext).pop('japanese'),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || selected == _selectedLanguagePreference) {
      return;
    }

    setState(() {
      _selectedLanguagePreference = selected;
    });
    _loadPosts();
  }

  void _openImageLightbox(List<String> imageUrls, {int initialIndex = 0}) {
    if (imageUrls.isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (BuildContext dialogContext) {
        final int startIndex = initialIndex.clamp(0, imageUrls.length - 1);
        final PageController controller = PageController(initialPage: startIndex);

        return Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: <Widget>[
              PageView.builder(
                controller: controller,
                itemCount: imageUrls.length,
                itemBuilder: (BuildContext context, int index) {
                  return InteractiveViewer(
                    minScale: 0.85,
                    maxScale: 4.0,
                    child: Center(
                      child: ExtendedImage.network(
                        imageUrls[index],
                        fit: BoxFit.contain,
                        cache: true,
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton.filled(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPostDetails(CommunityPostModel post) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailsScreen(postId: post.id),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadPosts();
  }

  Future<void> _toggleLikeFromFeed(CommunityPostModel post) async {
    if (_busyLikePostIds.contains(post.id)) {
      return;
    }

    final int index = _posts.indexWhere((CommunityPostModel p) => p.id == post.id);
    if (index == -1) {
      return;
    }

    final CommunityPostModel original = _posts[index];
    final bool nextLiked = !original.isLikedByMe;
    final int nextCount = original.likeCount + (nextLiked ? 1 : -1);

    setState(() {
      _busyLikePostIds.add(post.id);
      _posts[index] = original.copyWith(
        isLikedByMe: nextLiked,
        likeCount: nextCount < 0 ? 0 : nextCount,
      );
    });

    try {
      await _repository.toggleLikePost(post.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _posts[index] = original;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to like post: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _busyLikePostIds.remove(post.id);
        });
      }
    }
  }

  void _openProfile(String? userId, String fallbackName) {
    final _ = fallbackName;
    if (userId == null || userId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('profileNotAvailable'))),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityUserProfileScreen(
          userId: userId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_postsChannel != null) {
      Supabase.instance.client.removeChannel(_postsChannel!);
    }
    _backgroundSyncTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
    final yyyy = dateTime.year.toString().padLeft(4, '0');
    final mm = dateTime.month.toString().padLeft(2, '0');
    final dd = dateTime.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Map<String, String> languageLabels = <String, String>{
      'all': l10n.t('allLanguages'),
      'english': l10n.t('preferEnglishPosts'),
      'japanese': l10n.t('preferJapanesePosts'),
      'bilingual': l10n.t('bilingual'),
    };
    final String languageSummary = switch (_selectedLanguagePreference) {
      'all' => l10n.t('allLanguages'),
      'english' => l10n.t('preferEnglishPosts'),
      'japanese' => l10n.t('preferJapanesePosts'),
      _ => l10n.t('allLanguages'),
    };

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateScreen,
        icon: const Icon(Icons.edit_outlined),
        label: Text(l10n.t('newPost')),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: false,
              expandedHeight: 162,
              title: Text(
                l10n.t('boards'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 64, 16, 10),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _loadPosts(),
                          decoration: InputDecoration(
                            isDense: true,
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
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length + 1,
                            separatorBuilder: (_, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (BuildContext context, int index) {
                              if (index == 0) {
                                return FilterChip(
                                  label: Text(languageSummary),
                                  selected: true,
                                  avatar: const Icon(Icons.language, size: 18),
                                  onSelected: (_) => _pickLanguagePreference(),
                                );
                              }

                              final category = _categories[index - 1];
                              final isSelected =
                                  category == _selectedCategory;

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
                ),
              ),
            ),
            if (_isRefreshing)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_pendingPosts.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.fiber_new_outlined),
                      title: Text(
                        '${_pendingPosts.length} new posts available',
                      ),
                      trailing: TextButton(
                        onPressed: _revealPendingPosts,
                        child: const Text('Show'),
                      ),
                    ),
                  ),
                ),
              ),
            if (_isInitialLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_posts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No posts found')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                sliver: SliverList.builder(
                  itemCount: _posts.length,
                  itemBuilder: (BuildContext context, int index) {
                    final post = _posts[index];

                    return _CompactPostCard(
                      post: post,
                      timeAgo: _timeAgo(post.createdAt),
                      languageLabel:
                          languageLabels[(post.language ?? '').toLowerCase()] ??
                          l10n.t('allLanguages'),
                      onTap: () => _openPostDetails(post),
                        onImageTap: () {
                        final List<String> images = post.imageUrls.isNotEmpty
                          ? post.imageUrls
                          : (post.primaryImageUrl == null
                            ? <String>[]
                            : <String>[post.primaryImageUrl!]);
                        _openImageLightbox(images);
                        },
                      onLikeTap: () => _toggleLikeFromFeed(post),
                      isLiking: _busyLikePostIds.contains(post.id),
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
    required this.onImageTap,
    required this.onLikeTap,
    required this.isLiking,
    required this.onAuthorTap,
  });

  final CommunityPostModel post;
  final String timeAgo;
  final String languageLabel;
  final VoidCallback onTap;
  final VoidCallback onImageTap;
  final VoidCallback onLikeTap;
  final bool isLiking;
  final VoidCallback onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String normalizedCategory =
        CommunityPostCategories.normalizeCommunityCategory(post.category);
    final resolvedImageUrl = post.primaryImageUrl?.trim() ?? '';
    final hasImage = resolvedImageUrl.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.18),
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
                  child: InkWell(
                    onTap: hasImage ? onImageTap : null,
                    child: hasImage
                        ? ExtendedImage.network(
                      resolvedImageUrl,
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
                            color: theme.colorScheme.primary.withValues(alpha: 0.14),
                            textColor: theme.colorScheme.primary,
                          ),
                        _MiniBadge(
                          text: normalizedCategory,
                          color: theme.colorScheme.secondary.withValues(alpha: 0.14),
                          textColor: theme.colorScheme.secondary,
                        ),
                        _MiniBadge(
                          text: languageLabel,
                          color: theme.colorScheme.tertiary.withValues(alpha: 0.14),
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
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: TextButton.icon(
                              onPressed: isLiking ? null : onLikeTap,
                              icon: isLiking
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      post.isLikedByMe
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                    ),
                              label: Text('Like ${post.likeCount}'),
                            ),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: onTap,
                              icon: const Icon(Icons.mode_comment_outlined),
                              label: Text('Comment ${post.commentCount}'),
                            ),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: onTap,
                              icon: const Icon(Icons.open_in_new_outlined),
                              label: const Text('Open'),
                            ),
                          ),
                        ],
                      ),
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
          .withValues(alpha: 0.65),
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
