import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/localization/app_localizations.dart';
import 'avatar_storage_service.dart';
import 'profile_repository.dart';

class AvatarPickerWidget extends StatefulWidget {
  const AvatarPickerWidget({
    super.key,
    this.initialAvatarUrl,
    required this.onAvatarUpdated,
  });

  final String? initialAvatarUrl;
  final ValueChanged<String> onAvatarUpdated;

  @override
  State<AvatarPickerWidget> createState() => _AvatarPickerWidgetState();
}

class _AvatarPickerWidgetState extends State<AvatarPickerWidget> {
  final ImagePicker _picker = ImagePicker();
  final AvatarStorageService _storageService = AvatarStorageService();
  final ProfileRepository _profileRepository = ProfileRepository();

  bool _isBusy = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.initialAvatarUrl;
  }

  Future<void> _selectAndUploadAvatar() async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (picked == null) {
        if (!mounted) return;
        setState(() {
          _isBusy = false;
        });
        return;
      }

      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 88,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: AppLocalizations.of(context).t('cropAvatar'),
            lockAspectRatio: true,
            hideBottomControls: false,
            initAspectRatio: CropAspectRatioPreset.square,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: AppLocalizations.of(context).t('cropAvatar'),
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (cropped == null) {
        if (!mounted) return;
        setState(() {
          _isBusy = false;
        });
        return;
      }

      final uploadedUrl = await _storageService.uploadAvatar(
        File(cropped.path),
      );

      await _profileRepository.updateAvatarUrl(uploadedUrl);

      if (!mounted) return;
      setState(() {
        _avatarUrl = uploadedUrl;
        _isBusy = false;
      });

      widget.onAvatarUpdated(uploadedUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('avatarUpdated'))),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            ).t('avatarUpdateFailed', args: {'error': '$error'}),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasAvatar = (_avatarUrl ?? '').trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: hasAvatar ? NetworkImage(_avatarUrl!) : null,
              child: !hasAvatar
                  ? const Icon(Icons.person, size: 42)
                  : null,
            ),
            Material(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isBusy ? null : _selectAndUploadAvatar,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _isBusy ? null : _selectAndUploadAvatar,
          child: Text(_isBusy ? l10n.t('updating') : l10n.t('changeAvatar')),
        ),
      ],
    );
  }
}