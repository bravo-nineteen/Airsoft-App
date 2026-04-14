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

  late Future<List<FieldModel>> _futureFields;

  @override
  void initState() {
    super.initState();
    _futureFields = _repository.getFields();
  }

  Future<void> _refresh() async {
    setState(() {
      _futureFields = _repository.getFields(
        search: _searchController.text,
      );
    });
    await _futureFields;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FutureBuilder<List<FieldModel>>(
        future: _futureFields,
        builder: (context, snapshot) {
          final fields = snapshot.data ?? const <FieldModel>[];
          return FloatingActionButton.extended(
            onPressed: fields.isEmpty
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FieldMapScreen(fields: fields),
                      ),
                    );
                  },
            icon: const Icon(Icons.map),
            label: const Text('Map'),
          );
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search fields',
                suffixIcon: IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => _refresh(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<FieldModel>>(
                future: _futureFields,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final fields = snapshot.data ?? [];
                  if (fields.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 160),
                        Center(child: Text('No fields found.')),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: fields.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final field = fields[index];
                      return Card(
                        child: ListTile(
                          title: Text(field.name),
                          subtitle: Text(field.locationName),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FieldDetailsScreen(field: field),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
