import 'dart:io';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarService {
  AvatarService();

  final SupabaseClient _client = Supabase.instance.client;

  Future<String> uploadAvatar(File file) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }

    final fileBytes = await file.readAsBytes();
    final fileExt = p.extension(file.path).toLowerCase();
    final contentType = lookupMimeType(file.path, headerBytes: fileBytes) ??
        _contentTypeFromExtension(fileExt);

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}${fileExt.isNotEmpty ? fileExt : '.jpg'}';
    final storagePath = '${user.id}/$fileName';

    await _client.storage.from('avatars').uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(storagePath);

    await _client.from('profiles').update({
      'avatar_url': publicUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);

    return publicUrl;
  }

  Future<void> deleteOldAvatarIfOwned(String? avatarUrl) async {
    final user = _client.auth.currentUser;
    if (user == null || avatarUrl == null || avatarUrl.isEmpty) {
      return;
    }

    final marker = '/storage/v1/object/public/avatars/';
    final index = avatarUrl.indexOf(marker);
    if (index == -1) {
      return;
    }

    final path = avatarUrl.substring(index + marker.length);

    if (!path.startsWith('${user.id}/')) {
      return;
    }

    try {
      await _client.storage.from('avatars').remove([path]);
    } catch (_) {
      // Ignore cleanup failure.
    }
  }

  String _contentTypeFromExtension(String extension) {
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
