import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../core/location/location_preferences.dart';
import 'shop_details_screen.dart';
import 'shop_model.dart';
import 'shop_repository.dart';
import 'user_submit_shop_screen.dart';

class ShopsScreen extends StatefulWidget {
  const ShopsScreen({super.key});

  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  final ShopRepository _repository = ShopRepository();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCountry = LocationPreferences.allCountries;
  String _selectedPrefecture = 'All';
  final Set<String> _selectedFeatures = <String>{};
  bool _featuresExpanded = false;
  late Future<List<ShopModel>> _shopsFuture;

  List<ShopModel> _allShops = const [];
  static const int _lazyPageSize = 20;
  int _visibleCount = _lazyPageSize;

  List<String> get _regions {
    // Merge predefined regions for the selected country with any regions
    // already present in the loaded data.
    final Set<String> values = <String>{
      ...LocationPreferences.getRegions(_selectedCountry),
    };
    for (final ShopModel shop in _allShops.where((ShopModel s) {
      return LocationPreferences.matchesCountry(
        selectedCountry: _selectedCountry,
        country: s.country,
        prefecture: s.prefecture,
        address: s.address,
      );
    })) {
      for (final String value in <String>[
        shop.prefecture ?? '',
        shop.city ?? '',
      ]) {
        final String trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          values.add(trimmed);
        }
      }
    }
    final List<String> sorted =
        values.where((String item) => item != 'All').toList()..sort(
          (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
        );
    return <String>['All', ...sorted];
  }

  List<String> get _availableFeatures {
    final Set<String> values = <String>{};
    final Iterable<ShopModel> scope = _allShops.where((ShopModel shop) {
      final bool matchesCountry = LocationPreferences.matchesCountry(
        selectedCountry: _selectedCountry,
        country: shop.country,
        prefecture: shop.prefecture,
        address: shop.address,
      );
      if (!matchesCountry) {
        return false;
      }
      if (_selectedPrefecture == 'All') {
        return true;
      }
      final String selected = _selectedPrefecture.toLowerCase();
      return (shop.prefecture ?? '').toLowerCase() == selected ||
          (shop.city ?? '').toLowerCase() == selected;
    });

    for (final ShopModel shop in scope) {
      values.addAll(
        shop.features.where((String feature) => feature.trim().isNotEmpty),
      );
    }

    final List<String> sorted = values.toList()
      ..sort(
        (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _restoreCountryPreference();
    _shopsFuture = _loadShops();
  }

  Future<void> _restoreCountryPreference() async {
    final String savedCountry =
        await LocationPreferences.loadPreferredCountry();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedCountry = savedCountry;
    });
    _refresh();
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
    final List<ShopModel> filtered = _repository.applyFilters(
      _allShops,
      search: _searchController.text,
      prefecture: _selectedPrefecture,
      features: _selectedFeatures.toList(),
    );
    final List<ShopModel> scoped = filtered.where((ShopModel shop) {
      return LocationPreferences.matchesCountry(
        selectedCountry: _selectedCountry,
        country: shop.country,
        prefecture: shop.prefecture,
        address: shop.address,
      );
    }).toList();
    _visibleCount = _lazyPageSize;
    return scoped;
  }

  void _refresh() {
    setState(() {
      _shopsFuture = _loadShops(force: true);
    });
  }

  void _loadMoreIfNeeded(int total, int index) {
    if (index < _visibleCount - 6) {
      return;
    }
    if (_visibleCount >= total) {
      return;
    }
    setState(() {
      _visibleCount = (_visibleCount + _lazyPageSize).clamp(0, total);
    });
  }

  void _applyFilters() {
    setState(() {
      _visibleCount = _lazyPageSize;
      _shopsFuture = Future.value(
        _repository
            .applyFilters(
              _allShops,
              search: _searchController.text,
              prefecture: _selectedPrefecture,
              features: _selectedFeatures.toList(),
            )
            .where((ShopModel shop) {
              return LocationPreferences.matchesCountry(
                selectedCountry: _selectedCountry,
                country: shop.country,
                prefecture: shop.prefecture,
                address: shop.address,
              );
            })
            .toList(),
      );
    });
  }

  void _openShop(ShopModel shop) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ShopDetailsScreen(shop: shop)));
  }

  Future<void> _openSubmitShopScreen() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const UserSubmitShopScreen()));
    if (!mounted) return;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 920;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText:
                              '${l10n.t('searchShopsHint')} (name, address, features)',
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
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          SizedBox(
                            width: isWide ? 260 : double.infinity,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCountry,
                              decoration: const InputDecoration(
                                labelText: 'Country',
                              ),
                              items: LocationPreferences.countries
                                  .map(
                                    (String c) => DropdownMenuItem<String>(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (String? value) {
                                setState(() {
                                  _selectedCountry =
                                      value ?? LocationPreferences.allCountries;
                                  _selectedPrefecture = 'All';
                                  _selectedFeatures.clear();
                                });
                                LocationPreferences.savePreferredCountry(
                                  _selectedCountry,
                                );
                                _applyFilters();
                              },
                            ),
                          ),
                          SizedBox(
                            width: isWide ? 260 : double.infinity,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedPrefecture,
                              decoration: const InputDecoration(
                                labelText: 'State / Prefecture',
                              ),
                              items: _regions
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedPrefecture = value ?? 'All';
                                  _selectedFeatures.removeWhere(
                                    (String feature) =>
                                        !_availableFeatures.contains(feature),
                                  );
                                });
                                _applyFilters();
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_availableFeatures.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              title: Row(
                                children: [
                                  Text('Features', style: Theme.of(context).textTheme.titleSmall),
                                  if (_selectedFeatures.isNotEmpty) ...<Widget>[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_selectedFeatures.length}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              initiallyExpanded: _featuresExpanded,
                              onExpansionChanged: (v) => setState(() => _featuresExpanded = v),
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _availableFeatures.map((String feature) {
                                    final bool isSelected = _selectedFeatures.contains(feature);
                                    return FilterChip(
                                      label: Text(feature),
                                      selected: isSelected,
                                      onSelected: (bool selected) {
                                        setState(() {
                                          if (selected) _selectedFeatures.add(feature);
                                          else _selectedFeatures.remove(feature);
                                        });
                                        _applyFilters();
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _openSubmitShopScreen,
                          icon: const Icon(Icons.storefront_outlined),
                          label: const Text('Add Shop'),
                        ),
                      ),
                    ],
                  ),
                ),
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
                          l10n.t(
                            'failedLoadShops',
                            args: {'error': '${snapshot.error}'},
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final shops = snapshot.data ?? <ShopModel>[];
                  final int visible = _visibleCount.clamp(0, shops.length);

                  if (shops.isEmpty) {
                    return Center(child: Text(l10n.t('noShopsFound')));
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: isWide
                        ? GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 2.25,
                                ),
                            itemCount: visible,
                            itemBuilder: (context, index) {
                              _loadMoreIfNeeded(shops.length, index);
                              return _ShopDirectoryCard(
                                shop: shops[index],
                                onTap: () => _openShop(shops[index]),
                              );
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: visible,
                            itemBuilder: (context, index) {
                              _loadMoreIfNeeded(shops.length, index);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ShopDirectoryCard(
                                  shop: shops[index],
                                  onTap: () => _openShop(shops[index]),
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
      },
    );
  }
}

class _ShopDirectoryCard extends StatelessWidget {
  const _ShopDirectoryCard({required this.shop, required this.onTap});

  final ShopModel shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: shop.hasImage
                      ? Image.network(
                          shop.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _ShopThumbnailPlaceholder(name: shop.name),
                        )
                      : _ShopThumbnailPlaceholder(name: shop.name),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            shop.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (shop.isOfficial)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Tooltip(
                              message: 'Official listing',
                              child: Icon(
                                Icons.verified,
                                size: 16,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shop.locationDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((shop.openingTimes ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        shop.openingTimes!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _ShopMetaPill(
                          icon: Icons.place_outlined,
                          label: shop.address.isEmpty
                              ? shop.locationDisplay
                              : shop.address,
                        ),
                        if ((shop.phoneNumber ?? '').isNotEmpty)
                          _ShopMetaPill(
                            icon: Icons.phone_outlined,
                            label: shop.phoneNumber!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopMetaPill extends StatelessWidget {
  const _ShopMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
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
