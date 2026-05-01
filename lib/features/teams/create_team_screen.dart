import 'package:flutter/material.dart';

import '../../core/location/location_preferences.dart';
import '../community/community_image_service.dart';
import '../../shared/widgets/persistent_shell_bottom_nav.dart';
import 'team_repository.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final TeamRepository _repo = TeamRepository();
  final CommunityImageService _imageService = CommunityImageService();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _prefectureCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _associationCtrl = TextEditingController();
  String _country = 'Japan';
  String? _logoUrl;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _prefectureCtrl.dispose();
    _cityCtrl.dispose();
    _associationCtrl.dispose();
    super.dispose();
  }

  Future<void> _uploadLogo() async {
    final String? imageUrl = await _imageService.pickCropAndUploadCommunityImage(
      folder: 'teams',
    );
    if (!mounted || imageUrl == null) {
      return;
    }
    setState(() => _logoUrl = imageUrl);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repo.createTeam(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        logoUrl: _logoUrl,
        country: _country,
        prefecture: _prefectureCtrl.text,
        city: _cityCtrl.text,
        association: _associationCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team created!')),
        );
        Navigator.of(context).pop(true); // true = reload list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Team')),
      bottomNavigationBar: const PersistentShellBottomNav(selectedIndex: 4),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Team Name *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter a team name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _country,
              decoration: const InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(),
              ),
              items: LocationPreferences.countries
                  .where((String c) => c != LocationPreferences.allCountries)
                  .map((String c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                  .toList(),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _country = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _prefectureCtrl,
              decoration: const InputDecoration(
                labelText: 'State / Prefecture',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityCtrl,
              decoration: const InputDecoration(
                labelText: 'City',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _associationCtrl,
              decoration: const InputDecoration(
                labelText: 'Association / Community / Field',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _saving ? null : _uploadLogo,
              icon: const Icon(Icons.upload_outlined),
              label: Text(_logoUrl == null ? 'Upload team logo' : 'Replace team logo'),
            ),
            const SizedBox(height: 8),
            Text(
              'You will automatically become the team leader. '
              'Members can apply to join and you will be able to '
              'approve or reject applications.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Team'),
            ),
          ],
        ),
      ),
    );
  }
}
