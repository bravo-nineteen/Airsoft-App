import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityImageService {
  CommunityImageService({
    ImagePicker? imagePicker,
    SupabaseClient? client,
  })  : _imagePicker = imagePicker ?? ImagePicker(),
        _client = client ?? Supabase.instance.client;

  final ImagePicker _imagePicker;
  final SupabaseClient _client;

  Future<String?> pickCropAndUploadCommunityImage() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2000,
      maxHeight: 2000,
    );

    if (pickedFile == null) {
      return null;
    }

    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          lockAspectRatio: false,
          hideBottomControls: false,
          initAspectRatio: CropAspectRatioPreset.original,
        ),
        IOSUiSettings(
          title: 'Crop Image',
        ),
      ],
    );

    if (croppedFile == null) {
      return null;
    }

    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final String fileExt = _safeExtension(croppedFile.path);
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${user.id}.$fileExt';
    final String filePath = 'community/${user.id}/$fileName';

    final List<int> bytes = await File(croppedFile.path).readAsBytes();

    await _client.storage.from('community-images').uploadBinary(
          filePath,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            upsert: false,
            contentType: _contentTypeFromExtension(fileExt),
          ),
        );

    final String publicUrl =
        _client.storage.from('community-images').getPublicUrl(filePath);

    return publicUrl;
  }

  String _safeExtension(String path) {
    final String ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (ext.isEmpty) {
      return 'jpg';
    }
    if (ext == 'jpeg') {
      return 'jpg';
    }
    if (ext == 'png' || ext == 'webp' || ext == 'jpg') {
      return ext;
    }
    return 'jpg';
  }

  String _contentTypeFromExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}
