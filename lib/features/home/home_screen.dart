import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum HomeFeedItemType {
  blog,
  event,
  news,
}

class HomeFeedItem {
  final String id;
  final HomeFeedItemType type;
  final String title;
  final String subtitle;
  final String body;
  final String? imageUrl;
  final DateTime date;
  final String? sourceLabel;
  final String? externalUrl;
  final Map<String, dynamic> raw;

  const HomeFeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.date,
    required this.raw,
    this.imageUrl,
    this.sourceLabel,
    this.externalUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'subtitle': subtitle,
      'body': body,
      'imageUrl': imageUrl,
      'date': date.toIso8601String(),
      'sourceLabel': sourceLabel,
      'externalUrl': externalUrl,
      'raw': raw,
    };
  }

  factory HomeFeedItem.fromJson(Map<String, dynamic> json) {
    return HomeFeedItem(
      id: json['id'] as String? ?? '',
      type: HomeFeedItemType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => HomeFeedItemType.news,
      ),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      body: json['body'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      sourceLabel: json['sourceLabel'] as String?,
      externalUrl: json['externalUrl'] as String?,
      raw: (json['raw'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _cacheKey = 'home_feed_cache_v1';
  static const String _lastUpdatedKey = 'home_feed_last_updated_v1';
  static const String _blogEndpoint =
      'https://airsoftonlinejapan.com/wp-json/wp/v2/posts?_embed&per_page=10';

  final SupabaseClient _supabase = Supabase.instance.client;

  List<HomeFeedItem> _items = const [];
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await _loadCache();
    await _refreshFeed();
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    final lastUpdated = prefs.getString(_lastUpdatedKey);

    if (cached == null || cached.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(cached) as List<dynamic>;
      final items = decoded
          .map((entry) => HomeFeedItem.fromJson(Map<String, dynamic>.from(entry as Map)))
          .toList();

      setState(() {
        _items = items;
        _lastUpdated = lastUpdated != null ? DateTime.tryParse(lastUpdated) : null;
        _isInitialLoading = false;
      });
    } catch (_) {
      // Ignore broken cache.
    }
  }

  Future<void> _saveCache(List<HomeFeedItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((item) => item.toJson()).toList());
    final now = DateTime.now().toIso8601String();

    await prefs.setString(_cacheKey, encoded);
    await prefs.setString(_lastUpdatedKey, now);

    _lastUpdated = DateTime.tryParse(now);
  }

  Future<void> _refreshFeed() async {
    if (!mounted) return;

    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<List<HomeFeedItem>>([
        _fetchBlogPosts(),
        _fetchEvents(),
        _buildAppNews(),
      ]);

      final merged = <HomeFeedItem>[
        ...results[0],
        ...results[1],
        ...results[2],
      ]..sort((a, b) => b.date.compareTo(a.date));

      await _saveCache(merged);

      if (!mounted) return;
      setState(() {
        _items = merged;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to refresh feed: $error';
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<List<HomeFeedItem>> _fetchBlogPosts() async {
    final response = await http.get(Uri.parse(_blogEndpoint));

    if (response.statusCode != 200) {
      throw Exception('WordPress returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;

    return data.map((entry) {
      final map = Map<String, dynamic>.from(entry as Map);

      final title = _stripHtml(
        (map['title'] as Map?)?['rendered']?.toString() ?? 'Untitled post',
      );

      final excerpt = _stripHtml(
        (map['excerpt'] as Map?)?['rendered']?.toString() ?? '',
      );

      final content = _stripHtml(
        (map['content'] as Map?)?['rendered']?.toString() ?? excerpt,
      );

      final slug = map['slug']?.toString() ?? '';
      final link = map['link']?.toString();
      final date = DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now();

      String? imageUrl;
      final embedded = map['_embedded'];
      if (embedded is Map &&
          embedded['wp:featuredmedia'] is List &&
          (embedded['wp:featuredmedia'] as List).isNotEmpty) {
        final media = (embedded['wp:featuredmedia'] as List).first;
        if (media is Map) {
          imageUrl = media['source_url']?.toString();
        }
      }

      return HomeFeedItem(
        id: 'blog_${map['id']}',
        type: HomeFeedItemType.blog,
        title: title,
        subtitle: 'Airsoft Online Japan blog',
        body: content.isNotEmpty ? content : excerpt,
        imageUrl: imageUrl,
        date: date,
        sourceLabel: 'Blog',
        externalUrl: link ?? 'https://airsoftonlinejapan.com/blog/$slug',
        raw: map,
      );
    }).toList();
  }

  Future<List<HomeFeedItem>> _fetchEvents() async {
    try {
      final dynamic response = await _supabase
          .from('events')
          .select()
          .order('event_date', ascending: false);

      final rows = (response as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      return rows.map((row) {
        final id = row['id']?.toString() ?? UniqueKey().toString();
        final title = _firstNonEmptyString([
              row['title'],
              row['name'],
              row['event_name'],
            ]) ??
            'Upcoming event';

        final description = _firstNonEmptyString([
              row['description'],
              row['details'],
              row['body'],
              row['summary'],
            ]) ??
            'Event details will appear here.';

        final location = _firstNonEmptyString([
              row['location_name'],
              row['location'],
              row['venue'],
              row['prefecture'],
            ]);

        final imageUrl = _firstNonEmptyString([
          row['image_url'],
          row['banner_url'],
          row['cover_url'],
          row['thumbnail_url'],
        ]);

        final url = _firstNonEmptyString([
          row['external_url'],
          row['event_url'],
          row['link'],
        ]);

        final date = _parseBestDate([
              row['event_date'],
              row['start_date'],
              row['starts_at'],
              row['date'],
              row['created_at'],
            ]) ??
            DateTime.now();

        return HomeFeedItem(
          id: 'event_$id',
          type: HomeFeedItemType.event,
          title: title,
          subtitle: location ?? 'AOJ event',
          body: description,
          imageUrl: imageUrl,
          date: date,
          sourceLabel: 'Event',
          externalUrl: url,
          raw: row,
        );
      }).toList();
    } catch (_) {
      return <HomeFeedItem>[];
    }
  }

  Future<List<HomeFeedItem>> _buildAppNews() async {
    final now = DateTime.now();

    return <HomeFeedItem>[
      HomeFeedItem(
        id: 'news_home_feed',
        type: HomeFeedItemType.news,
        title: 'Feed system online',
        subtitle: 'Home command layer upgraded',
        body:
            'Your home screen now combines blog content, events, and app news into one feed with offline cache and pull-to-refresh.',
        date: now.subtract(const Duration(hours: 1)),
        sourceLabel: 'System',
        raw: const <String, dynamic>{},
      ),
      HomeFeedItem(
        id: 'news_field_finder',
        type: HomeFeedItemType.news,
        title: 'Field Finder remains mission priority',
        subtitle: 'Next objective',
        body:
            'Complete the field list flow, then move into map integration, avatars, and notification rollout.',
        date: now.subtract(const Duration(days: 1)),
        sourceLabel: 'System',
        raw: const <String, dynamic>{},
      ),
    ];
  }

  String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  DateTime? _parseBestDate(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty) continue;
      final parsed = DateTime.tryParse(text);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#8217;', '\'')
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Color _typeColor(HomeFeedItemType type, BuildContext context) {
    switch (type) {
      case HomeFeedItemType.blog:
        return Colors.blue;
      case HomeFeedItemType.event:
        return Colors.green;
      case HomeFeedItemType.news:
        return Colors.orange;
    }
  }

  IconData _typeIcon(HomeFeedItemType type) {
    switch (type) {
      case HomeFeedItemType.blog:
        return Icons.article;
      case HomeFeedItemType.event:
        return Icons.event;
      case HomeFeedItemType.news:
        return Icons.campaign;
    }
  }

  String _typeLabel(HomeFeedItemType type) {
    switch (type) {
      case HomeFeedItemType.blog:
        return 'BLOG';
      case HomeFeedItemType.event:
        return 'EVENT';
      case HomeFeedItemType.news:
        return 'NEWS';
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$y/$m/$d  $hh:$mm';
  }

  void _openItem(HomeFeedItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HomeFeedDetailScreen(item: item),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.18),
            theme.colorScheme.surfaceVariant.withOpacity(0.60),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Home Feed',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AOJ posts, event intel, and system news in one place.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _QuickStatChip(
                icon: Icons.dynamic_feed,
                label: '${_items.length} items',
              ),
              _QuickStatChip(
                icon: Icons.wifi_off,
                label: _lastUpdated == null
                    ? 'No cache yet'
                    : 'Cached ${_formatDate(_lastUpdated!)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = <_QuickAction>[
      const _QuickAction(
        title: 'Fields',
        subtitle: 'Browse fields',
        icon: Icons.map,
      ),
      const _QuickAction(
        title: 'Events',
        subtitle: 'Upcoming games',
        icon: Icons.event,
      ),
      const _QuickAction(
        title: 'Community',
        subtitle: 'Player posts',
        icon: Icons.groups,
      ),
      const _QuickAction(
        title: 'Profile',
        subtitle: 'Settings & avatar',
        icon: Icons.person,
      ),
    ];

    return SizedBox(
      height: 102,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final action = actions[index];
          return Container(
            width: 160,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(action.icon),
                    const Spacer(),
                    Text(
                      action.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedCard(HomeFeedItem item) {
    final accent = _typeColor(item.type, context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.10),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openItem(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: Image.network(
                  item.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      height: 180,
                      alignment: Alignment.center,
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: const Icon(Icons.broken_image_outlined, size: 32),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _typeIcon(item.type),
                              size: 14,
                              color: accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _typeLabel(item.type),
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(item.date),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (item.subtitle.trim().isNotEmpty)
                    Text(
                      item.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  if (item.subtitle.trim().isNotEmpty) const SizedBox(height: 8),
                  Text(
                    item.body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        item.sourceLabel ?? 'Feed',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshFeed,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildHeader(context),
          _buildQuickActions(context),
          const SizedBox(height: 8),
          if (_errorMessage != null && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  _errorMessage ?? 'No feed items available yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._items.map(_buildFeedCard),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBody(),
          if (_isRefreshing)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.small(
                onPressed: null,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HomeFeedDetailScreen extends StatelessWidget {
  final HomeFeedItem item;

  const HomeFeedDetailScreen({
    super.key,
    required this.item,
  });

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$y/$m/$d  $hh:$mm';
  }

  String _typeLabel(HomeFeedItemType type) {
    switch (type) {
      case HomeFeedItemType.blog:
        return 'Blog';
      case HomeFeedItemType.event:
        return 'Event';
      case HomeFeedItemType.news:
        return 'News';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_typeLabel(item.type)),
      ),
      body: ListView(
        children: [
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            Image.network(
              item.imageUrl!,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  height: 240,
                  alignment: Alignment.center,
                  color: theme.colorScheme.surfaceVariant,
                  child: const Icon(Icons.broken_image_outlined, size: 32),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.subtitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _formatDate(item.date),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                Text(
                  item.body,
                  style: theme.textTheme.bodyLarge,
                ),
                if (item.externalUrl != null && item.externalUrl!.trim().isNotEmpty) ...[
                  const SizedBox(height: 24),
                  SelectableText(
                    item.externalUrl!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final String title;
  final String subtitle;
  final IconData icon;

  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _QuickStatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuickStatChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}