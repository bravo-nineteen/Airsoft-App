import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/widgets/persistent_shell_bottom_nav.dart';
import 'shop_model.dart';
import 'shop_repository.dart';

class UserSubmitShopScreen extends StatefulWidget {
  const UserSubmitShopScreen({super.key});

  @override
  State<UserSubmitShopScreen> createState() => _UserSubmitShopScreenState();
}

class _UserSubmitShopScreenState extends State<UserSubmitShopScreen> {
  final ShopRepository _repository = ShopRepository();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _prefectureController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _openingTimesController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  bool _isSaving = false;
  late Future<List<ShopModel>> _mySubmissionsFuture;

  @override
  void initState() {
    super.initState();
    _mySubmissionsFuture = _repository.getMyShopSubmissions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _prefectureController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _openingTimesController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('submitShopNameAddressRequired'))),
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
      await _repository.submitShop(
        name: name,
        address: address,
        prefecture: _prefectureController.text,
        city: _cityController.text,
        phoneNumber: _phoneController.text,
        openingTimes: _openingTimesController.text,
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('submitListingSuccess'))),
      );
      _nameController.clear();
      _addressController.clear();
      _prefectureController.clear();
      _cityController.clear();
      _phoneController.clear();
      _openingTimesController.clear();
      _latController.clear();
      _lngController.clear();
      setState(() {
        _mySubmissionsFuture = _repository.getMyShopSubmissions();
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
      appBar: AppBar(title: Text(l10n.t('submitShop'))),
      bottomNavigationBar: const PersistentShellBottomNav(selectedIndex: 4),
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
              labelText: l10n.t('shopNameLabel'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: l10n.t('address'),
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
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.t('phoneNumber'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _openingTimesController,
            decoration: InputDecoration(
              labelText: l10n.t('openingTimes'),
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
          FutureBuilder<List<ShopModel>>(
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
                      (s) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(s.name),
                          subtitle: Text(s.locationDisplay),
                          trailing: _SubmissionStatusBadge(status: s.status),
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
