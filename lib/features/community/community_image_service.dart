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

  Future<String?> pickCropAndUploadCommunityImage({
    String folder = 'community',
  }) async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2000,
      maxHeight: 2000,
    );

    if (pickedFile == null) {
      return null;
    }

    String uploadSourcePath = pickedFile.path;
    Uint8List bytes = await pickedFile.readAsBytes();

    final bool shouldCrop = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS;

    if (shouldCrop) {
      try {
        final CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 88,
          uiSettings: [
            IOSUiSettings(
              title: 'Crop Image',
            ),
          ],
        );

        if (croppedFile != null) {
          uploadSourcePath = croppedFile.path;
          bytes = await XFile(croppedFile.path).readAsBytes();
        }
      } catch (_) {
        // If cropper fails, continue with original image.
      }
    }

    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final String fileExt = _safeExtension(uploadSourcePath);
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${user.id}.$fileExt';
    final String safeFolder = folder.trim().isEmpty ? 'community' : folder.trim();
    final String filePath = '$safeFolder/${user.id}/$fileName';

    await _client.storage.from('community-images').uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: _contentTypeFromExtension(fileExt),
          ),
        );

    final String publicUrl =
        _client.storage.from('community-images').getPublicUrl(filePath);

    return publicUrl;
  }

  Future<void> deleteUploadedImageByPublicUrl(String? imageUrl) async {
    final String url = (imageUrl ?? '').trim();
    if (url.isEmpty) {
      return;
    }

    const String marker = '/storage/v1/object/public/community-images/';
    final int markerIndex = url.indexOf(marker);
    if (markerIndex == -1) {
      return;
    }

    String objectPath = url.substring(markerIndex + marker.length);
    final int queryIndex = objectPath.indexOf('?');
    if (queryIndex != -1) {
      objectPath = objectPath.substring(0, queryIndex);
    }
    if (objectPath.isEmpty) {
      return;
    }

    try {
      await _client.storage.from('community-images').remove(<String>[objectPath]);
    } catch (_) {
      // Ignore cleanup failures so delete flows continue.
    }
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
