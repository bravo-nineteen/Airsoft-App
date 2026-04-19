import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import 'avatar_picker_widget.dart';
import 'profile_model.dart';
import 'profile_repository.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
  });

  final ProfileModel profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ProfileRepository _repository = ProfileRepository();

  late final TextEditingController _callSignController;
  late final TextEditingController _areaController;
  late final TextEditingController _teamController;
  late final TextEditingController _loadoutController;
  late final TextEditingController _instagramController;
  late final TextEditingController _facebookController;
  late final TextEditingController _youtubeController;
    final List<TextEditingController> _loadoutTitleControllers =
      <TextEditingController>[];
    final List<TextEditingController> _loadoutDescriptionControllers =
      <TextEditingController>[];
    final List<TextEditingController> _loadoutImageControllers =
      <TextEditingController>[];

  late ProfileModel _profile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _callSignController = TextEditingController(text: _profile.callSign);
    _areaController = TextEditingController(text: _profile.area ?? '');
    _teamController = TextEditingController(text: _profile.teamName ?? '');
    _loadoutController = TextEditingController(text: _profile.loadout ?? '');
    _instagramController = TextEditingController(text: _profile.instagram ?? '');
    _facebookController = TextEditingController(text: _profile.facebook ?? '');
    _youtubeController = TextEditingController(text: _profile.youtube ?? '');

    final List<ProfileLoadoutCard> cards = _profile.normalizedLoadoutCards;
    for (final ProfileLoadoutCard card in cards) {
      _loadoutTitleControllers.add(
        TextEditingController(text: card.title ?? ''),
      );
      _loadoutDescriptionControllers.add(
        TextEditingController(text: card.description ?? ''),
      );
      _loadoutImageControllers.add(
        TextEditingController(text: card.imageUrl ?? ''),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final updated = _profile.copyWith(
        callSign: _callSignController.text.trim(),
        area: _areaController.text.trim(),
        teamName: _teamController.text.trim(),
        loadout: _loadoutController.text.trim(),
        instagram: _instagramController.text.trim(),
        facebook: _facebookController.text.trim(),
        youtube: _youtubeController.text.trim(),
        loadoutCards: List<ProfileLoadoutCard>.generate(3, (int index) {
          return ProfileLoadoutCard(
            title: _loadoutTitleControllers[index].text.trim(),
            description: _loadoutDescriptionControllers[index].text.trim(),
            imageUrl: _loadoutImageControllers[index].text.trim(),
          );
        }),
      );

      final saved = await _repository.updateCurrentProfile(updated);

      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).t('failedSaveProfile', args: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _callSignController.dispose();
    _areaController.dispose();
    _teamController.dispose();
    _loadoutController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _youtubeController.dispose();
    for (final TextEditingController controller in _loadoutTitleControllers) {
      controller.dispose();
    }
    for (final TextEditingController controller
        in _loadoutDescriptionControllers) {
      controller.dispose();
    }
    for (final TextEditingController controller in _loadoutImageControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfile)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: AvatarPickerWidget(
              initialAvatarUrl: _profile.avatarUrl,
              onAvatarUpdated: (newUrl) {
                setState(() {
                  _profile = _profile.copyWith(avatarUrl: newUrl);
                });
              },
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _callSignController,
            decoration: InputDecoration(labelText: l10n.callSign),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _areaController,
            decoration: InputDecoration(labelText: l10n.area),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _teamController,
            decoration: InputDecoration(labelText: l10n.teamName),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loadoutController,
            decoration: InputDecoration(labelText: l10n.loadout),
          ),
          const SizedBox(height: 20),
          Text(
            'Loadout photo cards',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add up to 3 loadouts. Each card shows image, title, and details.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          ...List<Widget>.generate(3, (int index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Loadout ${index + 1}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _loadoutImageControllers[index],
                        decoration: const InputDecoration(
                          labelText: 'Image URL',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _loadoutTitleControllers[index],
                        decoration: const InputDecoration(
                          labelText: 'Loadout title',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _loadoutDescriptionControllers[index],
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Loadout details',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: _instagramController,
            decoration: InputDecoration(labelText: l10n.instagram),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _facebookController,
            decoration: InputDecoration(labelText: l10n.facebook),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _youtubeController,
            decoration: InputDecoration(labelText: l10n.youtube),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const CircularProgressIndicator()
                : Text(l10n.t('saveChanges')),
          ),
        ],
      ),
    );
  }
}
