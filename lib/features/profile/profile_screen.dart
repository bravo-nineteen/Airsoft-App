import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../settings/settings_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_model.dart';
import 'profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileRepository _repository = ProfileRepository();
  late Future<ProfileModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.getCurrentProfile();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repository.getCurrentProfile();
    });
    await _future;
  }

  Future<void> _edit(ProfileModel profile) async {
    final result = await Navigator.of(context).push<ProfileModel>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(profile: profile),
      ),
    );

    if (result != null) {
      await _refresh();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = snapshot.data;
        if (profile == null) {
          return const Center(child: Text('Profile not found.'));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: (profile.avatarUrl ?? '').isNotEmpty
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                      child: (profile.avatarUrl ?? '').isEmpty
                          ? const Icon(Icons.person, size: 44)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(profile.userCode),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _edit(profile),
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openSettings,
                          icon: const Icon(Icons.settings),
                          label: const Text('Settings'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _InfoCard(title: 'Area', value: profile.area),
            _InfoCard(title: 'Team', value: profile.teamName),
            _InfoCard(title: 'Loadout', value: profile.loadout),
            _InfoCard(title: 'Instagram', value: profile.instagram),
            _InfoCard(title: 'Facebook', value: profile.facebook),
            _InfoCard(title: 'YouTube', value: profile.youtube),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.mail),
                title: const Text('Signed-in account'),
                subtitle:
                    Text(Supabase.instance.client.auth.currentUser?.email ?? ''),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if ((value ?? '').trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          title: Text(title),
          subtitle: Text(value!),
        ),
      ),
    );
  }
}
