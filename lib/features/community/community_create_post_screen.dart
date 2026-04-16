import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/localization/app_localizations.dart';
import 'community_image_service.dart';
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
  final CommunityImageService _imageService = CommunityImageService();
  final ImagePicker _picker = ImagePicker();

  String _languageCode = 'en';
  String _category = 'meetups';
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _imageUrl;
  File? _selectedImageFile;

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

  Future<void> _pickImage() async {
    if (_isUploadingImage) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (picked == null) {
        if (!mounted) return;
        setState(() {
          _isUploadingImage = false;
        });
        return;
      }

      final file = File(picked.path);
      final uploadedUrl = await _imageService.uploadPostImage(file);

      if (!mounted) return;
      setState(() {
        _selectedImageFile = file;
        _imageUrl = uploadedUrl;
        _isUploadingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).t('failedUploadImage', args: {'error': '$e'}),
          ),
        ),
      );
    }
  }

  void _applyWrap(String prefix, String suffix) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;

    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final selectedText = (start < end) ? text.substring(start, end) : '';
    final replacement = '$prefix${selectedText.isEmpty ? 'text' : selectedText}$suffix';

    final newText = text.replaceRange(start, end, replacement);
    final cursorOffset = selectedText.isEmpty
        ? start + prefix.length
        : start + replacement.length;

    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }

  void _applyLinePrefix(String prefix, {bool numbered = false}) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;

    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final safeStart = start.clamp(0, text.length);
    final safeEnd = end.clamp(0, text.length);

    final lineStart = text.lastIndexOf('\n', safeStart == 0 ? 0 : safeStart - 1);
    final adjustedStart = lineStart == -1 ? 0 : lineStart + 1;

    final lineEndIndex = text.indexOf('\n', safeEnd);
    final adjustedEnd = lineEndIndex == -1 ? text.length : lineEndIndex;

    final selectedBlock = text.substring(adjustedStart, adjustedEnd);
    final lines = selectedBlock.split('\n');

    final updatedLines = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        updatedLines.add(numbered ? '${i + 1}. ' : prefix);
      } else {
        updatedLines.add(numbered ? '${i + 1}. $line' : '$prefix$line');
      }
    }

    final replacement = updatedLines.join('\n');
    final newText = text.replaceRange(adjustedStart, adjustedEnd, replacement);

    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: adjustedStart + replacement.length,
      ),
    );
  }

  Widget _buildFormatButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('titleRequired'))),
      );
      return;
    }

    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('bodyRequired'))),
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
        imageUrl: _imageUrl,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).t('failedCreatePost', args: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _labelForCategory(AppLocalizations l10n, String value) {
    switch (value) {
      case 'meetups':
        return l10n.t('meetupsLabel');
      case 'tech-talk':
        return l10n.t('techTalk');
      case 'troubleshooting':
        return l10n.t('troubleshooting');
      case 'events':
        return l10n.events;
      case 'off-topic':
        return l10n.t('offTopic');
      case 'memes':
        return l10n.t('memes');
      case 'buy-sell':
        return l10n.t('buySell');
      case 'gear-showcase':
        return l10n.t('gearShowcase');
      case 'field-talk':
        return l10n.t('fieldTalk');
      default:
        return value;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final previewImage = _selectedImageFile != null
        ? Image.file(_selectedImageFile!, fit: BoxFit.cover)
        : (_imageUrl ?? '').trim().isNotEmpty
            ? Image.network(_imageUrl!, fit: BoxFit.cover)
            : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('createPost'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment<String>(
                  value: 'en',
                  label: Text(l10n.t('english')),
                ),
                const ButtonSegment<String>(
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
              value: _category,
              decoration: InputDecoration(labelText: l10n.t('section')),
              items: _categories
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(_labelForCategory(l10n, value)),
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
              decoration: InputDecoration(labelText: l10n.title),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _buildFormatButton(
                      icon: Icons.format_bold,
                      tooltip: 'Bold',
                      onPressed: () => _applyWrap('**', '**'),
                    ),
                    _buildFormatButton(
                      icon: Icons.format_italic,
                      tooltip: 'Italic',
                      onPressed: () => _applyWrap('*', '*'),
                    ),
                    _buildFormatButton(
                      icon: Icons.format_underline,
                      tooltip: 'Underline',
                      onPressed: () => _applyWrap('<u>', '</u>'),
                    ),
                    _buildFormatButton(
                      icon: Icons.format_list_bulleted,
                      tooltip: 'Bullet List',
                      onPressed: () => _applyLinePrefix('- '),
                    ),
                    _buildFormatButton(
                      icon: Icons.format_list_numbered,
                      tooltip: 'Numbered List',
                      onPressed: () => _applyLinePrefix('', numbered: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              minLines: 10,
              maxLines: 16,
              decoration: InputDecoration(
                labelText: l10n.t('body'),
                hintText:
                    '${l10n.t('bodyLinkHint')}\n\nFormatting supported: bold, italic, underline, bullet list, numbered list.',
                alignLabelWithHint: true,
              ),
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              maxLength: 5000,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isUploadingImage ? null : _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                _isUploadingImage ? l10n.t('uploading') : l10n.t('addImage'),
              ),
            ),
            if (previewImage != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 180,
                  child: previewImage,
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(l10n.t('publish')),
          ),
        ),
      ),
    );
  }
}