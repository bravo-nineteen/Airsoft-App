import 'package:flutter/material.dart';

import 'field_model.dart';

class FieldMapScreen extends StatelessWidget {
  const FieldMapScreen({
    super.key,
    required this.fields,
  });

  final List<FieldModel> fields;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Map')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: fields.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final field = fields[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.map),
              title: Text(field.name),
              subtitle: Text(
                '${field.latitude.toStringAsFixed(5)}, '
                '${field.longitude.toStringAsFixed(5)}',
              ),
            ),
          );
        },
      ),
    );
  }
}
