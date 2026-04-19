import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../fields/field_model.dart';
import 'admin_repository.dart';

class AdminCreateFieldScreen extends StatefulWidget {
  const AdminCreateFieldScreen({
    super.key,
    this.existingField,
  });

  final FieldModel? existingField;

  @override
  State<AdminCreateFieldScreen> createState() => _AdminCreateFieldScreenState();
}

class _AdminCreateFieldScreenState extends State<AdminCreateFieldScreen> {
  final AdminRepository _repository = AdminRepository();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _prefectureController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _featuresController = TextEditingController();
  final TextEditingController _prosController = TextEditingController();
  final TextEditingController _consController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  bool _isSaving = false;

  bool get _isEditing => widget.existingField != null;

  @override
  void initState() {
    super.initState();
    final FieldModel? field = widget.existingField;
    if (field == null) {
      return;
    }
    _nameController.text = field.name;
    _locationController.text = field.locationName;
    _prefectureController.text = field.prefecture ?? '';
    _cityController.text = field.city ?? '';
    _typeController.text = field.fieldType ?? '';
    _descriptionController.text = field.description;
    _featuresController.text = field.featuresText ?? '';
    _prosController.text = field.prosText ?? '';
    _consController.text = field.consText ?? '';
    _imageUrlController.text = field.imageUrl ?? '';
    _latitudeController.text = field.latitude.toString();
    _longitudeController.text = field.longitude.toString();
  }

  Future<void> _save() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    if (_nameController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        latitude == null ||
        longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('fieldRequiredValues'))),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEditing) {
        await _repository.updateField(
          fieldId: widget.existingField!.id,
          name: _nameController.text,
          locationName: _locationController.text,
          description: _descriptionController.text,
          latitude: latitude,
          longitude: longitude,
          prefecture: _prefectureController.text,
          city: _cityController.text,
          fieldType: _typeController.text,
          imageUrl: _imageUrlController.text,
          featuresText: _featuresController.text,
          prosText: _prosController.text,
          consText: _consController.text,
          isOfficial: widget.existingField!.isOfficial,
        );
      } else {
        await _repository.createOfficialField(
          name: _nameController.text,
          locationName: _locationController.text,
          description: _descriptionController.text,
          latitude: latitude,
          longitude: longitude,
          prefecture: _prefectureController.text,
          city: _cityController.text,
          fieldType: _typeController.text,
          imageUrl: _imageUrlController.text,
          featuresText: _featuresController.text,
          prosText: _prosController.text,
          consText: _consController.text,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).t(
              _isEditing ? 'failedUpdateField' : 'failedCreateField',
              args: {'error': '$error'},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _prefectureController.dispose();
    _cityController.dispose();
    _typeController.dispose();
    _descriptionController.dispose();
    _featuresController.dispose();
    _prosController.dispose();
    _consController.dispose();
    _imageUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.t('editField') : l10n.t('officialFieldListing'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _nameController, decoration: InputDecoration(labelText: l10n.t('fieldName'))),
          const SizedBox(height: 12),
          TextField(controller: _locationController, decoration: InputDecoration(labelText: l10n.t('locationName'))),
          const SizedBox(height: 12),
          TextField(controller: _prefectureController, decoration: InputDecoration(labelText: l10n.t('prefecture'))),
          const SizedBox(height: 12),
          TextField(controller: _cityController, decoration: InputDecoration(labelText: l10n.t('city'))),
          const SizedBox(height: 12),
          TextField(controller: _typeController, decoration: InputDecoration(labelText: l10n.t('fieldType'))),
          const SizedBox(height: 12),
          TextField(controller: _imageUrlController, decoration: InputDecoration(labelText: l10n.t('imageUrl'))),
          const SizedBox(height: 12),
          TextField(controller: _latitudeController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l10n.t('latitude'))),
          const SizedBox(height: 12),
          TextField(controller: _longitudeController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l10n.t('longitude'))),
          const SizedBox(height: 12),
          TextField(controller: _descriptionController, minLines: 4, maxLines: 8, decoration: InputDecoration(labelText: l10n.t('description'))),
          const SizedBox(height: 12),
          TextField(
            controller: _featuresController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Features (comma separated)',
              hintText: 'Parking, CQB zones, Night games',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _prosController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Pros (comma separated)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _consController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Cons (comma separated)',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_business),
            label: Text(_isEditing ? l10n.t('updateOfficialField') : l10n.t('createOfficialField')),
          ),
        ],
      ),
    );
  }
}
