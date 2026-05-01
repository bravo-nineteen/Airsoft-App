import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../community/community_create_post_screen.dart';
import '../community/community_model.dart';
import '../community/community_post_details_screen.dart';
import '../community/community_repository.dart';
import '../community/community_user_profile_screen.dart';
import '../events/event_details_screen.dart';
import '../events/event_model.dart';
import '../events/event_repository.dart';
import '../social/contact_model.dart';
import '../social/contact_repository.dart';
import 'avatar_picker_widget.dart';
import 'edit_profile_screen.dart';
import 'profile_model.dart';
import 'profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.currentLocale,
    this.onLocaleChanged,
    this.currentThemeMode,
    this.onThemeModeChanged,
  });

  final Locale? currentLocale;
  final ValueChanged<Locale?>? onLocaleChanged;
  final ThemeMode? currentThemeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ProfileRepository _profileRepository = ProfileRepository();
  final ContactRepository _contactRepository = ContactRepository();
  final EventRepository _eventRepository = EventRepository();
  final CommunityRepository _communityRepository = CommunityRepository();

  late final TabController _tabController = TabController(length: 3, vsync: this);

  late Future<ProfileModel?> _profileFuture;
  late Future<List<ContactModel>> _friendsFuture;
  late Future<List<EventModel>> _eventsFuture;
  late Future<List<CommunityPostModel>> _timelineFuture;
  late Future<List<CommunityCommentModel>> _commentsFuture;
  late Future<int> _likesFuture;
  late Future<EventAttendanceStats> _eventStatsFuture;
  late Future<Map<String, dynamic>?> _communityProfileFuture;

  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _primeFutures();
  }

  void _primeFutures() {
    _profileFuture = _profileRepository.getCurrentProfile();
    _friendsFuture = _contactRepository.getAcceptedFriends();
    _eventsFuture = _eventRepository.getUserAttendingEvents(_uid);
    _timelineFuture = _communityRepository.fetchMergedTimelinePosts(_uid);
    _commentsFuture = _communityRepository.fetchCommentsByAuthor(_uid, limit: 20);
    _likesFuture = _communityRepository.fetchUserReceivedLikesCount(_uid);
    _eventStatsFuture = _eventRepository.getUserEventStats(_uid);
    _communityProfileFuture = _communityRepository.fetchProfileByUserId(_uid);
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(_primeFutures);
    await Future.wait<dynamic>(<Future<dynamic>>[
      _profileFuture,
      _friendsFuture,
      _eventsFuture,
      _timelineFuture,
      _commentsFuture,
      _likesFuture,
      _eventStatsFuture,
      _communityProfileFuture,
    ]);
  }

  Future<void> _edit(ProfileModel profile) async {
    final result = await Navigator.of(context).push<ProfileModel>(
      MaterialPageRoute<ProfileModel>(
        builder: (_) => EditProfileScreen(profile: profile),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result != null) {
      await _refresh();
    }
  }

  Future<void> _openCreateTimelinePost(ProfileModel profile) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityCreatePostScreen(
          postContext: 'profile',
          targetUserId: profile.id,
          appBarTitle: 'New Timeline Post',
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _openPost(CommunityPostModel post) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailsScreen(postId: post.id),
      ),
    );
    await _refresh();
  }

  Future<void> _openComment(CommunityCommentModel comment) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailsScreen(postId: comment.postId),
      ),
    );
    await _refresh();
  }

  Future<void> _openEvent(EventModel event) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EventDetailsScreen(event: event),
      ),
    );
    await _refresh();
  }

  String _otherUserId(ContactModel contact) {
    return contact.requesterId == _uid ? contact.addresseeId : contact.requesterId;
  }

  String _otherDisplayName(ContactModel contact) {
    final String value = contact.requesterId == _uid
        ? (contact.addresseeCallSign ?? '').trim()
        : (contact.requesterCallSign ?? '').trim();
    return value.isEmpty ? 'Unknown user' : value;
  }

  List<_ProfileActivityItem> _activityItems({
    required List<CommunityPostModel> posts,
    required List<CommunityCommentModel> comments,
  }) {
    final List<_ProfileActivityItem> items = <_ProfileActivityItem>[
      ...posts.map(
        (CommunityPostModel post) => _ProfileActivityItem(
          title: post.title.isEmpty ? 'Untitled post' : post.title,
          subtitle: post.excerpt.isEmpty ? 'Posted on your timeline' : post.excerpt,
          icon: Icons.article_outlined,
          createdAt: post.createdAt,
          onTap: () => _openPost(post),
        ),
      ),
      ...comments.map(
        (CommunityCommentModel comment) => _ProfileActivityItem(
          title: 'Comment',
          subtitle: comment.message,
          icon: Icons.comment_outlined,
          createdAt: comment.createdAt,
          onTap: () => _openComment(comment),
        ),
      ),
    ];
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(25).toList();
  }

  String _formatDate(DateTime value) {
    final DateTime local = value.toLocal();
    final String year = local.year.toString();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return FutureBuilder<List<dynamic>>(
      future: Future.wait<dynamic>(<Future<dynamic>>[
        _profileFuture,
        _friendsFuture,
        _eventsFuture,
        _timelineFuture,
        _commentsFuture,
        _likesFuture,
        _eventStatsFuture,
        _communityProfileFuture,
      ]),
      builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SingleChildScrollView(
            child: ShimmerList(count: 7),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.t('profileError', args: {'error': '${snapshot.error}'}),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final ProfileModel? profile = snapshot.data![0] as ProfileModel?;
        if (profile == null) {
          return Center(child: Text(l10n.t('noProfileAvailable')));
        }

        final List<ContactModel> friends = snapshot.data![1] as List<ContactModel>;
        final List<EventModel> events = snapshot.data![2] as List<EventModel>;
        final List<CommunityPostModel> posts = snapshot.data![3] as List<CommunityPostModel>;
        final List<CommunityCommentModel> comments = snapshot.data![4] as List<CommunityCommentModel>;
        final int receivedLikes = snapshot.data![5] as int;
        final EventAttendanceStats eventStats = snapshot.data![6] as EventAttendanceStats;
        final Map<String, dynamic>? communityProfile = snapshot.data![7] as Map<String, dynamic>?;
        final List<_ProfileActivityItem> activity = _activityItems(posts: posts, comments: comments);
        final String bio = (communityProfile?['bio'] ?? '').toString().trim();

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isWide = constraints.maxWidth >= 980;
            final double viewportHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.of(context).size.height;
            final double tabViewportHeight = (viewportHeight * (isWide ? 0.78 : 0.7)).clamp(620.0, 1020.0);
            final Widget sidebar = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _IntroCard(
                  profile: profile,
                  email: Supabase.instance.client.auth.currentUser?.email ?? '',
                ),
                const SizedBox(height: 14),
                _FriendsCard(
                  friends: friends,
                  getUserId: _otherUserId,
                  getDisplayName: _otherDisplayName,
                ),
                const SizedBox(height: 14),
                _LoadoutGallery(cards: profile.normalizedLoadoutCards),
              ],
            );

            final Widget tabPanel = Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: TabBar(
                      controller: _tabController,
                      indicatorWeight: 3,
                      dividerColor: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      tabs: const <Tab>[
                        Tab(text: 'Timeline'),
                        Tab(text: 'Activity'),
                        Tab(text: 'Events'),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: tabViewportHeight,
                    child: TabBarView(
                      controller: _tabController,
                      children: <Widget>[
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _TimelineTab(
                            posts: posts,
                            onOpenPost: _openPost,
                            onCreatePost: () => _openCreateTimelinePost(profile),
                            formatDate: _formatDate,
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _ActivityTab(
                            likesCount: receivedLikes,
                            postsCount: posts.length,
                            commentsCount: comments.length,
                            activity: activity,
                            formatDate: _formatDate,
                          ),
                        ),
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _EventsTab(
                            events: events,
                            stats: eventStats,
                            onOpenEvent: _openEvent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: <Widget>[
                  _ProfileHero(
                    profile: profile,
                    bio: bio.isEmpty ? null : bio,
                    friendsCount: friends.length,
                    eventsCount: events.length,
                    likesCount: receivedLikes,
                    postsCount: posts.length,
                    onEdit: () => _edit(profile),
                    onViewPublicProfile: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CommunityUserProfileScreen(
                            userId: profile.id,
                            fallbackName: profile.displayName,
                          ),
                        ),
                      );
                    },
                    onAvatarUpdated: (_) => _refresh(),
                  ),
                  const SizedBox(height: 16),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(width: 330, child: sidebar),
                        const SizedBox(width: 16),
                        Expanded(child: tabPanel),
                      ],
                    )
                  else ...<Widget>[
                    sidebar,
                    const SizedBox(height: 16),
                    tabPanel,
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.friendsCount,
    required this.eventsCount,
    required this.likesCount,
    required this.postsCount,
    required this.onEdit,
    required this.onViewPublicProfile,
    required this.onAvatarUpdated,
    this.bio,
  });

  final ProfileModel profile;
  final String? bio;
  final int friendsCount;
  final int eventsCount;
  final int likesCount;
  final int postsCount;
  final VoidCallback onEdit;
  final VoidCallback onViewPublicProfile;
  final ValueChanged<String?> onAvatarUpdated;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                height: 190,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      theme.colorScheme.primary.withValues(alpha: 0.9),
                      theme.colorScheme.secondary.withValues(alpha: 0.75),
                      theme.colorScheme.tertiary.withValues(alpha: 0.55),
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Wrap(
                      spacing: 8,
                      children: <Widget>[
                        _HeroStatPill(icon: Icons.article_outlined, label: 'Posts $postsCount'),
                        _HeroStatPill(icon: Icons.favorite_border, label: 'Likes $likesCount'),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -34,
                top: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: 44,
                bottom: 8,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: 20,
                bottom: -54,
                child: AvatarPickerWidget(
                  initialAvatarUrl: profile.avatarUrl,
                  onAvatarUpdated: onAvatarUpdated,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 68, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile.displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.userCode,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if ((bio ?? '').trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(bio!),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _HeroStatPill(icon: Icons.people_outline, label: 'Friends $friendsCount'),
                    _HeroStatPill(icon: Icons.event_outlined, label: 'Events $eventsCount'),
                    if ((profile.teamName ?? '').trim().isNotEmpty)
                      _HeroStatPill(icon: Icons.shield_outlined, label: profile.teamName!),
                    if ((profile.area ?? '').trim().isNotEmpty)
                      _HeroStatPill(icon: Icons.public_outlined, label: profile.area!),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit profile'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onViewPublicProfile,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View public profile'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatPill extends StatelessWidget {
  const _HeroStatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.profile, required this.email});

  final ProfileModel profile;
  final String email;

  @override
  Widget build(BuildContext context) {
    final List<_IntroItem> items = <_IntroItem>[
      if ((profile.area ?? '').trim().isNotEmpty)
        _IntroItem(icon: Icons.public_outlined, title: 'Area', value: profile.area!),
      if ((profile.teamName ?? '').trim().isNotEmpty)
        _IntroItem(icon: Icons.groups_outlined, title: 'Team', value: profile.teamName!),
      if ((profile.loadout ?? '').trim().isNotEmpty)
        _IntroItem(icon: Icons.inventory_2_outlined, title: 'Loadout', value: profile.loadout!),
      if ((profile.instagram ?? '').trim().isNotEmpty)
        _IntroItem(icon: Icons.camera_alt_outlined, title: 'Instagram', value: profile.instagram!),
      if ((profile.facebook ?? '').trim().isNotEmpty)
        _IntroItem(icon: Icons.facebook_outlined, title: 'Facebook', value: profile.facebook!),
      if ((profile.youtube ?? '').trim().isNotEmpty)
        _IntroItem(icon: Icons.ondemand_video_outlined, title: 'YouTube', value: profile.youtube!),
      if (email.trim().isNotEmpty)
        _IntroItem(icon: Icons.mail_outline, title: 'Account', value: email),
    ];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Intro',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (_IntroItem item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(item.icon, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(item.value),
                        ],
                      ),
                    ),
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

class _FriendsCard extends StatelessWidget {
  const _FriendsCard({
    required this.friends,
    required this.getUserId,
    required this.getDisplayName,
  });

  final List<ContactModel> friends;
  final String Function(ContactModel) getUserId;
  final String Function(ContactModel) getDisplayName;

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Friends',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            ...friends.take(6).map((ContactModel contact) {
              final String userId = getUserId(contact);
              final String displayName = getDisplayName(contact);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(
                    displayName.isEmpty ? '?' : displayName.characters.first.toUpperCase(),
                  ),
                ),
                title: Text(displayName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CommunityUserProfileScreen(
                        userId: userId,
                        fallbackName: displayName,
                      ),
                    ),
                  );
                },
              );
            }),
            if (friends.length > 6)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '+${friends.length - 6} more friends',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({
    required this.posts,
    required this.onOpenPost,
    required this.onCreatePost,
    required this.formatDate,
  });

  final List<CommunityPostModel> posts;
  final ValueChanged<CommunityPostModel> onOpenPost;
  final VoidCallback onCreatePost;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _CreatePostPromptCard(onCreatePost: onCreatePost),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Timeline',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onCreatePost,
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('New Post'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (posts.isEmpty)
          const Text('Your timeline is empty. Create the first post.')
        else
          ...posts.map(
            (CommunityPostModel post) => _ProfilePostCard(
              post: post,
              onTap: () => onOpenPost(post),
              formatDate: formatDate,
            ),
          ),
      ],
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({
    required this.likesCount,
    required this.postsCount,
    required this.commentsCount,
    required this.activity,
    required this.formatDate,
  });

  final int likesCount;
  final int postsCount;
  final int commentsCount;
  final List<_ProfileActivityItem> activity;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Activity',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            Chip(label: Text('Received Likes $likesCount')),
            Chip(label: Text('Posts $postsCount')),
            Chip(label: Text('Comments $commentsCount')),
          ],
        ),
        const SizedBox(height: 12),
        if (activity.isEmpty)
          const Text('No recent activity yet.')
        else
          ...activity.map(
            (_ProfileActivityItem item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: item.onTap,
                leading: CircleAvatar(child: Icon(item.icon)),
                title: Text(item.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 4),
                    Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(formatDate(item.createdAt)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EventsTab extends StatelessWidget {
  const _EventsTab({
    required this.events,
    required this.stats,
    required this.onOpenEvent,
  });

  final List<EventModel> events;
  final EventAttendanceStats stats;
  final ValueChanged<EventModel> onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final int finalizedAttendanceCount = stats.attended + stats.noShow;
    final int attendanceRatePercent = finalizedAttendanceCount == 0
        ? 0
        : ((stats.attended / finalizedAttendanceCount) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Events',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            Chip(label: Text('Attending ${stats.attending}')),
            Chip(label: Text('Attended ${stats.attended}')),
            Chip(label: Text('Cancelled ${stats.cancelled}')),
            Chip(label: Text('No Show ${stats.noShow}')),
            Chip(label: Text('Attendance Rate $attendanceRatePercent%')),
          ],
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const Text('No upcoming attending events.')
        else
          ...events.map(
            (EventModel event) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(event.title),
                subtitle: Text(
                  [
                    if ((event.location ?? '').trim().isNotEmpty) event.location!,
                    if ((event.prefecture ?? '').trim().isNotEmpty) event.prefecture!,
                  ].join(' • '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenEvent(event),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfilePostCard extends StatelessWidget {
  const _ProfilePostCard({
    required this.post,
    required this.onTap,
    required this.formatDate,
  });

  final CommunityPostModel post;
  final VoidCallback onTap;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
                    child: Icon(
                      Icons.person_outline,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          post.title.isEmpty ? 'Untitled post' : post.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatDate(post.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz),
                ],
              ),
              const SizedBox(height: 8),
              if (post.excerpt.isNotEmpty) Text(post.excerpt),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: <Widget>[
                  _MetricPill(
                    icon: Icons.favorite_outline,
                    label: '${post.likeCount}',
                  ),
                  _MetricPill(
                    icon: Icons.mode_comment_outlined,
                    label: '${post.commentCount}',
                  ),
                  _MetricPill(
                    icon: Icons.visibility_outlined,
                    label: '${post.viewCount}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadoutGallery extends StatelessWidget {
  const _LoadoutGallery({required this.cards});

  final List<ProfileLoadoutCard> cards;

  @override
  Widget build(BuildContext context) {
    final List<ProfileLoadoutCard> nonEmpty = cards.where((ProfileLoadoutCard card) => !card.isEmpty).toList();
    if (nonEmpty.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Loadout Gallery',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool narrow = constraints.maxWidth < 720;
                final int columns = narrow ? 1 : 2;
                const double gap = 10;
                final double cardWidth = narrow
                    ? constraints.maxWidth
                    : (constraints.maxWidth - gap * (columns - 1)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: nonEmpty
                      .map(
                        (ProfileLoadoutCard card) => SizedBox(
                          width: cardWidth,
                          child: _LoadoutGalleryCard(card: card),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadoutGalleryCard extends StatelessWidget {
  const _LoadoutGalleryCard({required this.card});

  final ProfileLoadoutCard card;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: (card.imageUrl ?? '').trim().isNotEmpty
                    ? Image.network(
                        card.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildFallbackImage(context),
                      )
                    : _buildFallbackImage(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              (card.title ?? '').trim().isEmpty ? 'Untitled loadout' : card.title!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text((card.description ?? '').trim()),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: const Icon(Icons.inventory_2_outlined, size: 30),
    );
  }
}

class _CreatePostPromptCard extends StatelessWidget {
  const _CreatePostPromptCard({required this.onCreatePost});

  final VoidCallback onCreatePost;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
                  child: Icon(
                    Icons.edit_note,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onPressed: onCreatePost,
                    child: const Text('Share an update with your squad...'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton.icon(
                    onPressed: onCreatePost,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Photo'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onCreatePost,
                    icon: const Icon(Icons.event_outlined),
                    label: const Text('Event'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onCreatePost,
                    icon: const Icon(Icons.poll_outlined),
                    label: const Text('Poll'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _ProfileActivityItem {
  const _ProfileActivityItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.createdAt,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final DateTime createdAt;
  final VoidCallback onTap;
}

class _IntroItem {
  const _IntroItem({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;
}
