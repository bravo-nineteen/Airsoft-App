import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';

import 'field_details_screen.dart';
import 'field_map_screen.dart';
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
  double _minRating = 0;
  bool _mapView = false;

  late Future<List<FieldModel>> _fieldsFuture;

  final List<String> _locations = const [
    'All',
    'Tokyo',
    'Chiba',
    'Kanagawa',
    'Saitama',
    'Ibaraki',
    'Yamanashi',
    'Shizuoka',
  ];
  final List<String> _fieldTypes = const [
    'All',
    'Outdoor',
    'Indoor',
    'CQB',
    'Mixed',
  ];

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
      minRating: _minRating,
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
                textInputAction: TextInputAction.search,
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
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      initialValue: _minRating,
                      decoration: InputDecoration(labelText: l10n.t('minRating')),
                      items: [
                        DropdownMenuItem(value: 0, child: Text(l10n.t('any'))),
                        const DropdownMenuItem(value: 3, child: Text('3.0+')),
                        const DropdownMenuItem(value: 4, child: Text('4.0+')),
                        const DropdownMenuItem(value: 4.5, child: Text('4.5+')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _minRating = value ?? 0;
                        });
                        _refreshFields();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text(l10n.list),
                          icon: const Icon(Icons.view_list),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text(l10n.map),
                          icon: const Icon(Icons.map),
                        ),
                      ],
                      selected: {_mapView},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _mapView = selection.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<FieldModel>>(
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
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final List<FieldModel> fields = snapshot.data ?? <FieldModel>[];

              if (fields.isEmpty) {
                return Center(child: Text(l10n.t('noFieldsFound')));
              }

              if (_mapView) {
                return FieldMapScreen(fields: fields);
              }

              return RefreshIndicator(
                onRefresh: () async => _refreshFields(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: fields.length,
                  itemBuilder: (context, index) {
                    final FieldModel field = fields[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        onTap: () => _openField(field),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: field.hasImage
                                ? Image.network(
                                    field.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        _FieldListThumbnailPlaceholder(
                                      name: field.name,
                                    ),
                                  )
                                : _FieldListThumbnailPlaceholder(
                                    name: field.name,
                                  ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(child: Text(field.name)),
                            if (field.isOfficial) ...[
                              const SizedBox(width: 6),
                              const Tooltip(
                                message: 'Official listing',
                                child: Icon(
                                  Icons.verified,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${field.locationName}${(field.fieldType ?? '').isNotEmpty ? ' • ${field.fieldType}' : ''}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FieldListThumbnailPlaceholder extends StatelessWidget {
  const _FieldListThumbnailPlaceholder({
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.terrain, size: 24),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
