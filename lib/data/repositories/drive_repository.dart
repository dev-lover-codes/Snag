import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/errors.dart';
import '../remote/drive_remote.dart';
import '../remote/storage_remote.dart';
import 'items_repository.dart';

/// Drive "My Files": a private drive kept separate from Saved Messages.
/// Files live in the `drive` bucket at `<user_id>/<file_id>/<file_name>`.
class DriveRepository {
  DriveRepository({
    required this._remote,
    required this._storage,
    required String? Function() currentUserId,
    required this._isOnline,
  }) : _userId = currentUserId;

  final DriveRemote _remote;
  final StorageRemote _storage;
  final String? Function() _userId;
  final bool Function() _isOnline;

  static const maxNameLength = 200;

  String get _uid {
    final id = _userId();
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  void _requireOnline() {
    if (!_isOnline()) throw const OfflineException();
  }

  Future<List<DriveFile>> list() => _remote.fetchAll();

  Future<String> signedUrl(DriveFile f) => _storage.signedUrl(f.storagePath);

  /// Uploads the file first, then inserts the row; removes the upload again
  /// if the insert fails so nothing is orphaned.
  Future<DriveFile> upload(PickedAttachment file) async {
    _requireOnline();
    final size = file.size;
    if (size <= 0) throw const ValidationException('That file is empty');
    if (size > maxAttachmentBytes) {
      throw const ValidationException(Messages.fileTooLarge);
    }
    final id = const Uuid().v4();
    final name = cleanFileName(file.name, mime: file.mime);
    final path = '$_uid/$id/${storageSafeName(name)}';
    if (file.bytes != null) {
      await _storage.uploadBytes(path, file.bytes!, file.mime);
    } else {
      await _storage.upload(path, File(file.path), file.mime);
    }
    try {
      return await _remote.insert(
        id: id,
        name: name,
        storagePath: path,
        mimeType: file.mime,
        sizeBytes: size,
      );
    } catch (_) {
      await _bestEffortRemove(path);
      rethrow;
    }
  }

  /// Renames the display name only; the stored file stays where it is.
  /// The original extension is kept if the new name drops it.
  Future<DriveFile> rename(DriveFile f, String newName) async {
    _requireOnline();
    final name = cleanFileName(
      newName,
      mime: f.mimeType,
      keepExtensionOf: f.name,
    );
    final updated = await _remote.rename(f.id, name);
    if (updated == null) throw const ItemGoneException();
    return updated;
  }

  /// Deletes the row, then the stored file (best effort).
  Future<void> delete(DriveFile f) async {
    _requireOnline();
    await _remote.delete(f.id);
    await _bestEffortRemove(f.storagePath);
  }

  Future<void> _bestEffortRemove(String path) async {
    try {
      await _storage.remove(path);
    } catch (_) {
      // An orphaned object stays private to its owner; nothing to show.
    }
  }

  void clearCache() => _storage.clearCache();
}

/// Trims a user-facing file name, enforces 1–200 chars and keeps the
/// extension that matches the file type.
String cleanFileName(
  String raw, {
  required String mime,
  String? keepExtensionOf,
}) {
  var name = raw.trim().replaceAll(RegExp(r'[\\/\n\r\t]'), '_');
  if (name.isEmpty) throw const ValidationException('Enter a file name');
  final ext = keepExtensionOf != null
      ? p.extension(keepExtensionOf)
      : '.${extensionForMime(mime)}';
  final hasValidExt = mimeForPath(name) == mime;
  if (!hasValidExt &&
      ext.isNotEmpty &&
      !name.toLowerCase().endsWith(ext.toLowerCase())) {
    name = '$name$ext';
  }
  if (name.length > DriveRepository.maxNameLength) {
    throw const ValidationException(
      'File name must be 200 characters or fewer',
    );
  }
  return name;
}

/// The storage key part of a file name: ASCII-safe, max 80 chars.
String storageSafeName(String name) {
  final safe = name
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  return safe.length > 80 ? safe.substring(safe.length - 80) : safe;
}
