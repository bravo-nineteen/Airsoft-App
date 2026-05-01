import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import 'field_model.dart';
import 'field_repository.dart';

class UserSubmitFieldScreen extends StatefulWidget {
  const UserSubmitFieldScreen({super.key});

  @override
  State<UserSubmitFieldScreen> createState() => _UserSubmitFieldScreenState();
}

class _UserSubmitFieldScreenState extends State<UserSubmitFieldScreen> {
  final FieldRepository _repository = FieldRepository();

  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _prefectureController = TextEditingController();
  final _cityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  String _fieldType = 'Outdoor';
  bool _isSaving = false;
  late Future<List<FieldModel>> _mySubmissionsFuture;

  final List<String> _fieldTypes = const [
    'Outdoor',
    'Indoor',
    'CQB',
    'Mixed',
  ];

  @override
  void initState() {
    super.initState();
    _mySubmissionsFuture = _repository.getMyFieldSubmissions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _prefectureController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final locationName = _locationController.text.trim();

    if (name.isEmpty || locationName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('submitListingNameLocationRequired'))),
      );
      return;
    }

    final double? lat = _latController.text.trim().isEmpty
        ? null
        : double.tryParse(_latController.text.trim());
    final double? lng = _lngController.text.trim().isEmpty
        ? null
        : double.tryParse(_lngController.text.trim());

    if ((_latController.text.trim().isNotEmpty && lat == null) ||
        (_lngController.text.trim().isNotEmpty && lng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('invalidLatLng'))),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _repository.submitField(
        name: name,
        locationName: locationName,
        prefecture: _prefectureController.text,
        city: _cityController.text,
        fieldType: _fieldType,
        description: _descriptionController.text,
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('submitListingSuccess'))),
      );
      // Reset form and refresh submissions list.
      _nameController.clear();
      _locationController.clear();
      _prefectureController.clear();
      _cityController.clear();
      _descriptionController.clear();
      _latController.clear();
      _lngController.clear();
      setState(() {
        _mySubmissionsFuture = _repository.getMyFieldSubmissions();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('submitListingFailed', args: {'error': '$error'})),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('submitField'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.t('submitListingHint'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.t('fieldNameLabel'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: l10n.t('locationName'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _prefectureController,
            decoration: InputDecoration(
              labelText: l10n.t('prefecture'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: l10n.t('city'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _fieldType,
            decoration: InputDecoration(
              labelText: l10n.t('fieldType'),
              border: const OutlineInputBorder(),
            ),
            items: _fieldTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _fieldType = v ?? _fieldType),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.t('description'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.t('latitude'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lngController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.t('longitude'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.t('submitListingBtn')),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.t('mySubmissions'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<FieldModel>>(
            future: _mySubmissionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return Text(
                  l10n.t('noSubmissionsYet'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                );
              }
              return Column(
                children: items
                    .map(
                      (f) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(f.name),
                          subtitle: Text(f.locationName),
                          trailing: _SubmissionStatusBadge(status: f.status),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SubmissionStatusBadge extends StatelessWidget {
  const _SubmissionStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (Color bg, Color fg, String label) = switch (status) {
      'approved' => (
          Colors.green.withAlpha(38),
          Colors.green.shade800,
          l10n.t('statusApproved'),
        ),
      'rejected' => (
          Colors.red.withAlpha(28),
          Colors.red.shade700,
          l10n.t('statusRejected'),
        ),
      _ => (
          Colors.orange.withAlpha(38),
          Colors.orange.shade800,
          l10n.t('statusPending'),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12)),
    );
  }
}
