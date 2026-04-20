import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/localization/app_localizations.dart';

import 'field_model.dart';
import 'field_repository.dart';

class FieldDetailsScreen extends StatefulWidget {
  const FieldDetailsScreen({super.key, required this.field});

  final FieldModel field;

  @override
  State<FieldDetailsScreen> createState() => _FieldDetailsScreenState();
}

class _FieldDetailsScreenState extends State<FieldDetailsScreen> {
  final FieldRepository _repository = FieldRepository();
  final TextEditingController _reviewController = TextEditingController();

  List<FieldReviewModel> _reviews = <FieldReviewModel>[];
  bool _loadingReviews = true;
  bool _savingReview = false;
  int _selectedRating = 5;

  FieldModel get field => widget.field;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loadingReviews = true;
    });

    try {
      final List<FieldReviewModel> loaded = await _repository.getFieldReviews(
        field.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _reviews = loaded;
        _loadingReviews = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingReviews = false;
      });
    }
  }

  Future<void> _submitReview() async {
    final String text = _reviewController.text.trim();
    if (text.isEmpty || _savingReview) {
      return;
    }

    setState(() {
      _savingReview = true;
    });

    try {
      await _repository.upsertFieldReview(
        fieldId: field.id,
        rating: _selectedRating,
        reviewText: text,
      );
      _reviewController.clear();
      await _loadReviews();
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('reviewPosted'))));
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(l10n.t('failedPostReview', args: {'error': '$error'})),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingReview = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _openInMaps(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final String label = widget.field.name.trim().isEmpty
        ? l10n.t('fieldFallbackName')
        : widget.field.name;
    final String locationQuery = widget.field.fullLocation.trim().isNotEmpty
        ? '${widget.field.fullLocation} ($label)'
        : label;

    final Uri primaryGeo = Uri.parse(
      'geo:${widget.field.latitude},${widget.field.longitude}?q=${Uri.encodeComponent(locationQuery)}',
    );
    final Uri fallbackGoogle = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${widget.field.latitude},${widget.field.longitude}',
    );
    final Uri fallbackApple = Uri.parse(
      'https://maps.apple.com/?ll=${widget.field.latitude},${widget.field.longitude}&q=${Uri.encodeComponent(locationQuery)}',
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
    final List<String> features = field.features;
    final List<String> pros = field.pros;
    final List<String> cons = field.cons;
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
              if (features.isNotEmpty) ...[
                const SizedBox(height: 12),
                _BulletSection(
                  title: 'Features',
                  items: features,
                ),
              ],
              if (pros.isNotEmpty || cons.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _BulletSection(
                            title: 'Pros',
                            items: pros,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BulletSection(
                            title: 'Cons',
                            items: cons,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
              const SizedBox(height: 12),
              _buildReviewComposer(),
              const SizedBox(height: 8),
              _buildReviewsList(),
            ],
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
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

  Widget _buildReviewComposer() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Reviews',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: List<Widget>.generate(5, (int index) {
                final int value = index + 1;
                return IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedRating = value;
                    });
                  },
                  icon: Icon(
                    value <= _selectedRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            TextField(
              controller: _reviewController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Share your experience at this field',
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _savingReview ? null : _submitReview,
                icon: _savingReview
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.rate_review_outlined),
                label: const Text('Post review'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_loadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reviews.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('No reviews yet.'),
        ),
      );
    }

    return Column(
      children: _reviews.map((FieldReviewModel review) {
        final String name = (review.callSign ?? '').trim().isEmpty
            ? 'Operator'
            : review.callSign!;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  (review.avatarUrl ?? '').trim().isNotEmpty
                  ? NetworkImage(review.avatarUrl!)
                  : null,
              child: (review.avatarUrl ?? '').trim().isEmpty
                  ? Text(name[0].toUpperCase())
                  : null,
            ),
            title: Row(
              children: <Widget>[
                Expanded(child: Text(name)),
                _RatingStars(rating: review.rating.toDouble()),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(review.reviewText),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BulletSection extends StatelessWidget {
  const _BulletSection({
    required this.title,
    required this.items,
    this.compact = false,
  });

  final String title;
  final List<String> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && compact) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: compact ? EdgeInsets.zero : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('No details provided.')
            else
              ...items.map((String item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('• '),
                      Expanded(child: Text(item)),
                    ],
                  ),
                );
              }),
          ],
        ),
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
