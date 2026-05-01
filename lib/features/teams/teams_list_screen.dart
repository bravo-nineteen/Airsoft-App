import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets/user_avatar.dart';
import '../../shared/widgets/persistent_shell_bottom_nav.dart';
import 'team_details_screen.dart';
import 'team_model.dart';
import 'team_repository.dart';
import 'create_team_screen.dart';

class TeamsListScreen extends StatefulWidget {
  const TeamsListScreen({super.key});

  @override
  State<TeamsListScreen> createState() => _TeamsListScreenState();
}

class _TeamsListScreenState extends State<TeamsListScreen>
    with SingleTickerProviderStateMixin {
  final TeamRepository _repo = TeamRepository();
  late TabController _tabs;

  List<TeamModel> _allTeams = [];
  List<TeamModel> _myTeams = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.getTeams(search: _search.isEmpty ? null : _search),
        _repo.getMyTeams(),
      ]);
      if (!mounted) return;
      setState(() {
        _allTeams = results[0];
        _myTeams = results[1];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateTeamScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'All Teams'), Tab(text: 'My Teams')],
        ),
      ),
      floatingActionButton: uid == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Team'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search teams…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) {
                _search = v;
                _load();
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _TeamList(
                  teams: _allTeams,
                  loading: _loading,
                  onRefresh: _load,
                ),
                _TeamList(
                  teams: _myTeams,
                  loading: _loading,
                  onRefresh: _load,
                  emptyMessage: 'You have not joined any teams yet.',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const PersistentShellBottomNav(selectedIndex: 4),
    );
  }
}

class _TeamList extends StatelessWidget {
  const _TeamList({
    required this.teams,
    required this.loading,
    required this.onRefresh,
    this.emptyMessage = 'No teams found.',
  });

  final List<TeamModel> teams;
  final bool loading;
  final Future<void> Function() onRefresh;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (teams.isEmpty) {
      return Center(
        child: Text(emptyMessage,
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        itemCount: teams.length,
        itemBuilder: (context, i) => _TeamCard(team: teams[i]),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team});
  final TeamModel team;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TeamDetailsScreen(teamId: team.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              UserAvatar(
                userId: team.leaderId,
                avatarUrl: team.logoUrl,
                radius: 26,
                initials: team.name,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(team.name,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        if (team.isOfficial) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: 'Official Team',
                            child: Icon(Icons.verified,
                                size: 16, color: Colors.blue),
                          ),
                        ],
                      ],
                    ),
                    if ((team.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        team.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
