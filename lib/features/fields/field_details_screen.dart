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
    final secondaryLine = [
      if ((field.prefecture ?? '').isNotEmpty) field.prefecture,
      if ((field.city ?? '').isNotEmpty) field.city,
      if ((field.fieldType ?? '').isNotEmpty) field.fieldType,
    ].whereType<String>().join(' • ');

    return Scaffold(
      appBar: AppBar(title: Text(field.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: (field.imageUrl ?? '').isNotEmpty
                  ? Image.network(
                      field.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _FieldImagePlaceholder(
                        name: field.name,
                      ),
                    )
                  : _FieldImagePlaceholder(name: field.name),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            field.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            field.fullLocation,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (secondaryLine.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              secondaryLine,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _RatingStars(rating: field.rating ?? 0),
              const SizedBox(width: 8),
              Text(
                field.rating != null
                    ? '${field.rating!.toStringAsFixed(1)}${field.reviewCount != null ? ' (${field.reviewCount})' : ''}'
                    : 'No rating yet',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                field.description.isEmpty
                    ? 'No description available.'
                    : field.description,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.place),
              title: Text(field.locationName),
              subtitle: Text(field.fullLocation),
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

class _FieldImagePlaceholder extends StatelessWidget {
  const _FieldImagePlaceholder({
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
          const Icon(Icons.terrain, size: 56),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({
    required this.rating,
  });

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final icon = rating >= starValue
            ? Icons.star
            : rating >= starValue - 0.5
                ? Icons.star_half
                : Icons.star_border;

        return Icon(
          icon,
          size: 18,
          color: Colors.amber,
        );
      }),
    );
  }
}