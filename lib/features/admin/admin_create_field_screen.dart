import 'package:flutter/material.dart';

import 'admin_repository.dart';

class AdminCreateFieldScreen extends StatefulWidget {
  const AdminCreateFieldScreen({super.key});

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
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  bool _isSaving = false;

  Future<void> _save() async {
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    if (_nameController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        latitude == null ||
        longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, location, description, latitude and longitude are required.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
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
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create field: $error')),
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
    _imageUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Official Field Listing')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Field name')),
          const SizedBox(height: 12),
          TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location name')),
          const SizedBox(height: 12),
          TextField(controller: _prefectureController, decoration: const InputDecoration(labelText: 'Prefecture')),
          const SizedBox(height: 12),
          TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'City')),
          const SizedBox(height: 12),
          TextField(controller: _typeController, decoration: const InputDecoration(labelText: 'Field type')),
          const SizedBox(height: 12),
          TextField(controller: _imageUrlController, decoration: const InputDecoration(labelText: 'Image URL')),
          const SizedBox(height: 12),
          TextField(controller: _latitudeController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Latitude')),
          const SizedBox(height: 12),
          TextField(controller: _longitudeController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Longitude')),
          const SizedBox(height: 12),
          TextField(controller: _descriptionController, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_business),
            label: const Text('Create Official Field'),
          ),
        ],
      ),
    );
  }
}
