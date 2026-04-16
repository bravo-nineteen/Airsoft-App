import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum FeedType { blog, event, news }

class FeedItem {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime date;
  final FeedType type;

  FeedItem({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.date,
    required this.type,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FeedItem> _feed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _loading = true);

    try {
      final blogItems = await _fetchBlogPosts();

      // Placeholder: later replace with Supabase events
      final eventItems = _mockEvents();

      final combined = [
        ...blogItems,
        ...eventItems,
      ];

      combined.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _feed = combined;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Feed error: $e');
      setState(() => _loading = false);
    }
  }

  // ---------------------------
  // BLOG FETCH (WordPress API)
  // ---------------------------
  Future<List<FeedItem>> _fetchBlogPosts() async {
    final url = Uri.parse(
      'https://airsoftonlinejapan.com/wp-json/wp/v2/posts?_embed',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to load blog');
    }

    final List data = jsonDecode(response.body);

    return data.map((post) {
      final image =
          post['_embedded']?['wp:featuredmedia']?[0]?['source_url'] ?? '';

      return FeedItem(
        id: post['id'].toString(),
        title: _stripHtml(post['title']['rendered']),
        description: _stripHtml(post['excerpt']['rendered']),
        imageUrl: image,
        date: DateTime.parse(post['date']),
        type: FeedType.blog,
      );
    }).toList();
  }

  // ---------------------------
  // MOCK EVENTS (replace later)
  // ---------------------------
  List<FeedItem> _mockEvents() {
    return [
      FeedItem(
        id: 'event1',
        title: 'AOJ Monthly Game - BEAM',
        description: 'Full day event with lunch included.',
        imageUrl: '',
        date: DateTime.now().add(const Duration(days: 3)),
        type: FeedType.event,
      ),
    ];
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadFeed,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _feed.length,
                itemBuilder: (context, index) {
                  final item = _feed[index];
                  return _buildFeedCard(item);
                },
              ),
      ),
    );
  }

  Widget _buildFeedCard(FeedItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // TODO: navigate to detail screen
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.network(
                  item.imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeTag(item.type),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(item.date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTag(FeedType type) {
    String label;
    Color color;

    switch (type) {
      case FeedType.blog:
        label = 'BLOG';
        color = Colors.blue;
        break;
      case FeedType.event:
        label = 'EVENT';
        color = Colors.green;
        break;
      case FeedType.news:
        label = 'NEWS';
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}