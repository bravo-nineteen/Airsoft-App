import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/localization/app_localizations.dart';
import 'shop_model.dart';

class ShopDetailsScreen extends StatelessWidget {
  const ShopDetailsScreen({super.key, required this.shop});

  final ShopModel shop;

  Future<void> _callPhone(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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
