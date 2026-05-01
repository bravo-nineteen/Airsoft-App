import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../core/content/app_content_preloader.dart';
import '../admin/admin_create_field_screen.dart';
import '../admin/admin_repository.dart';

import 'field_details_screen.dart';
import 'field_map_screen.dart';
import 'field_model.dart';
import 'field_repository.dart';
import 'user_submit_field_screen.dart';

class FieldsScreen extends StatefulWidget {
  const FieldsScreen({super.key});

  @override
  State<FieldsScreen> createState() => _FieldsScreenState();
}

class _FieldsScreenState extends State<FieldsScreen> {
  final AppContentPreloader _contentPreloader = AppContentPreloader.instance;
  final FieldRepository _repository = FieldRepository();
  final AdminRepository _adminRepository = AdminRepository();
  final TextEditingController _searchController = TextEditingController();

  String _selectedLocation = 'All';
  String _selectedFieldType = 'All';
  double _minRating = 0;
  bool _mapView = false;

  late Future<List<FieldModel>> _fieldsFuture;
  late Future<bool> _isAdminFuture;

  List<String> get _locations {
    final Set<String> values = <String>{'All'};
    for (final FieldModel field in _contentPreloader.fields) {
      for (final String value in <String>[
        field.prefecture ?? '',
        field.city ?? '',
        field.locationName,
      ]) {
        final String trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          values.add(trimmed);
        }
      }
    }
    final List<String> sorted = values.where((String item) => item != 'All').toList()
      ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return <String>['All', ...sorted];
  }

  List<String> get _fieldTypes {
    final Set<String> values = <String>{'All'};
    for (final FieldModel field in _contentPreloader.fields) {
      final String type = (field.fieldType ?? '').trim();
      if (type.isNotEmpty) {
        values.add(type);
      }
    }
    final List<String> sorted = values.where((String item) => item != 'All').toList()
      ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return <String>['All', ...sorted];
  }

  @override
  void initState() {
    super.initState();
    _contentPreloader.fieldsRevision.addListener(_handleSharedFieldsUpdated);
    _fieldsFuture = _loadFields();
    _isAdminFuture = _adminRepository.isCurrentUserAdmin();
  }

  @override
  void dispose() {
    _contentPreloader.fieldsRevision.removeListener(_handleSharedFieldsUpdated);
    _searchController.dispose();
    super.dispose();
  }

  Future<List<FieldModel>> _loadFields({bool preferCache = true}) async {
    final List<FieldModel> source = await _contentPreloader.loadFields(
      preferCache: preferCache,
    );
    return _repository.applyFilters(
      source,
      search: _searchController.text,
      location: _selectedLocation,
      fieldType: _selectedFieldType,
      minRating: _minRating,
    );
  }

  void _handleSharedFieldsUpdated() {
    if (!mounted) {
      return;
    }

    setState(() {
      _fieldsFuture = Future<List<FieldModel>>.value(
        _repository.applyFilters(
          _contentPreloader.fields,
          search: _searchController.text,
          location: _selectedLocation,
          fieldType: _selectedFieldType,
          minRating: _minRating,
        ),
      );
    });
  }

  void _refreshFields() {
    setState(() {
      _fieldsFuture = _loadFields(preferCache: false);
    });
  }

  void _openField(FieldModel field) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => FieldDetailsScreen(field: field)));
  }

  Future<void> _openCreateFieldScreen() async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminCreateFieldScreen()),
    );

    if (!mounted || created != true) {
      return;
    }

    _refreshFields();
  }

  Future<void> _openSubmitFieldScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UserSubmitFieldScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 920;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: isWide ? 260 : double.infinity,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedLocation,
                              decoration: InputDecoration(labelText: l10n.location),
                              items: _locations
                                  .map(
                                    (value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedLocation = value ?? 'All';
                                });
                                _refreshFields();
                              },
                            ),
                          ),
                          SizedBox(
                            width: isWide ? 220 : double.infinity,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedFieldType,
                              decoration: InputDecoration(
                                labelText: l10n.t('fieldType'),
                              ),
                              items: _fieldTypes
                                  .map(
                                    (value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedFieldType = value ?? 'All';
                                });
                                _refreshFields();
                              },
                            ),
                          ),
                          SizedBox(
                            width: isWide ? 180 : double.infinity,
                            child: DropdownButtonFormField<double>(
                              initialValue: _minRating,
                              decoration: InputDecoration(
                                labelText: l10n.t('minRating'),
                              ),
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
                          SizedBox(
                            width: isWide ? 220 : double.infinity,
                            child: SegmentedButton<bool>(
                              segments: [
                                ButtonSegment<bool>(
                                  value: false,
                                  label: Text(l10n.list),
                                  icon: const Icon(Icons.view_agenda_outlined),
                                ),
                                ButtonSegment<bool>(
                                  value: true,
                                  label: Text(l10n.map),
                                  icon: const Icon(Icons.map_outlined),
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
              const SizedBox(height: 12),
              FutureBuilder<bool>(
                future: _isAdminFuture,
                builder: (context, snapshot) {
                  if (snapshot.data == true) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _openCreateFieldScreen,
                        icon: const Icon(Icons.add_business),
                        label: const Text('Add Field (Admin)'),
                      ),
                    );
                  }

                  // Regular users can submit a field for review.
                  return Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _openSubmitFieldScreen,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: Text(l10n.t('submitField')),
                    ),
                  );
                },
              ),
                    ],
                  ),
                ),
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
                if (isWide) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          flex: 7,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: FieldMapScreen(fields: fields),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 4,
                          child: _FieldResultsPane(
                            fields: fields,
                            onOpenField: _openField,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return FieldMapScreen(fields: fields);
              }

              return RefreshIndicator(
                onRefresh: () async => _refreshFields(),
                child: isWide
                    ? GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 2.15,
                        ),
                        itemCount: fields.length,
                        itemBuilder: (context, index) {
                          return _FieldDirectoryCard(
                            field: fields[index],
                            onTap: () => _openField(fields[index]),
                          );
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: fields.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _FieldDirectoryCard(
                              field: fields[index],
                              onTap: () => _openField(fields[index]),
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
      },
    );
  }
}

class _FieldResultsPane extends StatelessWidget {
  const _FieldResultsPane({required this.fields, required this.onOpenField});

  final List<FieldModel> fields;
  final ValueChanged<FieldModel> onOpenField;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: fields.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          final FieldModel field = fields[index];
          return _FieldDirectoryCard(
            field: field,
            compact: true,
            onTap: () => onOpenField(field),
          );
        },
      ),
    );
  }
}

class _FieldDirectoryCard extends StatelessWidget {
  const _FieldDirectoryCard({
    required this.field,
    required this.onTap,
    this.compact = false,
  });

  final FieldModel field;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String subtitle = [
      field.locationName,
      if ((field.fieldType ?? '').trim().isNotEmpty) field.fieldType!,
    ].where((String item) => item.trim().isNotEmpty).join(' • ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: compact ? 68 : 82,
                  height: compact ? 68 : 82,
                  child: field.hasImage
                      ? Image.network(
                          field.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _FieldListThumbnailPlaceholder(name: field.name),
                        )
                      : _FieldListThumbnailPlaceholder(name: field.name),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            field.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (field.isOfficial)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Tooltip(
                              message: 'Official listing',
                              child: Icon(
                                Icons.verified,
                                size: 16,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _FieldMetaPill(
                          icon: Icons.map_outlined,
                          label: field.fullLocation,
                        ),
                        _FieldMetaPill(
                          icon: Icons.star_outline,
                          label: field.rating != null
                              ? field.rating!.toStringAsFixed(1)
                              : AppLocalizations.of(context).t('noRatingYet'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldMetaPill extends StatelessWidget {
  const _FieldMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldListThumbnailPlaceholder extends StatelessWidget {
  const _FieldListThumbnailPlaceholder({required this.name});

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
