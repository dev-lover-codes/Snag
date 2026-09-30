import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Access to the private `chat-files` bucket.
/// Paths are always `<user_id>/<item_id>/<file_name>`; storage policies
/// reject anything outside the caller's own folder.
abstract class StorageRemote {
  Future<void> upload(String path, File file, String mime);
  Future<void> remove(String path);

  /// Signed URL valid for 1 hour, cached in memory for the session.
  Future<String> signedUrl(String path);
  void clearCache();
}

class SupabaseStorageRemote implements StorageRemote {
  SupabaseStorageRemote(this._client);
  final SupabaseClient _client;

  static const bucket = 'chat-files';
  static const _validity = Duration(hours: 1);
  static const _timeout = Duration(seconds: 60);

  final _cache = <String, (String, DateTime)>{};

  StorageFileApi get _bucket => _client.storage.from(bucket);

  @override
  Future<void> upload(String path, File file, String mime) async {
    await _bucket
        .upload(
          path,
          file,
          fileOptions: FileOptions(contentType: mime, upsert: true),
        )
        .timeout(_timeout);
  }

  @override
  Future<void> remove(String path) async {
    _cache.remove(path);
    await _bucket.remove([path]).timeout(const Duration(seconds: 20));
  }

  @override
  Future<String> signedUrl(String path) async {
    final cached = _cache[path];
    // Refresh a few minutes before expiry.
    if (cached != null &&
        cached.$2.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return cached.$1;
    }
    final url = await _bucket
        .createSignedUrl(path, _validity.inSeconds)
        .timeout(const Duration(seconds: 20));
    _cache[path] = (url, DateTime.now().add(_validity));
    return url;
  }

  @override
  void clearCache() => _cache.clear();
}
