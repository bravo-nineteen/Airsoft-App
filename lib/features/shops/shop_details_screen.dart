import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/widgets/persistent_shell_bottom_nav.dart';
import 'shop_model.dart';
import 'shop_repository.dart';
import 'shop_review_model.dart';

class ShopDetailsScreen extends StatefulWidget {
  const ShopDetailsScreen({super.key, required this.shop});

  final ShopModel shop;

  @override
  State<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends State<ShopDetailsScreen> {
  final ShopRepository _repository = ShopRepository();
  late Future<List<ShopReviewModel>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _repository.getShopReviews(widget.shop.id);
  }

  ShopModel get shop => widget.shop;

  void _reloadReviews() {
    setState(() {
      _reviewsFuture = _repository.getShopReviews(shop.id);
    });
  }

  Future<void> _callPhone(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openExternalMap(double latitude, double longitude) async {
    final String label = shop.name.trim().isEmpty ? 'Shop' : shop.name.trim();
    final Uri primaryGeo = Uri.parse(
      'geo:$latitude,$longitude?q=${Uri.encodeComponent(label)}',
    );
    final Uri fallbackGoogle = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    final Uri fallbackApple = Uri.parse(
      'https://maps.apple.com/?ll=$latitude,$longitude&q=${Uri.encodeComponent(label)}',
    );

    if (await launchUrl(primaryGeo, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (await launchUrl(fallbackGoogle, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (mounted) {
      await launchUrl(fallbackApple, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showWriteReviewDialog() async {
    int selectedRating = 0;
    final bodyController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Write a Review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rating'),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return IconButton(
                        onPressed: () =>
                            setDialogState(() => selectedRating = star),
                        icon: Icon(
                          star <= selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bodyController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Share your experience (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedRating == 0
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;
    try {
      await _repository.submitShopReview(
        shopId: shop.id,
        rating: selectedRating,
        body: bodyController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted.')),
      );
      _reloadReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(shop.name),
        actions: [
          if (shop.isOfficial)
            const Tooltip(
              message: 'Official listing',
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.verified, color: Colors.blue),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const PersistentShellBottomNav(selectedIndex: 4),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hero image
          if (shop.hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: Image.network(
                  shop.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 200,
                    color: colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.storefront, size: 48),
                  ),
                ),
              ),
            ),
          if (shop.hasImage) const SizedBox(height: 16),

          // Shop name + location
          Text(shop.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          if ((shop.prefecture ?? '').isNotEmpty ||
              (shop.city ?? '').isNotEmpty)
            Text(
              shop.locationDisplay,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.secondary),
            ),
          const SizedBox(height: 16),

          // Address
          _DetailCard(
            icon: Icons.location_on_outlined,
            title: l10n.t('address'),
            value: shop.address.isEmpty ? null : shop.address,
            onTap: shop.address.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: shop.address));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text(l10n.t('addressCopied'))),
                    );
                  },
            trailing: shop.address.isEmpty
                ? null
                : const Icon(Icons.copy, size: 18),
          ),

          if (shop.latitude != null && shop.longitude != null) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 220,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(shop.latitude!, shop.longitude!),
                        initialZoom: 14,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.airsoftonlinejapan.fieldops',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(shop.latitude!, shop.longitude!),
                              width: 52,
                              height: 52,
                              child: const Icon(
                                Icons.location_pin,
                                size: 42,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.map_outlined, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Map location',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _openExternalMap(
                            shop.latitude!,
                            shop.longitude!,
                          ),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Open Maps'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Opening times
          _DetailCard(
            icon: Icons.access_time_outlined,
            title: l10n.t('openingTimes'),
            value: shop.openingTimes,
          ),

          // Phone
          _DetailCard(
            icon: Icons.phone_outlined,
            title: l10n.t('phoneNumber'),
            value: shop.phoneNumber,
            onTap: (shop.phoneNumber ?? '').isNotEmpty
                ? () => _callPhone(context, shop.phoneNumber!)
                : null,
            trailing: (shop.phoneNumber ?? '').isNotEmpty
                ? const Icon(Icons.call, size: 18)
                : null,
          ),

          // Features
          if (shop.features.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star_outline,
                            size: 20, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          l10n.t('features'),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: shop.features
                          .map(
                            (f) => Chip(
                              label: Text(f),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Reviews
          const SizedBox(height: 8),
          FutureBuilder<List<ShopReviewModel>>(
            future: _reviewsFuture,
            builder: (context, snapshot) {
              final reviews = snapshot.data ?? [];
              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id ?? '';
              final hasReviewed =
                  reviews.any((r) => r.userId == currentUserId);

              double avgRating = 0;
              if (reviews.isNotEmpty) {
                avgRating = reviews.fold(0, (s, r) => s + r.rating) /
                    reviews.length;
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.reviews_outlined),
                          const SizedBox(width: 8),
                          Text(
                            'Reviews',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          if (reviews.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 2),
                                Text(avgRating.toStringAsFixed(1)),
                                Text(' (${reviews.length})'),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (snapshot.connectionState != ConnectionState.done)
                        const LinearProgressIndicator(minHeight: 2)
                      else if (reviews.isEmpty)
                        const Text('No reviews yet. Be the first!')
                      else
                        ...reviews.map((r) => _ReviewTile(review: r)),
                      const SizedBox(height: 8),
                      if (!hasReviewed)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showWriteReviewDialog,
                            icon: const Icon(Icons.rate_review_outlined),
                            label: const Text('Write a Review'),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final ShopReviewModel review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                review.callSign ?? 'Anonymous',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              ...List.generate(
                5,
                (i) => Icon(
                  i < review.rating ? Icons.star : Icons.star_border,
                  size: 14,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          if ((review.body ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(review.body!),
            ),
          const Divider(),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if ((value ?? '').trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
          subtitle: Text(value!),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }
}
