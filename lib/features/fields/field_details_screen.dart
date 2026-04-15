import 'package:flutter/material.dart';

import 'field_model.dart';

class FieldDetailsScreen extends StatelessWidget {
  const FieldDetailsScreen({
    super.key,
    required this.field,
  });

  final FieldModel field;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(field.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(field.description.isEmpty
                  ? 'No description available.'
                  : field.description),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.place),
              title: Text(field.locationName),
              subtitle: Text(
                [
                  if ((field.prefecture ?? '').isNotEmpty) field.prefecture,
                  if ((field.city ?? '').isNotEmpty) field.city,
                  if ((field.fieldType ?? '').isNotEmpty) field.fieldType,
                ].whereType<String>().join(' • '),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.pin_drop),
              title: const Text('Coordinates'),
              subtitle: Text('${field.latitude}, ${field.longitude}'),
            ),
          ),
        ],
      ),
    );
  }
}
