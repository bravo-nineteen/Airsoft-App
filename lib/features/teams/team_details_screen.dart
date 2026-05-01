import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/admin_repository.dart';
import '../../shared/widgets/user_avatar.dart';
import '../../shared/widgets/persistent_shell_bottom_nav.dart';
import 'team_chat_screen.dart';
import 'team_map_screen.dart';
import 'team_model.dart';
import 'team_repository.dart';

class TeamDetailsScreen extends StatefulWidget {
  const TeamDetailsScreen({super.key, required this.teamId});
  final String teamId;

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  final TeamRepository _repo = TeamRepository();
  final AdminRepository _adminRepo = AdminRepository();

  TeamModel? _team;
  List<TeamMemberModel> _activeMembers = [];
  List<TeamMemberModel> _pendingMembers = [];
  TeamMemberModel? _myMembership;
  bool _isAdmin = false;
  bool _loading = true;
  bool _acting = false;

  String? get _uid => Supabase.instance.client.auth.currentUser?.id;
  bool get _isLeader => _myMembership?.isLeader == true;
  bool get _canManageTeam => _myMembership?.canManageTeam == true;
  bool get _isMember => _myMembership?.isActive == true;
  bool get _isPending => _myMembership?.isPending == true;

  String _locationLabel(TeamModel team) => [
        team.country,
        team.prefecture,
        team.city,
      ].whereType<String>().where((String value) => value.trim().isNotEmpty).join(' • ');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.getTeam(widget.teamId),
        _repo.getMembers(widget.teamId),
        _repo.getMyMembership(widget.teamId),
        _adminRepo.isCurrentUserAdmin(),
      ]);
      if (!mounted) return;
      final allMembers = results[1] as List<TeamMemberModel>;
      setState(() {
        _team = results[0] as TeamModel?;
        _activeMembers =
            allMembers.where((m) => m.isActive).toList();
        _pendingMembers =
            allMembers.where((m) => m.isPending).toList();
        _myMembership = results[2] as TeamMemberModel?;
        _isAdmin = results[3] as bool;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyToJoin() async {
    setState(() => _acting = true);
    try {
      await _repo.applyToJoin(widget.teamId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application sent!')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _leaveTeam() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave team?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Leave')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _acting = true);
    try {
      await _repo.leaveTeam(widget.teamId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _approve(TeamMemberModel m) async {
    try {
      await _repo.approveMember(m.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _reject(TeamMemberModel m) async {
    try {
      await _repo.removeMember(m.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _toggleOfficial() async {
    final team = _team;
    if (team == null) return;
    try {
      await _repo.setOfficial(team.id, official: !team.isOfficial);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _changeRole(TeamMemberModel member, String role) async {
    try {
      await _repo.updateMemberRole(member.id, role);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _editTeam() async {
    final team = _team;
    if (team == null) return;
    final nameCtrl = TextEditingController(text: team.name);
    final descCtrl = TextEditingController(text: team.description ?? '');
    final prefectureCtrl = TextEditingController(text: team.prefecture ?? '');
    final cityCtrl = TextEditingController(text: team.city ?? '');
    final associationCtrl = TextEditingController(text: team.association ?? '');
    String country = team.country ?? 'Japan';
    try {
      final updated = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
            title: const Text('Edit team'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                  const SizedBox(height: 8),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: country,
                    decoration: const InputDecoration(labelText: 'Country'),
                    items: const [
                      DropdownMenuItem(value: 'Japan', child: Text('Japan')),
                      DropdownMenuItem(value: 'United States', child: Text('United States')),
                      DropdownMenuItem(value: 'United Kingdom', child: Text('United Kingdom')),
                      DropdownMenuItem(value: 'Canada', child: Text('Canada')),
                      DropdownMenuItem(value: 'Australia', child: Text('Australia')),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setLocalState(() => country = value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: prefectureCtrl, decoration: const InputDecoration(labelText: 'State / Prefecture')),
                  const SizedBox(height: 8),
                  TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City')),
                  const SizedBox(height: 8),
                  TextField(controller: associationCtrl, decoration: const InputDecoration(labelText: 'Association')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
            ],
          ),
        ),
      );
      if (updated != true) {
        return;
      }
      await _repo.updateTeam(
        team.id,
        name: nameCtrl.text,
        description: descCtrl.text,
        country: country,
        prefecture: prefectureCtrl.text,
        city: cityCtrl.text,
        association: associationCtrl.text,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      nameCtrl.dispose();
      descCtrl.dispose();
      prefectureCtrl.dispose();
      cityCtrl.dispose();
      associationCtrl.dispose();
    }
  }

  Future<void> _deleteTeam() async {
    final team = _team;
    if (team == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete team?'),
        content: const Text('This removes the team for all members.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _repo.deleteTeam(team.id);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final team = _team;
    if (team == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Team not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(team.name),
            if (team.isOfficial) ...[
              const SizedBox(width: 6),
              const Tooltip(
                message: 'Official Team',
                child: Icon(Icons.verified, size: 18, color: Colors.blue),
              ),
            ],
          ],
        ),
        actions: [
          if (_isLeader)
            PopupMenuButton<String>(
              onSelected: (String value) {
                if (value == 'edit') {
                  _editTeam();
                } else if (value == 'delete') {
                  _deleteTeam();
                }
              },
              itemBuilder: (BuildContext context) => const [
                PopupMenuItem<String>(value: 'edit', child: Text('Edit team')),
                PopupMenuItem<String>(value: 'delete', child: Text('Delete team')),
              ],
            ),
          if (_isAdmin)
            IconButton(
              icon: Icon(team.isOfficial
                  ? Icons.verified_outlined
                  : Icons.verified),
              tooltip: team.isOfficial
                  ? 'Revoke official status'
                  : 'Grant official status',
              onPressed: _toggleOfficial,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            // Banner / logo header
            if ((team.bannerUrl ?? '').isNotEmpty)
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.network(team.bannerUrl!, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        userId: team.leaderId,
                        avatarUrl: team.logoUrl,
                        radius: 32,
                        initials: team.name,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(team.name,
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            Text(
                              '${_activeMembers.length} member${_activeMembers.length == 1 ? '' : 's'}',
                              style: theme.textTheme.bodySmall,
                            ),
                            if (_locationLabel(team).isNotEmpty)
                              Text(
                                _locationLabel(team),
                                style: theme.textTheme.bodySmall,
                              ),
                            if ((team.association ?? '').trim().isNotEmpty)
                              Text(
                                team.association!,
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((team.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(team.description!),
                  ],
                  const SizedBox(height: 16),
                  _buildActionBar(team),
                ],
              ),
            ),
            // Pending applications (only leader sees)
            if (_canManageTeam && _pendingMembers.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Pending Applications (${_pendingMembers.length})',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ..._pendingMembers.map((m) => _PendingTile(
                    member: m,
                    onApprove: () => _approve(m),
                    onReject: () => _reject(m),
                  )),
              const Divider(),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Members (${_activeMembers.length})',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ..._activeMembers.map((m) => ListTile(
                  leading: UserAvatar(
                    userId: m.userId,
                    avatarUrl: m.avatarUrl,
                    radius: 20,
                    initials: m.callSign,
                  ),
                  title: Text(m.callSign ?? 'Unknown'),
                  trailing: m.isLeader
                      ? Chip(
                          label: const Text('Leader'),
                          backgroundColor:
                              theme.colorScheme.primaryContainer,
                          padding: EdgeInsets.zero,
                          labelStyle: const TextStyle(fontSize: 11),
                        )
                      : (m.isSquadLeader
                          ? Chip(
                              label: const Text('Squad Leader'),
                              backgroundColor:
                                  theme.colorScheme.secondaryContainer,
                              padding: EdgeInsets.zero,
                              labelStyle: const TextStyle(fontSize: 11),
                            )
                          : (_canManageTeam && m.userId != _uid
                              ? PopupMenuButton<String>(
                                  onSelected: (String value) {
                                    if (value == 'remove') {
                                      _reject(m);
                                    } else {
                                      _changeRole(m, value);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    if (_isLeader)
                                      const PopupMenuItem<String>(
                                        value: 'member',
                                        child: Text('Set as member'),
                                      ),
                                    if (_isLeader)
                                      const PopupMenuItem<String>(
                                        value: 'squad_leader',
                                        child: Text('Set as squad leader'),
                                      ),
                                    const PopupMenuItem<String>(
                                      value: 'remove',
                                      child: Text('Remove member'),
                                    ),
                                  ],
                                )
                              : null)),
                )),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: const PersistentShellBottomNav(selectedIndex: 4),
    );
  }

  Widget _buildActionBar(TeamModel team) {
    if (_uid == null) {
      return const SizedBox.shrink();
    }

    Widget collaborationButtons() {
      return Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TeamMapScreen(
                      teamId: team.id,
                      teamName: team.name,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.map_outlined),
              label: const Text('Map'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TeamChatScreen(
                      teamId: team.id,
                      teamName: team.name,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Live Chat'),
            ),
          ),
        ],
      );
    }

    if (_canManageTeam) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.star_outline),
            label: Text(_isLeader ? 'You are the leader' : 'You are a squad leader'),
          ),
          const SizedBox(height: 8),
          collaborationButtons(),
        ],
      );
    }

    if (_isMember) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          collaborationButtons(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _acting ? null : _leaveTeam,
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Leave Team'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      );
    }

    if (_isPending) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.hourglass_top),
        label: const Text('Application Pending'),
      );
    }

    return FilledButton.icon(
      onPressed: _acting ? null : _applyToJoin,
      icon: const Icon(Icons.group_add),
      label: const Text('Apply to Join'),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({
    required this.member,
    required this.onApprove,
    required this.onReject,
  });
  final TeamMemberModel member;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: UserAvatar(
        userId: member.userId,
        avatarUrl: member.avatarUrl,
        radius: 20,
        initials: member.callSign,
      ),
      title: Text(member.callSign ?? 'Unknown'),
      subtitle: const Text('Wants to join'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            tooltip: 'Approve',
            onPressed: onApprove,
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: 'Reject',
            onPressed: onReject,
          ),
        ],
      ),
    );
  }
}
