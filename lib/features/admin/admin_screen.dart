import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../community/community_model.dart';
import '../events/event_create_screen.dart';
import '../events/event_model.dart';
import '../fields/field_model.dart';
import '../profile/profile_model.dart';
import 'admin_create_field_screen.dart';
import 'admin_repository.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final AdminRepository _repository = AdminRepository();
  final TextEditingController _userSearchController = TextEditingController();
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );
  late Future<bool> _isAdminFuture;
  late Future<_AdminDashboardData> _dashboardFuture;
  late Future<List<ProfileModel>> _profilesFuture;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _isAdminFuture = _repository.isCurrentUserAdmin();
    _dashboardFuture = _loadDashboard();
    _profilesFuture = _repository.searchProfiles('');
  }

  Widget _buildAccessDenied({Object? error}) {
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id ?? 'Not logged in';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.lock_outline, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Admin access is not enabled for this account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Current user id: $currentUserId',
              textAlign: TextAlign.center,
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text('Error: $error', textAlign: TextAlign.center),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isAdminFuture = _repository.isCurrentUserAdmin();
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry check'),
            ),
          ],
        ),
      ),
    );
  }

  Future<_AdminDashboardData> _loadDashboard() async {
    final results = await Future.wait<dynamic>([
      _repository.getRecentPosts(),
      _repository.getRecentComments(),
      _repository.getRecentEvents(),
      _repository.getRecentFields(),
      _repository.getRecentBans(),
    ]);

    return _AdminDashboardData(
      posts: results[0] as List<CommunityPostModel>,
      comments: results[1] as List<CommunityCommentModel>,
      events: results[2] as List<EventModel>,
      fields: results[3] as List<FieldModel>,
      bans: results[4] as List<AdminBanRecord>,
    );
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _dashboardFuture = _loadDashboard();
      _profilesFuture = _repository.searchProfiles(_userSearchController.text);
    });
    await Future.wait<dynamic>([_dashboardFuture, _profilesFuture]);
  }

  Future<void> _searchUsers() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _profilesFuture = _repository.searchProfiles(_userSearchController.text);
    });
    await _profilesFuture;
  }

  Future<void> _confirmDelete({
    required String title,
    required Future<void> Function() onDelete,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete $title?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await onDelete();
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
    }
  }

  Future<void> _openIssueBan(ProfileModel profile) async {
    final reasonController = TextEditingController();
    bool isPermanent = false;
    String duration = '7 days';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text('Ban ${profile.displayName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: reasonController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Reason'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Permanent ban'),
                      value: isPermanent,
                      onChanged: (value) {
                        setLocalState(() {
                          isPermanent = value;
                        });
                      },
                    ),
                    if (!isPermanent)
                      DropdownButtonFormField<String>(
                        initialValue: duration,
                        items: const [
                          DropdownMenuItem(
                            value: '1 day',
                            child: Text('1 day'),
                          ),
                          DropdownMenuItem(
                            value: '7 days',
                            child: Text('7 days'),
                          ),
                          DropdownMenuItem(
                            value: '30 days',
                            child: Text('30 days'),
                          ),
                        ],
                        onChanged: (value) {
                          setLocalState(() {
                            duration = value ?? '7 days';
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Duration',
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop({
                    'reason': reasonController.text,
                    'isPermanent': isPermanent,
                    'duration': duration,
                  }),
                  child: const Text('Issue Ban'),
                ),
              ],
            );
          },
        );
      },
    );
    reasonController.dispose();

    if (result == null) {
      return;
    }

    final selectedDuration = result['duration'] as String;
    Duration? durationValue;
    switch (selectedDuration) {
      case '1 day':
        durationValue = const Duration(days: 1);
        break;
      case '30 days':
        durationValue = const Duration(days: 30);
        break;
      case '7 days':
      default:
        durationValue = const Duration(days: 7);
        break;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await _repository.issueBan(
        userId: profile.id,
        reason: (result['reason'] as String?) ?? '',
        isPermanent: result['isPermanent'] == true,
        bannedUntil: result['isPermanent'] == true
            ? null
            : DateTime.now().add(durationValue),
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ban failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _revokeBan(AdminBanRecord ban) async {
    try {
      await _repository.revokeBan(ban.id);
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Revoke failed: $error')));
    }
  }

  Future<void> _openOfficialEvent() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const EventCreateScreen(isOfficial: true),
      ),
    );

    if (!mounted) {
      return;
    }

    if (created == true) {
      await _refresh();
    }
  }

  Future<void> _openOfficialField() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminCreateFieldScreen()),
    );

    if (!mounted) {
      return;
    }

    if (created == true) {
      await _refresh();
    }
  }

  Future<void> _editEvent(EventModel event) async {
    final bool? updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventCreateScreen(
          isOfficial: event.isOfficial,
          existingEvent: event,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updated == true) {
      await _refresh();
    }
  }

  Future<void> _editField(FieldModel field) async {
    final bool? updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminCreateFieldScreen(existingField: field),
      ),
    );

    if (!mounted) {
      return;
    }

    if (updated == true) {
      await _refresh();
    }
  }

  Widget _buildModerationTab() {
    return FutureBuilder<_AdminDashboardData>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load moderation data: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Recent Posts', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...data.posts.map(
              (post) => Card(
                child: ListTile(
                  title: Text(post.title),
                  subtitle: Text(post.authorName),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(
                      title: 'post "${post.title}"',
                      onDelete: () => _repository.deletePost(post.id),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent Comments',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...data.comments.map(
              (comment) => Card(
                child: ListTile(
                  title: Text(comment.authorName),
                  subtitle: Text(
                    comment.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(
                      title: 'this comment',
                      onDelete: () => _repository.deleteComment(comment.id),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent Events',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...data.events.map(
              (event) => Card(
                child: ListTile(
                  title: Text(event.title),
                  subtitle: Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(
                      title: 'event "${event.title}"',
                      onDelete: () => _repository.deleteEvent(event.id),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _userSearchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchUsers(),
            decoration: InputDecoration(
              hintText: 'Search users',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _searchUsers,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ProfileModel>>(
            future: _profilesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load users: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final profiles = snapshot.data ?? <ProfileModel>[];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...profiles.map(
                    (profile) => Card(
                      child: ListTile(
                        title: Text(profile.displayName),
                        subtitle: Text(profile.userCode),
                        trailing: FilledButton(
                          onPressed: _isBusy
                              ? null
                              : () => _openIssueBan(profile),
                          child: const Text('Ban'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<_AdminDashboardData>(
                    future: _dashboardFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Bans',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          ...snapshot.data!.bans.map(
                            (ban) => Card(
                              child: ListTile(
                                title: Text(ban.userId),
                                subtitle: Text(
                                  ban.isPermanent
                                      ? 'Permanent'
                                      : 'Until ${ban.bannedUntil?.toLocal()}',
                                ),
                                trailing: ban.isRevoked
                                    ? const Text('Revoked')
                                    : TextButton(
                                        onPressed: () => _revokeBan(ban),
                                        child: const Text('Revoke'),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOfficialTab() {
    return FutureBuilder<_AdminDashboardData>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load official content: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_available),
                title: const Text('Create Official Event'),
                subtitle: const Text('Publish an admin-managed event listing.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openOfficialEvent,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.terrain),
                title: const Text('Create Official Field Listing'),
                subtitle: const Text(
                  'Add an official field entry to the directory.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openOfficialField,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent Events',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...data.events.map(
              (event) => Card(
                child: ListTile(
                  leading: event.isOfficial
                      ? const Icon(Icons.verified, color: Colors.blue)
                      : const Icon(Icons.event),
                  title: Text(event.title),
                  subtitle: Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editEvent(event),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent Fields',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...data.fields.map(
              (field) => Card(
                child: ListTile(
                  leading: field.isOfficial
                      ? const Icon(Icons.verified, color: Colors.blue)
                      : const Icon(Icons.terrain),
                  title: Text(field.name),
                  subtitle: Text(
                    field.fullLocation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editField(field),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAdminFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Area')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Area')),
            body: _buildAccessDenied(error: snapshot.error),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Area'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Moderation'),
                Tab(text: 'Users'),
                Tab(text: 'Official'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildModerationTab(),
              _buildUsersTab(),
              _buildOfficialTab(),
            ],
          ),
        );
      },
    );
  }
}

class _AdminDashboardData {
  const _AdminDashboardData({
    required this.posts,
    required this.comments,
    required this.events,
    required this.fields,
    required this.bans,
  });

  final List<CommunityPostModel> posts;
  final List<CommunityCommentModel> comments;
  final List<EventModel> events;
  final List<FieldModel> fields;
  final List<AdminBanRecord> bans;
}
