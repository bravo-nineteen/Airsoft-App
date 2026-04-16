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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: 'en',
                label: Text(l10n.t('english')),
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
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyController,
            minLines: 6,
            maxLines: 12,
            decoration: InputDecoration(
              labelText: l10n.t('body'),
              hintText: l10n.t('bodyLinkHint'),
            ),
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
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(l10n.t('publish')),
          ),
        ],
      ),
    );
  }
}