import 'package:flutter/material.dart';

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
      );

      final saved = await _repository.updateCurrentProfile(updated);

      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
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
            decoration: const InputDecoration(labelText: 'Call sign'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _areaController,
            decoration: const InputDecoration(labelText: 'Area'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _teamController,
            decoration: const InputDecoration(labelText: 'Team'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loadoutController,
            decoration: const InputDecoration(labelText: 'Loadout'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instagramController,
            decoration: const InputDecoration(labelText: 'Instagram'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _facebookController,
            decoration: const InputDecoration(labelText: 'Facebook'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _youtubeController,
            decoration: const InputDecoration(labelText: 'YouTube'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const CircularProgressIndicator()
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
