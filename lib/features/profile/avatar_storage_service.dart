import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarStorageService {
  AvatarStorageService();

  final SupabaseClient _client = Supabase.instance.client;
  static const String _bucketName = 'avatars';

  Future<String> uploadAvatar(File file) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }

    final extension = _fileExtension(file.path);
    final filePath =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage.from(_bucketName).upload(
      filePath,
      file,
      fileOptions: const FileOptions(
        upsert: true,
        cacheControl: '3600',
        contentType: 'image/jpeg',
      ),
    );

    return _client.storage.from(_bucketName).getPublicUrl(filePath);
  }

  String _fileExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }
}