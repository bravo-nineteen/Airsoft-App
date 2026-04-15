import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'avatar_service.dart';

class AvatarPickerWidget extends StatefulWidget {
  const AvatarPickerWidget({
    super.key,
    required this.avatarUrl,
    required this.onAvatarUpdated,
    this.radius = 44,
  });

  final String? avatarUrl;
  final ValueChanged<String> onAvatarUpdated;
  final double radius;

  @override
  State<AvatarPickerWidget> createState() => _AvatarPickerWidgetState();
}

class _AvatarPickerWidgetState extends State<AvatarPickerWidget> {
  final AvatarService _avatarService = AvatarService();
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (picked == null) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Avatar',
            lockAspectRatio: true,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: 'Crop Avatar',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (cropped == null) return;

      setState(() {
        _isUploading = true;
      });

      await _avatarService.deleteOldAvatarIfOwned(widget.avatarUrl);

      final publicUrl = await _avatarService.uploadAvatar(File(cropped.path));

      if (!mounted) return;

      widget.onAvatarUpdated(publicUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  ImageProvider? _buildImageProvider() {
    final avatarUrl = widget.avatarUrl;
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return null;
    }
    return NetworkImage(avatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _buildImageProvider();

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: widget.radius,
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? Icon(
                  Icons.person,
                  size: widget.radius,
                )
              : null,
        ),
        Material(
          color: Theme.of(context).colorScheme.primary,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: _isUploading ? null : _pickAndUploadAvatar,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 36,
              height: 36,
              child: _isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
