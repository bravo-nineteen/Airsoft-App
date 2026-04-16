import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';

import 'field_details_screen.dart';
import 'field_model.dart';
import 'field_repository.dart';

class FieldsScreen extends StatefulWidget {
  const FieldsScreen({super.key});

  @override
  State<FieldsScreen> createState() => _FieldsScreenState();
}

class _FieldsScreenState extends State<FieldsScreen> {
  final FieldRepository _repository = FieldRepository();
  final TextEditingController _searchController = TextEditingController();

  String _selectedLocation = 'All';
  String _selectedFieldType = 'All';
  bool _mapView = false;

  late Future<List<FieldModel>> _fieldsFuture;

  final List<String> _locations = ['All', 'Chiba', 'Tokyo', 'Kanagawa'];
  final List<String> _fieldTypes = ['All', 'Outdoor', 'Indoor', 'CQB'];

  @override
  void initState() {
    super.initState();
    _fieldsFuture = _loadFields();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<FieldModel>> _loadFields() {
    return _repository.getFields(
      search: _searchController.text,
      location: _selectedLocation,
      fieldType: _selectedFieldType,
    );
  }

  void _refreshFields() {
    setState(() {
      _fieldsFuture = _loadFields();
    });
  }

  void _openField(FieldModel field) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FieldDetailsScreen(field: field),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.t('searchFieldsHint'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refreshFields,
                  ),
                ),
                onSubmitted: (_) => _refreshFields(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedLocation,
                      decoration: InputDecoration(labelText: l10n.location),
                      items: _locations
                          .map((value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLocation = value ?? 'All';
                        });
                        _refreshFields();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedFieldType,
                      decoration: InputDecoration(labelText: l10n.t('fieldType')),
                      items: _fieldTypes
                          .map((value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFieldType = value ?? 'All';
                        });
                        _refreshFields();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(l10n.list),
                    icon: Icon(Icons.view_list),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(l10n.map),
                    icon: Icon(Icons.map),
                  ),
                ],
                selected: {_mapView},
                onSelectionChanged: (selection) {
                  setState(() {
                    _mapView = selection.first;
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _mapView
              ? Center(child: Text(l10n.t('mapViewPlaceholder')))
              : FutureBuilder<List<FieldModel>>(
                  future: _fieldsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            l10n.t(
                              'failedLoadFields',
                              args: {'error': '${snapshot.error}'},
                            ),
                          ),
                        ),
                      );
                    }

                    final fields = snapshot.data ?? [];

                    if (fields.isEmpty) {
                      return Center(child: Text(l10n.t('noFieldsFound')));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: fields.length,
                      itemBuilder: (context, index) {
                        final field = fields[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () => _openField(field),
                            title: Text(field.name),
                            subtitle: Text(
                              '${field.locationName}${(field.fieldType ?? '').isNotEmpty ? ' • ${field.fieldType}' : ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
