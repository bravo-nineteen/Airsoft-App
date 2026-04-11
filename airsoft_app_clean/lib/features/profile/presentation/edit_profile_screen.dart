import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../shared/models/app_user_profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final AppUserProfile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _callSignController;
  late final TextEditingController _areaController;
  late final TextEditingController _teamNameController;
  late final TextEditingController _loadoutController;
  late final TextEditingController _instagramController;
  late final TextEditingController _facebookController;
  late final TextEditingController _youtubeController;

  @override
  void initState() {
    super.initState();
    _callSignController = TextEditingController(text: widget.profile.callSign);
    _areaController = TextEditingController(text: widget.profile.area ?? '');
    _teamNameController = TextEditingController(text: widget.profile.teamName ?? '');
    _loadoutController = TextEditingController(text: widget.profile.loadout ?? '');
    _instagramController = TextEditingController(text: widget.profile.instagram ?? '');
    _facebookController = TextEditingController(text: widget.profile.facebook ?? '');
    _youtubeController = TextEditingController(text: widget.profile.youtube ?? '');
  }

  @override
  void dispose() {
    _callSignController.dispose();
    _areaController.dispose();
    _teamNameController.dispose();
    _loadoutController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfile)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
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
            controller: _teamNameController,
            decoration: InputDecoration(labelText: l10n.teamName),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _loadoutController,
            decoration: InputDecoration(labelText: l10n.loadout),
          ),
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
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
