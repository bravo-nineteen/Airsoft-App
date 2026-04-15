import 'package:flutter/material.dart';

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
                  hintText: 'Search field name, 日本語, location, type, description',
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
                      decoration: const InputDecoration(labelText: 'Location'),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedFieldType,
                      decoration: const InputDecoration(labelText: 'Field Type'),
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
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      initialValue: _minRating,
                      decoration: const InputDecoration(labelText: 'Min Rating'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Any')),
                        DropdownMenuItem(value: 3, child: Text('3.0+')),
                        DropdownMenuItem(value: 4, child: Text('4.0+')),
                        DropdownMenuItem(value: 4.5, child: Text('4.5+')),
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
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('List'),
                          icon: Icon(Icons.view_list),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Map'),
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
                      'Failed to load fields: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final fields = snapshot.data ?? [];

              if (fields.isEmpty) {
                return const Center(child: Text('No fields found.'));
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
                    final field = fields[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FieldListCard(
                        field: field,
                        onTap: () => _openField(field),
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

class _FieldListCard extends StatelessWidget {
  const _FieldListCard({
    required this.field,
    required this.onTap,
  });

  final FieldModel field;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratingText = field.rating != null
        ? field.rating!.toStringAsFixed(1)
        : 'No rating';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: (field.imageUrl ?? '').isNotEmpty
                      ? Image.network(
                          field.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _FieldThumbFallback(field: field),
                        )
                      : _FieldThumbFallback(field: field),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      field.fullLocation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 18, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(ratingText),
                        if ((field.fieldType ?? '').isNotEmpty) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.forest, size: 18),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              field.fieldType!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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

class _FieldThumbFallback extends StatelessWidget {
  const _FieldThumbFallback({
    required this.field,
  });

  final FieldModel field;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(Icons.terrain, size: 32),
      ),
    );
  }
}