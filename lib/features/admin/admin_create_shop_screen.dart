import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../shops/shop_model.dart';
import 'admin_repository.dart';

class AdminCreateShopScreen extends StatefulWidget {
  const AdminCreateShopScreen({super.key, this.existingShop});

  final ShopModel? existingShop;

  @override
  State<AdminCreateShopScreen> createState() => _AdminCreateShopScreenState();
}

class _AdminCreateShopScreenState extends State<AdminCreateShopScreen> {
  final AdminRepository _repository = AdminRepository();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _prefectureController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _openingTimesController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _featuresController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  bool _isSaving = false;

  bool get _isEditing => widget.existingShop != null;

  @override
  void initState() {
    super.initState();
    final ShopModel? shop = widget.existingShop;
    if (shop == null) {
      return;
    }

    _nameController.text = shop.name;
    _addressController.text = shop.address;
    _prefectureController.text = shop.prefecture ?? '';
    _cityController.text = shop.city ?? '';
    _openingTimesController.text = shop.openingTimes ?? '';
    _phoneController.text = shop.phoneNumber ?? '';
    _featuresController.text = shop.featuresText ?? '';
    _imageUrlController.text = shop.imageUrl ?? '';
    _latitudeController.text = shop.latitude?.toString() ?? '';
    _longitudeController.text = shop.longitude?.toString() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _prefectureController.dispose();
    _cityController.dispose();
    _openingTimesController.dispose();
    _phoneController.dispose();
    _featuresController.dispose();
    _imageUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (_nameController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and address are required.')),
      );
      return;
    }

    final double? latitude = _latitudeController.text.trim().isEmpty
        ? null
        : double.tryParse(_latitudeController.text.trim());
    final double? longitude = _longitudeController.text.trim().isEmpty
        ? null
        : double.tryParse(_longitudeController.text.trim());

    if ((_latitudeController.text.trim().isNotEmpty && latitude == null) ||
        (_longitudeController.text.trim().isNotEmpty && longitude == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Latitude/Longitude must be valid numbers.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEditing) {
        await _repository.updateShop(
          shopId: widget.existingShop!.id,
          name: _nameController.text,
          address: _addressController.text,
          prefecture: _prefectureController.text,
          city: _cityController.text,
          openingTimes: _openingTimesController.text,
          phoneNumber: _phoneController.text,
          featuresText: _featuresController.text,
          imageUrl: _imageUrlController.text,
          latitude: latitude,
          longitude: longitude,
          isOfficial: widget.existingShop!.isOfficial,
        );
      } else {
        await _repository.createOfficialShop(
          name: _nameController.text,
          address: _addressController.text,
          prefecture: _prefectureController.text,
          city: _cityController.text,
          openingTimes: _openingTimesController.text,
          phoneNumber: _phoneController.text,
          featuresText: _featuresController.text,
          imageUrl: _imageUrlController.text,
          latitude: latitude,
          longitude: longitude,
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
            _isEditing
                ? 'Failed to update shop: $error'
                : 'Failed to create shop: $error',
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
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Shop Listing' : 'Official Shop Listing'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(labelText: l10n.t('address')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _prefectureController,
            decoration: InputDecoration(labelText: l10n.t('prefecture')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cityController,
            decoration: InputDecoration(labelText: l10n.t('city')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _openingTimesController,
            decoration: InputDecoration(labelText: l10n.t('openingTimes')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(labelText: l10n.t('phoneNumber')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _imageUrlController,
            decoration: InputDecoration(labelText: l10n.t('imageUrl')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _latitudeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.t('latitude')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _longitudeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.t('longitude')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _featuresController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Features (comma separated)',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.store_mall_directory),
            label: Text(
              _isEditing ? 'Update Official Shop' : 'Create Official Shop',
            ),
          ),
        ],
      ),
    );
  }
}
