import 'package:flutter/material.dart';

import 'community_create_post_screen.dart';
import 'community_model.dart';
import 'community_post_details_screen.dart';
import 'community_repository.dart';

class CommunityListScreen extends StatefulWidget {
  const CommunityListScreen({super.key});

  @override
  State<CommunityListScreen> createState() => _CommunityListScreenState();
}

class _CommunityListScreenState extends State<CommunityListScreen> {
  final CommunityRepository _repository = CommunityRepository();
  final TextEditingController _searchController = TextEditingController();

  String _languageCode = 'en';
  String _category = 'all';

  late Future<List<CommunityModel>> _future;

  static const List<String> _categories = [
    'all',
    'meetups',
    'tech-talk',
    'troubleshooting',
    'events',
    'off-topic',
    'memes',
    'buy-sell',
    'gear-showcase',
    'field-talk',
  ];

  @override
  void initState() {
    super.initState();
    _future = _loadPosts();
  }

  Future<List<CommunityModel>> _loadPosts() {
    return _repository.getPosts(
      languageCode: _languageCode,
      category: _category,
      search: _searchController.text,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadPosts();
    });
    await _future;
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CommunityCreatePostScreen()),
    );
    if (created == true) {
      await _refresh();
    }
  }

  String _categoryLabel(String value) {
    switch (value) {
      case 'all':
        return 'All';
      case 'meetups':
        return 'Meetups';
      case 'tech-talk':
        return 'Tech Talk';
      case 'troubleshooting':
        return 'Troubleshooting';
      case 'events':
        return 'Events';
      case 'off-topic':
        return 'Off-topic';
      case 'memes':
        return 'Memes';
      case 'buy-sell':
        return 'Buy / Sell';
      case 'gear-showcase':
        return 'Gear Showcase';
      case 'field-talk':
        return 'Field Talk';
      default:
        return value;
    }
  }

  String _languageLabel(String code) {
    return code == 'ja' ? '日本語' : 'English';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Post'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'en',
                      label: Text('English'),
                    ),
                    ButtonSegment<String>(
                      value: 'ja',
                      label: Text('日本語'),
                    ),
                  ],
                  selected: {_languageCode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _languageCode = selection.first;
                      _future = _loadPosts();
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search posts',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                  onSubmitted: (_) => _refresh(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final value = _categories[index];
                      final selected = _category == value;

                      return ChoiceChip(
                        label: Text(_categoryLabel(value)),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _category = value;
                            _future = _loadPosts();
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<CommunityModel>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        const SizedBox(height: 160),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Failed to load board:\n${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  final posts = snapshot.data ?? [];
                  if (posts.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 160),
                        Center(child: Text('No posts found.')),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: posts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return Card(
                        child: ListTile(
                          title: Text(post.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _TagChip(label: _categoryLabel(post.category)),
                                  _TagChip(label: _languageLabel(post.languageCode)),
                                  if ((post.callSign ?? '').isNotEmpty)
                                    _TagChip(label: post.callSign!),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                post.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CommunityPostDetailsScreen(post: post),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
    );
  }
}