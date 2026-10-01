import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Access to a private bucket (`chat-files` for Saved Messages, `drive` for
/// Drive "My Files").
/// Paths are always `<user_id>/<item_id>/<file_name>`; storage policies
/// reject anything outside the caller's own folder.
abstract class StorageRemote {
  Future<void> upload(String path, File file, String mime);

  /// Website uploads (no file paths in the browser).
  Future<void> uploadBytes(String path, Uint8List bytes, String mime);
  Future<void> remove(String path);

  /// The file's bytes (the caller must be allowed to read it).
  Future<Uint8List> download(String path);

  /// Signed URL valid for 1 hour, cached in memory for the session.
  Future<String> signedUrl(String path);
  void clearCache();
}

class SupabaseStorageRemote implements StorageRemote {
  SupabaseStorageRemote(this._client, {this.bucket = 'chat-files'});
  final SupabaseClient _client;

  final String bucket;
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
  Future<void> uploadBytes(String path, Uint8List bytes, String mime) async {
    await _bucket
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: true),
        )
        .timeout(_timeout);
  }

  @override
  Future<Uint8List> download(String path) =>
      _bucket.download(path).timeout(_timeout);

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
