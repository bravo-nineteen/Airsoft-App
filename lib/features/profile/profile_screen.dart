import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/localization/app_localizations.dart';
import '../settings/settings_screen.dart';
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

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileRepository _repository = ProfileRepository();
  late Future<ProfileModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.getCurrentProfile();
  }

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }
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

    if (!mounted) {
      return;
    }

    if (result != null) {
      await _refresh();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          currentLocale: widget.currentLocale,
          onLocaleChanged: widget.onLocaleChanged,
          currentThemeMode: widget.currentThemeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<ProfileModel?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
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

        final profile = snapshot.data;

        if (profile == null) {
          return Center(
            child: Text(l10n.t('noProfileAvailable')),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    AvatarPickerWidget(
                      initialAvatarUrl: profile.avatarUrl,
                      onAvatarUpdated: (_) => _refresh(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(profile.userCode),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _edit(profile),
                          icon: const Icon(Icons.edit),
                          label: Text(l10n.t('edit')),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openSettings,
                          icon: const Icon(Icons.settings),
                          label: Text(l10n.settings),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _InfoCard(title: l10n.area, value: profile.area),
            _InfoCard(title: l10n.teamName, value: profile.teamName),
            _InfoCard(title: l10n.loadout, value: profile.loadout),
            _LoadoutGallery(cards: profile.normalizedLoadoutCards),
            _InfoCard(title: l10n.instagram, value: profile.instagram),
            _InfoCard(title: l10n.facebook, value: profile.facebook),
            _InfoCard(title: l10n.youtube, value: profile.youtube),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.mail),
                title: Text(l10n.t('signedInAccount')),
                subtitle: Text(
                  Supabase.instance.client.auth.currentUser?.email ?? '',
                ),
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

class _LoadoutGallery extends StatelessWidget {
  const _LoadoutGallery({required this.cards});

  final List<ProfileLoadoutCard> cards;

  @override
  Widget build(BuildContext context) {
    final List<ProfileLoadoutCard> nonEmpty = cards
        .where((ProfileLoadoutCard card) => !card.isEmpty)
        .toList();
    if (nonEmpty.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Loadout Gallery',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double gap = 10;
                  final bool narrow = constraints.maxWidth < 720;
                  final int columns = narrow ? 1 : 3;
                  final double cardWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: nonEmpty.map((ProfileLoadoutCard card) {
                      return SizedBox(
                        width: narrow ? constraints.maxWidth : cardWidth,
                        child: _LoadoutGalleryCard(card: card),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
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
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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