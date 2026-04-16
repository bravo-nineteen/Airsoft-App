import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_repository.dart';

class CommunityCreatePostScreen extends StatefulWidget {
  const CommunityCreatePostScreen({super.key});

  @override
  State<CommunityCreatePostScreen> createState() => _CommunityCreatePostScreenState();
}

class _CommunityCreatePostScreenState extends State<CommunityCreatePostScreen> {
  final CommunityRepository _repository = CommunityRepository();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();

  late final quill.QuillController _quillController;

  final List<String> _imageUrls = <String>[];
  String _category = 'General';
  bool _isSaving = false;

  static const List<String> _categories = <String>[
    'General',
    'Question',
    'Event',
    'Review',
    'Sale',
    'Guide',
  ];

  @override
  void initState() {
    super.initState();
    _quillController = quill.QuillController.basic();
  }

  String _extractPlainText() {
    final plainText = _quillController.document.toPlainText();
    return plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _encodeDocumentJson() {
    final raw = _quillController.document.toDelta().toJson();
    return jsonEncode(<String, dynamic>{
      'ops': raw,
    });
  }

  Future<void> _savePost() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to post')),
      );
      return;
    }

    final title = _titleController.text.trim();
    final plainText = _extractPlainText();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    if (plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Body is required')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final metadata = user.userMetadata ?? <String, dynamic>{};
      final authorName = (metadata['call_sign'] ??
              metadata['callsign'] ??
              metadata['full_name'] ??
              user.email ??
              'User')
          .toString();
      final authorAvatarUrl = metadata['avatar_url']?.toString();

      await _repository.createPost(
        authorId: user.id,
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        title: title,
        plainText: plainText,
        bodyDeltaJson: _encodeDocumentJson(),
        imageUrls: _imageUrls,
        category: _category,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create post')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _addImageUrl() {
    final value = _imageUrlController.text.trim();
    if (value.isEmpty) {
      return;
    }

    if (_imageUrls.contains(value)) {
      _imageUrlController.clear();
      return;
    }

    setState(() {
      _imageUrls.add(value);
      _imageUrlController.clear();
    });
  }

  void _removeImageUrl(String url) {
    setState(() {
      _imageUrls.remove(url);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _imageUrlController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create post'),
        actions: <Widget>[
          TextButton(
            onPressed: _isSaving ? null : _savePost,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publish'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: <Widget>[
                  TextField(
                    controller: _titleController,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: 'Write a clear title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _category,
                    items: _categories
                        .map(
                          (String category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _category = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: theme.colorScheme.surfaceContainerLowest,
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        quill.QuillToolbar.simple(
                          controller: _quillController,
                          configurations: const quill.QuillSimpleToolbarConfigurations(
                            showInlineCode: false,
                            showCodeBlock: false,
                            showBackgroundColorButton: false,
                            showColorButton: false,
                            showFontFamily: false,
                            showFontSize: false,
                            showListNumbers: true,
                            showListBullets: true,
                            showQuote: true,
                            showLink: true,
                            showSearchButton: false,
                            showDirection: false,
                            showIndent: true,
                            showDividers: true,
                          ),
                        ),
                        const Divider(height: 20),
                        SizedBox(
                          height: 320,
                          child: quill.QuillEditor.basic(
                            controller: _quillController,
                            readOnly: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Image URLs',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _imageUrlController,
                          decoration: InputDecoration(
                            hintText: 'Paste image URL',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _addImageUrl,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_imageUrls.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _imageUrls.map((String url) {
                        return Chip(
                          label: SizedBox(
                            width: 180,
                            child: Text(
                              url,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onDeleted: () => _removeImageUrl(url),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
                    ),
                    child: const Text(
                      'This editor is WYSIWYG. Users tap bold, bullets, and quote buttons directly. No markdown symbols are needed.',
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
}