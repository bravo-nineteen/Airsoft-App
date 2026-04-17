import 'package:flutter/material.dart';

import 'community_image_service.dart';
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
  String _selectedCategory = 'General';
  final List<String> _uploadedImageUrls = <String>[];

  List<String> get _categories {
    if (widget.postContext == 'profile') {
      return <String>['Timeline'];
    }

    return <String>[
      'General',
      'News',
      'Discussion',
      'Gear',
      'Field',
      'Events',
      'Team',
      'Advice',
    ];
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
        SnackBar(content: Text('Failed to upload image: $error')),
      );
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty || _isSubmitting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content are required')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final postId = widget.postContext == 'profile'
          ? await _repository.createProfileTimelinePost(
              targetUserId: widget.targetUserId ?? '',
              title: title,
              bodyText: body,
              plainText: body,
              imageUrls: _uploadedImageUrls,
            )
          : await _repository.createPost(
              title: title,
              bodyText: body,
              plainText: body,
              imageUrls: _uploadedImageUrls,
              category: _selectedCategory,
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
        SnackBar(content: Text('Failed to create post: $error')),
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
    final isProfilePost = widget.postContext == 'profile';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appBarTitle ?? (isProfilePost ? 'New Timeline Post' : 'Create Post')),
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
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Enter a title',
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!isProfilePost)
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
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
                          _selectedCategory = value;
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
                      child: const Row(
                        children: <Widget>[
                          Icon(Icons.timeline),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text('This will be posted to your profile timeline'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _bodyController,
                    minLines: 8,
                    maxLines: 14,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      hintText: 'Write your post',
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
                        label: const Text('Add Image'),
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
                      label: Text(isProfilePost ? 'Post to Timeline' : 'Publish Post'),
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
