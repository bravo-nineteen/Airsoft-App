import 'package:flutter/material.dart';

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by field name or location',
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
                      decoration: const InputDecoration(labelText: 'Field Type'),
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
            ],
          ),
        ),
        Expanded(
          child: _mapView
              ? const Center(child: Text('Map view placeholder'))
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
                          child: Text('Failed to load fields: ${snapshot.error}'),
                        ),
                      );
                    }

                    final fields = snapshot.data ?? [];

                    if (fields.isEmpty) {
                      return const Center(child: Text('No fields found.'));
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
