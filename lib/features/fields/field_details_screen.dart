import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/localization/app_localizations.dart';

import 'field_model.dart';

class FieldDetailsScreen extends StatelessWidget {
  const FieldDetailsScreen({super.key, required this.field});

  final FieldModel field;

  Future<void> _openInMaps(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final String label = field.name.trim().isEmpty
        ? l10n.t('fieldFallbackName')
        : field.name;
    final String locationQuery = field.fullLocation.trim().isNotEmpty
        ? '${field.fullLocation} ($label)'
        : label;

    final Uri primaryGeo = Uri.parse(
      'geo:${field.latitude},${field.longitude}?q=${Uri.encodeComponent(locationQuery)}',
    );
    final Uri fallbackGoogle = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${field.latitude},${field.longitude}',
    );
    final Uri fallbackApple = Uri.parse(
      'https://maps.apple.com/?ll=${field.latitude},${field.longitude}&q=${Uri.encodeComponent(locationQuery)}',
    );

    final bool openedGeo = await launchUrl(
      primaryGeo,
      mode: LaunchMode.externalApplication,
    );
    if (openedGeo) {
      return;
    }

    final bool openedGoogle = await launchUrl(
      fallbackGoogle,
      mode: LaunchMode.externalApplication,
    );
    if (openedGoogle) {
      return;
    }

    final bool openedApple = await launchUrl(
      fallbackApple,
      mode: LaunchMode.externalApplication,
    );

    if (!openedApple && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('failedOpenMapApp'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final secondaryLine = [
      if ((field.prefecture ?? '').isNotEmpty) field.prefecture,
      if ((field.city ?? '').isNotEmpty) field.city,
      if ((field.fieldType ?? '').isNotEmpty) field.fieldType,
    ].whereType<String>().join(' • ');

    return Scaffold(
      appBar: AppBar(title: Text(field.name)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isTablet = constraints.maxWidth >= 900;

          final imagePanel = ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: isTablet ? 4 / 5 : 16 / 9,
              child: (field.imageUrl ?? '').isNotEmpty
                  ? Image.network(
                      field.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _FieldImagePlaceholder(name: field.name),
                    )
                  : _FieldImagePlaceholder(name: field.name),
            ),
          );

          final detailsPanel = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                field.fullLocation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => _openInMaps(context),
                icon: const Icon(Icons.map_outlined),
                label: Text(l10n.t('openInMaps')),
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
                  Expanded(
                    child: Text(
                      field.rating != null
                          ? '${field.rating!.toStringAsFixed(1)}${field.reviewCount != null ? ' (${field.reviewCount})' : ''}'
                          : l10n.t('noRatingYet'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    field.description.isEmpty
                        ? l10n.t('noDescriptionAvailable')
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
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openInMaps(context),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.pin_drop),
                  title: Text(l10n.t('coordinates')),
                  subtitle: Text('${field.latitude}, ${field.longitude}'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openInMaps(context),
                ),
              ),
            ],
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: isTablet
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: imagePanel),
                      const SizedBox(width: 20),
                      Expanded(flex: 6, child: detailsPanel),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      imagePanel,
                      const SizedBox(height: 16),
                      detailsPanel,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _FieldImagePlaceholder extends StatelessWidget {
  const _FieldImagePlaceholder({required this.name});

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
          Text(name, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating});

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

        return Icon(icon, size: 18, color: Colors.amber);
      }),
    );
  }
}
