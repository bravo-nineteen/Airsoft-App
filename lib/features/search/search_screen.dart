import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/widgets/persistent_shell_bottom_nav.dart';
import '../community/community_user_profile_screen.dart';
import '../events/event_details_screen.dart';
import '../events/event_model.dart';
import '../events/event_repository.dart';
import '../fields/field_details_screen.dart';
import '../fields/field_model.dart';
import '../fields/field_repository.dart';
import '../profile/profile_model.dart';
import '../profile/profile_repository.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ProfileRepository _profileRepo = ProfileRepository();
  final EventRepository _eventRepo = EventRepository();
  final FieldRepository _fieldRepo = FieldRepository();

  Timer? _debounce;
  bool _loading = false;
  String _query = '';

  List<ProfileModel> _users = [];
  List<EventModel> _events = [];
  List<FieldModel> _fields = [];

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _query = '';
        _users = [];
        _events = [];
        _fields = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value.trim()));
  }

  Future<void> _search(String q) async {
    if (!mounted) return;
    setState(() {
      _query = q;
      _loading = true;
    });

    final lq = q.toLowerCase();

    final results = await Future.wait([
      _profileRepo.searchProfiles(q).catchError((_) => <ProfileModel>[]),
      _eventRepo.getEvents().catchError((_) => <EventModel>[]),
      _fieldRepo.getFields().catchError((_) => <FieldModel>[]),
    ]);

    if (!mounted) return;

    final users = results[0] as List<ProfileModel>;
    final allEvents = results[1] as List<EventModel>;
    final allFields = results[2] as List<FieldModel>;

    final events = allEvents.where((e) {
      return e.title.toLowerCase().contains(lq) ||
          e.description.toLowerCase().contains(lq) ||
          (e.location ?? '').toLowerCase().contains(lq);
    }).toList();

    final fields = allFields.where((f) {
      return f.name.toLowerCase().contains(lq) ||
          f.locationName.toLowerCase().contains(lq) ||
          (f.prefecture ?? '').toLowerCase().contains(lq);
    }).toList();

    setState(() {
      _users = users;
      _events = events;
      _fields = fields;
      _loading = false;
    });
  }

  bool get _hasResults =>
      _users.isNotEmpty || _events.isNotEmpty || _fields.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search players, events, fields…',
            border: InputBorder.none,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: _onChanged,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      bottomNavigationBar: const PersistentShellBottomNav(selectedIndex: 4),
      body: _loading
          ? const LinearProgressIndicator()
          : _query.isEmpty
              ? const Center(
                  child: Text(
                    'Search players, events, and fields.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : !_hasResults
                  ? const Center(child: Text('No results found.'))
                  : ListView(
                      children: [
                        if (_users.isNotEmpty) ...[
                          _SectionHeader(
                              icon: Icons.person_outline, title: 'Players'),
                          ..._users.take(5).map((u) => ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    u.displayName.characters.first
                                        .toUpperCase(),
                                  ),
                                ),
                                title: Text(u.displayName),
                                subtitle: Text(u.userCode),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CommunityUserProfileScreen(
                                      userId: u.id,
                                      fallbackName: u.displayName,
                                    ),
                                  ),
                                ),
                              )),
                        ],
                        if (_events.isNotEmpty) ...[
                          _SectionHeader(
                              icon: Icons.event_outlined, title: 'Events'),
                          ..._events.take(5).map((e) => ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.event),
                                ),
                                title: Text(e.title),
                                subtitle: e.location != null
                                    ? Text(e.location!)
                                    : null,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EventDetailsScreen(event: e),
                                  ),
                                ),
                              )),
                        ],
                        if (_fields.isNotEmpty) ...[
                          _SectionHeader(
                              icon: Icons.landscape_outlined, title: 'Fields'),
                          ..._fields.take(5).map((f) => ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.landscape),
                                ),
                                title: Text(f.name),
                                subtitle: Text(
                                    '${f.prefecture ?? ''} ${f.locationName}'
                                        .trim()),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FieldDetailsScreen(field: f),
                                  ),
                                ),
                              )),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
