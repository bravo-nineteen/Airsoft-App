import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import 'shop_details_screen.dart';
import 'shop_model.dart';
import 'shop_repository.dart';

class ShopsScreen extends StatefulWidget {
  const ShopsScreen({super.key});

  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  final ShopRepository _repository = ShopRepository();
  final TextEditingController _searchController = TextEditingController();

  String _selectedPrefecture = 'All';
  late Future<List<ShopModel>> _shopsFuture;

  final List<String> _prefectures = const [
    'All',
    'Tokyo',
    'Hokkaido',
    'Aomori',
    'Iwate',
    'Miyagi',
    'Akita',
    'Yamagata',
    'Fukushima',
    'Ibaraki',
    'Tochigi',
    'Gunma',
    'Saitama',
    'Chiba',
    'Kanagawa',
    'Niigata',
    'Toyama',
    'Ishikawa',
    'Fukui',
    'Yamanashi',
    'Nagano',
    'Shizuoka',
    'Aichi',
    'Mie',
    'Shiga',
    'Kyoto',
    'Osaka',
    'Hyogo',
    'Nara',
    'Wakayama',
    'Hiroshima',
    'Okayama',
    'Fukuoka',
    'Okinawa',
  ];

  List<ShopModel> _allShops = const [];

  @override
  void initState() {
    super.initState();
    _shopsFuture = _loadShops();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ShopModel>> _loadShops({bool force = false}) async {
    if (_allShops.isEmpty || force) {
      _allShops = await _repository.getShops();
    }
    return _repository.applyFilters(
      _allShops,
      search: _searchController.text,
      prefecture: _selectedPrefecture,
    );
  }

  void _refresh() {
    setState(() {
      _shopsFuture = _loadShops(force: true);
    });
  }

  void _applyFilters() {
    setState(() {
      _shopsFuture = Future.value(
        _repository.applyFilters(
          _allShops,
          search: _searchController.text,
          prefecture: _selectedPrefecture,
        ),
      );
    });
  }

  void _openShop(ShopModel shop) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ShopDetailsScreen(shop: shop)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.t('searchShopsHint'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refresh,
                  ),
                ),
                onChanged: (_) => _applyFilters(),
                onSubmitted: (_) => _applyFilters(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedPrefecture,
                decoration: InputDecoration(labelText: l10n.t('prefecture')),
                items: _prefectures
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedPrefecture = value ?? 'All');
                  _applyFilters();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ShopModel>>(
            future: _shopsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.t('failedLoadShops',
                          args: {'error': '${snapshot.error}'}),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final shops = snapshot.data ?? <ShopModel>[];

              if (shops.isEmpty) {
                return Center(child: Text(l10n.t('noShopsFound')));
              }

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: shops.length,
                  itemBuilder: (context, index) {
                    final shop = shops[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        onTap: () => _openShop(shop),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: shop.hasImage
                                ? Image.network(
                                    shop.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        _ShopThumbnailPlaceholder(
                                            name: shop.name),
                                  )
                                : _ShopThumbnailPlaceholder(name: shop.name),
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(child: Text(shop.name)),
                            if (shop.isOfficial) ...[
                              const SizedBox(width: 6),
                              const Tooltip(
                                message: 'Official listing',
                                child: Icon(Icons.verified,
                                    size: 16, color: Colors.blue),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(shop.locationDisplay),
                            if ((shop.openingTimes ?? '').isNotEmpty)
                              Text(
                                shop.openingTimes!,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        isThreeLine: (shop.openingTimes ?? '').isNotEmpty,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ShopThumbnailPlaceholder extends StatelessWidget {
  const _ShopThumbnailPlaceholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storefront, size: 22),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
