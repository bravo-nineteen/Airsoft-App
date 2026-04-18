import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import 'community_image_service.dart';
import 'community_post_categories.dart';
import 'community_post_details_screen.dart';
import 'community_repository.dart';

class CommunityCreatePostScreen extends StatefulWidget {
  const CommunityCreatePostScreen({
    super.key,
    this.postContext = 'community',
    this.targetUserId,
    this.appBarTitle,
  });

  final String postContext;
  final String? targetUserId;
  final String? appBarTitle;

  @override
  State<CommunityCreatePostScreen> createState() =>
      _CommunityCreatePostScreenState();
}

class _CommunityCreatePostScreenState extends State<CommunityCreatePostScreen> {
  final CommunityRepository _repository = CommunityRepository();
  final CommunityImageService _imageService = CommunityImageService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  bool _isSubmitting = false;
  String _selectedCategory = CommunityPostCategories.general;
  String _selectedLanguage = 'english';
  final List<String> _uploadedImageUrls = <String>[];
  bool _didInitLanguage = false;

  bool get _isProfilePost => widget.postContext == 'profile';

  List<String> get _categories {
    if (_isProfilePost) {
      return CommunityPostCategories.timelineCategories;
    }
    return CommunityPostCategories.communityCategories;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitLanguage) {
      return;
    }
    _didInitLanguage = true;
    _selectedLanguage =
        AppLocalizations.of(context).locale.languageCode == 'ja'
            ? 'japanese'
            : 'english';
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final imageUrl = await _imageService.pickCropAndUploadCommunityImage();
      if (imageUrl == null || imageUrl.trim().isEmpty) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _uploadedImageUrls.add(imageUrl);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).t('failedUploadImage', args: {'error': '$error'}),
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty || _isSubmitting) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).t('titleAndContentRequired'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final postId = _isProfilePost
          ? await _repository.createProfileTimelinePost(
              targetUserId: widget.targetUserId ?? '',
              title: title,
              bodyText: body,
              plainText: body,
              imageUrls: _uploadedImageUrls,
              language: _selectedLanguage,
            )
          : await _repository.createPost(
              title: title,
              bodyText: body,
              plainText: body,
              imageUrls: _uploadedImageUrls,
              language: _selectedLanguage,
              category: CommunityPostCategories.normalizeCommunityCategory(
                _selectedCategory,
              ),
              postContext: 'community',
            );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CommunityPostDetailsScreen(postId: postId),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).t('failedCreatePost', args: {'error': '$error'}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
    final theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Map<String, String> languageLabels = <String, String>{
      'english': l10n.t('english'),
      'japanese': l10n.t('japanese'),
      'bilingual': l10n.t('bilingual'),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.appBarTitle ??
              (_isProfilePost ? l10n.t('newTimelinePost') : l10n.t('createPost')),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.title,
                      hintText: l10n.t('enterTitle'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLanguage,
                    decoration: InputDecoration(
                      labelText: l10n.t('postLanguage'),
                    ),
                    items: languageLabels.entries
                        .map(
                          (MapEntry<String, String> entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedLanguage = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  if (!_isProfilePost)
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: l10n.t('category'),
                      ),
                      items: _categories.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedCategory =
                              CommunityPostCategories.normalizeCommunityCategory(
                            value,
                          );
                        });
                      },
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.timeline),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.t('profileTimelineHint'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _bodyController,
                    minLines: 8,
                    maxLines: 14,
                    decoration: InputDecoration(
                      labelText: l10n.content,
                      hintText: l10n.t('writePostHint'),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      ..._uploadedImageUrls.map((String imageUrl) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                imageUrl,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: -8,
                              right: -8,
                              child: IconButton.filled(
                                onPressed: () {
                                  setState(() {
                                    _uploadedImageUrls.remove(imageUrl);
                                  });
                                },
                                icon: const Icon(Icons.close, size: 16),
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: _pickAndUploadImage,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(l10n.t('addImage')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        _isProfilePost
                            ? l10n.t('postToTimeline')
                            : l10n.t('publishPost'),
                      ),
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
