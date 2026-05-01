import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/widgets/persistent_shell_bottom_nav.dart';
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
  Timer? _draftSaveDebounce;

  bool _isSubmitting = false;
  bool _isLoadingDraft = true;
  String _selectedCategory = CommunityPostCategories.general;
  String _selectedLanguage = 'english';
  final List<String> _uploadedImageUrls = <String>[];
  final TextEditingController _pollQuestionController =
      TextEditingController();
  final List<TextEditingController> _pollOptionControllers =
      <TextEditingController>[
        TextEditingController(),
        TextEditingController(),
      ];
  bool _enablePoll = false;
  bool _pollAllowMultiple = false;
  bool _didInitLanguage = false;

  bool get _isProfilePost => widget.postContext == 'profile';

  List<String> get _categories {
    if (_isProfilePost) {
      return CommunityPostCategories.timelineCategories;
    }
    return CommunityPostCategories.communityCategories;
  }

  String get _draftKey {
    if (_isProfilePost) {
      return 'profile:${widget.targetUserId ?? ''}';
    }
    return 'community';
  }

  List<String> get _pollOptions {
    return _pollOptionControllers
        .map((TextEditingController controller) => controller.text.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
  }

  bool get _canPublishPoll {
    if (!_enablePoll) {
      return true;
    }
    return _pollQuestionController.text.trim().isNotEmpty &&
        _pollOptions.length >= 2;
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onDraftInputsChanged);
    _bodyController.addListener(_onDraftInputsChanged);
    _pollQuestionController.addListener(_onDraftInputsChanged);
    for (final TextEditingController controller in _pollOptionControllers) {
      controller.addListener(_onDraftInputsChanged);
    }
    _loadDraft();
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

  Future<void> _loadDraft() async {
    try {
      final Map<String, dynamic>? draft = await _repository.getPostDraft(
        draftKey: _draftKey,
        postContext: widget.postContext,
        targetUserId: widget.targetUserId,
      );

      if (!mounted) {
        return;
      }

      if (draft != null) {
        final String title = (draft['title'] ?? '').toString();
        final String body = (draft['body_text'] ?? '').toString();
        final dynamic mediaJson = draft['media_json'];
        final dynamic pollJson = draft['poll_json'];

        _titleController.text = title;
        _bodyController.text = body;

        if (mediaJson is List) {
          _uploadedImageUrls
            ..clear()
            ..addAll(
              mediaJson
                  .map((dynamic e) => e.toString().trim())
                  .where((String e) => e.isNotEmpty),
            );
        }

        if (pollJson is Map) {
          final String language = (pollJson['language'] ?? '').toString();
          final String category = (pollJson['category'] ?? '').toString();
          final String question = (pollJson['question'] ?? '').toString();
          final bool allowMultiple = pollJson['allow_multiple'] == true;
          final List<String> options =
              (pollJson['options'] as List<dynamic>? ?? <dynamic>[])
                  .map((dynamic value) => value.toString().trim())
                  .where((String value) => value.isNotEmpty)
                  .toList();
          if (language.isNotEmpty) {
            _selectedLanguage = language;
          }
          if (category.isNotEmpty) {
            _selectedCategory =
                CommunityPostCategories.normalizeCommunityCategory(category);
          }

          _pollQuestionController.text = question;
          for (final TextEditingController controller in _pollOptionControllers) {
            controller.removeListener(_onDraftInputsChanged);
            controller.dispose();
          }
          final List<String> normalizedOptions = options.isEmpty
              ? <String>['', '']
              : options.length == 1
                  ? <String>[options.first, '']
                  : options;

          _pollOptionControllers
            ..clear()
            ..addAll(
              normalizedOptions.map(
                (String value) => TextEditingController(text: value)
                  ..addListener(_onDraftInputsChanged),
              ),
            );

          _enablePoll = question.trim().isNotEmpty || options.isNotEmpty;
          _pollAllowMultiple = allowMultiple;
        }
      }
    } catch (_) {
      // Draft loading should never block compose.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDraft = false;
        });
      }
    }
  }

  void _onDraftInputsChanged() {
    _scheduleDraftSave();
  }

  void _scheduleDraftSave() {
    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = Timer(const Duration(milliseconds: 550), () {
      unawaited(_saveDraft());
    });
  }

  Future<void> _saveDraft() async {
    if (_isSubmitting || _isLoadingDraft) {
      return;
    }

    final String title = _titleController.text.trim();
    final String body = _bodyController.text.trim();
    final bool hasContent =
        title.isNotEmpty || body.isNotEmpty || _uploadedImageUrls.isNotEmpty;

    if (!hasContent) {
      await _repository.clearPostDraft(draftKey: _draftKey);
      return;
    }

    await _repository.savePostDraft(
      draftKey: _draftKey,
      title: title,
      bodyText: body,
      plainText: body,
      imageUrls: _uploadedImageUrls,
      language: _selectedLanguage,
      category: _selectedCategory,
      postContext: widget.postContext,
      targetUserId: widget.targetUserId,
      pollQuestion: _enablePoll ? _pollQuestionController.text.trim() : null,
      pollOptions: _enablePoll ? _pollOptions : null,
      pollAllowMultiple: _enablePoll ? _pollAllowMultiple : false,
    );
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
      _scheduleDraftSave();
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

  void _togglePoll(bool enabled) {
    setState(() {
      _enablePoll = enabled;
      if (!_enablePoll) {
        _pollAllowMultiple = false;
      }
    });
    _scheduleDraftSave();
  }

  void _addPollOption() {
    if (_pollOptionControllers.length >= 6) {
      return;
    }
    setState(() {
      final TextEditingController controller = TextEditingController();
      controller.addListener(_onDraftInputsChanged);
      _pollOptionControllers.add(controller);
    });
    _scheduleDraftSave();
  }

  void _removePollOption(int index) {
    if (_pollOptionControllers.length <= 2) {
      return;
    }
    final TextEditingController controller = _pollOptionControllers[index];
    setState(() {
      _pollOptionControllers.removeAt(index);
    });
    controller.removeListener(_onDraftInputsChanged);
    controller.dispose();
    _scheduleDraftSave();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty || _isSubmitting || !_canPublishPoll) {
      final AppLocalizations l10n = AppLocalizations.of(context);
      final String message = !_canPublishPoll
          ? 'Poll needs a question and at least two options.'
          : l10n.t('titleAndContentRequired');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final String? pollQuestion =
          _enablePoll ? _pollQuestionController.text.trim() : null;
      final List<String>? pollOptions = _enablePoll ? _pollOptions : null;
      final bool pollAllowMultiple = _enablePoll && _pollAllowMultiple;

      final postId = _isProfilePost
          ? await _repository.createProfileTimelinePost(
              targetUserId: widget.targetUserId ?? '',
              title: title,
              bodyText: body,
              plainText: body,
              imageUrls: _uploadedImageUrls,
              language: _selectedLanguage,
              pollQuestion: pollQuestion,
              pollOptions: pollOptions,
              pollAllowMultiple: pollAllowMultiple,
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
              pollQuestion: pollQuestion,
              pollOptions: pollOptions,
              pollAllowMultiple: pollAllowMultiple,
            );

      await _repository.clearPostDraft(draftKey: _draftKey);

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
    _draftSaveDebounce?.cancel();
    unawaited(_saveDraft());
    _titleController.removeListener(_onDraftInputsChanged);
    _bodyController.removeListener(_onDraftInputsChanged);
    _pollQuestionController.removeListener(_onDraftInputsChanged);
    for (final TextEditingController controller in _pollOptionControllers) {
      controller.removeListener(_onDraftInputsChanged);
      controller.dispose();
    }
    _titleController.dispose();
    _bodyController.dispose();
    _pollQuestionController.dispose();
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
      bottomNavigationBar: PersistentShellBottomNav(
        selectedIndex: _isProfilePost ? 3 : 2,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            if (_isLoadingDraft)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(minHeight: 2),
              ),
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
                      _scheduleDraftSave();
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
                        _scheduleDraftSave();
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
                  SwitchListTile.adaptive(
                    value: _enablePoll,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Add poll'),
                    subtitle: const Text('Let operators vote on this post.'),
                    onChanged: _togglePoll,
                  ),
                  if (_enablePoll) ...<Widget>[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pollQuestionController,
                      decoration: const InputDecoration(
                        labelText: 'Poll question',
                        hintText: 'What should we vote on?',
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._pollOptionControllers.asMap().entries.map(
                      (MapEntry<int, TextEditingController> entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: TextField(
                                  controller: entry.value,
                                  decoration: InputDecoration(
                                    labelText: 'Option ${entry.key + 1}',
                                  ),
                                ),
                              ),
                              if (_pollOptionControllers.length > 2)
                                IconButton(
                                  onPressed: () => _removePollOption(entry.key),
                                  icon: const Icon(Icons.remove_circle_outline),
                                  tooltip: 'Remove option',
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _pollOptionControllers.length >= 6
                            ? null
                            : _addPollOption,
                        icon: const Icon(Icons.add),
                        label: const Text('Add option'),
                      ),
                    ),
                    SwitchListTile.adaptive(
                      value: _pollAllowMultiple,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow multiple choices'),
                      onChanged: (bool value) {
                        setState(() {
                          _pollAllowMultiple = value;
                        });
                        _scheduleDraftSave();
                      },
                    ),
                    if (!_canPublishPoll)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Poll requires a question and two options.',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
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
                                  _scheduleDraftSave();
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
