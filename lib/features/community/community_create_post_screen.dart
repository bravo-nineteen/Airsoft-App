import 'package:flutter/material.dart';

import 'community_repository.dart';

class CommunityCreatePostScreen extends StatefulWidget {
  const CommunityCreatePostScreen({super.key});

  @override
  State<CommunityCreatePostScreen> createState() =>
      _CommunityCreatePostScreenState();
}

class _CommunityCreatePostScreenState extends State<CommunityCreatePostScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final CommunityRepository _repository = CommunityRepository();

  String _languageCode = 'en';
  String _category = 'meetups';
  bool _isSaving = false;

  static const List<String> _categories = [
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

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.')),
      );
      return;
    }

    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Body is required.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _repository.createPost(
        title: title,
        body: body,
        languageCode: _languageCode,
        category: _category,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create post: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  String _labelForCategory(String value) {
    switch (value) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Section'),
            items: _categories
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(_labelForCategory(value)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _category = value ?? 'meetups';
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyController,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(labelText: 'Body'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Text('Publish'),
          ),
        ],
      ),
    );
  }
}