import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'field_details_screen.dart';
import 'field_model.dart';

class FieldMapScreen extends StatelessWidget {
  const FieldMapScreen({
    super.key,
    required this.fields,
  });

  final List<FieldModel> fields;

  @override
  Widget build(BuildContext context) {
    final List<FieldModel> validFields = fields
        .where((f) => f.latitude != 0 && f.longitude != 0)
        .toList();

    final LatLng center = validFields.isNotEmpty
        ? LatLng(validFields.first.latitude, validFields.first.longitude)
        : const LatLng(35.681236, 139.767125);

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: validFields.length == 1 ? 12 : 7,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.airsoft_app',
            ),
            MarkerLayer(
              markers: validFields.map((field) {
                return Marker(
                  point: LatLng(field.latitude, field.longitude),
                  width: 56,
                  height: 56,
                  child: _FieldMarker(
                    field: field,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FieldDetailsScreen(field: field),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        if (validFields.isEmpty)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No field coordinates available yet. Showing the default map area.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FieldMarker extends StatelessWidget {
  const _FieldMarker({
    required this.field,
    required this.onTap,
  });

  final FieldModel field;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = field.rating ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 8,
                  color: Colors.black26,
                ),
              ],
            ),
            child: Text(
              rating > 0 ? '${field.name} ★${rating.toStringAsFixed(1)}' : field.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            Icons.location_on,
            size: 28,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}