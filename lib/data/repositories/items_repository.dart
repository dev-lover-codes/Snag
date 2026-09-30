import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;

import '../../core/errors.dart';
import '../../core/utils/share_parser.dart' show maxNoteLength;
import '../../core/utils/tag_utils.dart';
import '../../core/utils/title_utils.dart';
import '../../core/utils/url_utils.dart';
import '../local/app_database.dart';
import '../remote/items_remote.dart';
import '../remote/storage_remote.dart';

const maxAttachmentBytes = 10 * 1024 * 1024;

const imageMimes = {'image/jpeg', 'image/png', 'image/webp'};
const pdfMime = 'application/pdf';

String? mimeForPath(String path) {
  switch (p.extension(path).toLowerCase()) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.webp':
      return 'image/webp';
    case '.pdf':
      return pdfMime;
  }
  return null;
}

String extensionForMime(String mime) => switch (mime) {
  'image/jpeg' => 'jpg',
  'image/png' => 'png',
  'image/webp' => 'webp',
  _ => 'pdf',
};

/// A file the user picked, already copied into app storage.
class PickedAttachment {
  const PickedAttachment({
    required this.path,
    required this.mime,
    required this.name,
  });
  final String path;
  final String mime;
  final String name;

  bool get isPdf => mime == pdfMime;

  Map<String, dynamic> toJson() => {'path': path, 'mime': mime, 'name': name};
  static PickedAttachment? fromJson(Object? json) {
    if (json is! Map) return null;
    final path = json['path'], mime = json['mime'], name = json['name'];
    if (path is! String || mime is! String || name is! String) return null;
    if (!File(path).existsSync()) return null;
    return PickedAttachment(path: path, mime: mime, name: name);
  }
}

/// What the create/edit form hands to the repository. Also the draft payload.
class ItemInput {
  const ItemInput({
    this.type = 'note',
    this.title = '',
    this.content = '',
    this.url = '',
    this.tags = const [],
    this.newAttachment,
    this.removeAttachment = false,
  });

  final String type;
  final String title;
  final String content;
  final String url;
  final List<String> tags;

  /// A newly picked file (replaces any existing attachment).
  final PickedAttachment? newAttachment;

  /// True when the user removed the existing attachment while editing.
  final bool removeAttachment;

  bool get isBlank =>
      title.trim().isEmpty &&
      content.trim().isEmpty &&
      url.trim().isEmpty &&
      tags.isEmpty &&
      newAttachment == null;

  String toDraft() => jsonEncode({
    'type': type,
    'title': title,
    'content': content,
    'url': url,
    'tags': tags,
    'attachment': newAttachment?.toJson(),
    'removeAttachment': removeAttachment,
  });

  static ItemInput? fromDraft(String? payload) {
    if (payload == null) return null;
    try {
      final j = jsonDecode(payload) as Map<String, dynamic>;
      final type = j['type'];
      return ItemInput(
        type: type is String && ['note', 'link', 'image'].contains(type)
            ? type
            : 'note',
        title: (j['title'] as String?) ?? '',
        content: (j['content'] as String?) ?? '',
        url: (j['url'] as String?) ?? '',
        tags: ((j['tags'] as List?) ?? const []).whereType<String>().toList(),
        newAttachment: PickedAttachment.fromJson(j['attachment']),
        removeAttachment: j['removeAttachment'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

sealed class UpdateOutcome {
  const UpdateOutcome();
}

class Updated extends UpdateOutcome {
  const Updated(this.item);
  final SavedItem item;
}

/// The server has a newer version than the one the user edited.
class Conflict extends UpdateOutcome {
  const Conflict(this.server);
  final SavedItem server;
}

/// Deleted, or never visible to this user.
class Gone extends UpdateOutcome {
  const Gone();
}

/// THE ONLY door to item data. Supabase is the source of truth; drift is a
/// per-user cache that the UI renders from.
class ItemsRepository {
  ItemsRepository({
    required this._db,
    required this._remote,
    required this._storage,
    required String? Function() currentUserId,
    required this._isOnline,
    required Future<Directory> Function() documentsDir,
    DateTime Function()? clock,
  }) : _userId = currentUserId,
       _docs = documentsDir,
       _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final ItemsRemote _remote;
  final StorageRemote _storage;
  final String? Function() _userId;
  final bool Function() _isOnline;
  final Future<Directory> Function() _docs;
  final DateTime Function() _now;

  String get _uid {
    final id = _userId();
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  void _requireOnline() {
    if (!_isOnline()) throw const OfflineException();
  }

  // ---- Reads -------------------------------------------------------------

  Stream<List<SavedItem>> watchAll() {
    final uid = _userId();
    return uid == null ? Stream.value(const []) : _db.watchItems(uid);
  }

  Stream<SavedItem?> watchOne(String id) {
    final uid = _userId();
    return uid == null ? Stream.value(null) : _db.watchItem(uid, id);
  }

  /// Local copy if cached, otherwise asks the server (RLS decides).
  /// Throws [ItemGoneException] if missing or not ours.
  Future<SavedItem> load(String id) async {
    final local = await _db.getItem(_uid, id);
    if (local != null) return local;
    final remote = await _remote.fetchOne(id);
    if (remote == null || remote.ownerId != _uid) {
      throw const ItemGoneException();
    }
    await _db.upsertItem(remote);
    return remote;
  }

  /// Section 6.2: fetch everything, then replace the cache in one transaction.
  Future<void> refresh() async {
    final uid = _uid;
    final remote = await _remote.fetchAll();
    await _db.replaceAllForOwner(
      uid,
      remote.where((i) => i.ownerId == uid).toList(),
    );
  }

  Future<String> signedUrl(String remotePath) => _storage.signedUrl(remotePath);

  // ---- Validation (section 9) -------------------------------------------

  /// Returns the normalised write, or throws [ValidationException].
  /// [existing] is the item being edited (for its current attachment).
  ItemWrite validate(ItemInput input, {SavedItem? existing}) {
    final type = input.type;
    if (!['note', 'link', 'image'].contains(type)) {
      throw const ValidationException('Unknown item type');
    }

    final keepsOld =
        existing?.remotePath != null &&
        !input.removeAttachment &&
        input.newAttachment == null;
    final attachmentMime =
        input.newAttachment?.mime ??
        (keepsOld ? existing!.attachmentMime : null);

    final content = input.content.trim().isEmpty ? null : input.content;
    if (content != null && content.runes.length > maxNoteLength) {
      throw const ValidationException(
        'Text is too long (max 20,000 characters)',
      );
    }

    String? url;
    if (type == 'link') {
      if (input.url.trim().isEmpty) {
        throw const ValidationException('Enter a link');
      }
      url = normalizeUrl(input.url);
      if (url == null) {
        throw const ValidationException(
          'Enter a valid http(s) link, e.g. https://github.com',
        );
      }
    }

    if (type == 'note' && content == null && attachmentMime == null) {
      throw const ValidationException('Write something or attach a PDF');
    }
    if (type == 'image') {
      if (attachmentMime == null || !imageMimes.contains(attachmentMime)) {
        throw const ValidationException('Pick an image');
      }
    } else if (attachmentMime != null && attachmentMime != pdfMime) {
      throw const ValidationException('Only PDFs can be attached here');
    }

    final att = input.newAttachment;
    if (att != null) {
      final f = File(att.path);
      if (!f.existsSync()) {
        throw const ValidationException('The attached file is missing');
      }
      if (f.lengthSync() > maxAttachmentBytes) {
        throw ValidationException(
          att.isPdf ? Messages.pdfTooLarge : Messages.fileTooLarge,
        );
      }
    }

    final title = resolveTitle(
      input.title,
      type: type,
      content: content,
      url: url,
      attachmentName: att?.name ?? _nameFromPath(existing?.remotePath),
      now: _now(),
    );

    return ItemWrite(
      type: type,
      title: title,
      content: content,
      url: url,
      attachmentMime: attachmentMime,
      attachmentPath: keepsOld ? existing!.remotePath : null,
      tags: normalizeTags(input.tags),
      archived: existing?.archived ?? false,
    );
  }

  // ---- Writes (section 6.3) ----------------------------------------------

  /// Validate → upload the attachment → insert the row → cache it.
  /// If the insert fails after an upload, the uploaded file is deleted.
  Future<SavedItem> create(ItemInput input, {required String id}) async {
    final write = validate(input);
    _requireOnline();
    final uid = _uid;

    String? uploaded;
    final att = input.newAttachment;
    if (att != null) {
      uploaded = _storagePath(uid, id, att.name);
      await _storage.upload(uploaded, File(att.path), att.mime);
    }

    final SavedItem saved;
    try {
      saved = await _remote.insert(
        id,
        _withAttachment(write, uploaded, att?.mime ?? write.attachmentMime),
      );
    } catch (_) {
      if (uploaded != null) await _bestEffortRemove(uploaded);
      rethrow;
    }

    final local = att == null ? null : await _keepLocalCopy(id, att);
    final cached = saved.copyWith(localAttachmentPath: Value(local));
    await _db.upsertItem(cached);
    return cached;
  }

  /// Full edit. [baseVersion] overrides the version to match (used by
  /// "Overwrite" after a conflict).
  Future<UpdateOutcome> update(
    SavedItem original,
    ItemInput input, {
    int? baseVersion,
  }) async {
    final write = validate(input, existing: original);
    _requireOnline();
    final uid = _uid;

    String? uploaded;
    final att = input.newAttachment;
    if (att != null) {
      uploaded = _storagePath(uid, original.id, att.name);
      await _storage.upload(uploaded, File(att.path), att.mime);
    }

    final newPath = att != null ? uploaded : write.attachmentPath;
    final changes = _withAttachment(
      write,
      newPath,
      newPath == null ? null : (att?.mime ?? write.attachmentMime),
    ).toJson()..remove('archived');

    final UpdateOutcome outcome;
    try {
      outcome = await _conditionalUpdate(
        original,
        changes,
        baseVersion: baseVersion,
        newLocal: newPath == null || att != null
            ? null
            : original.localAttachmentPath,
      );
    } catch (_) {
      if (uploaded != null) await _bestEffortRemove(uploaded);
      rethrow;
    }

    if (outcome is! Updated) {
      if (uploaded != null) await _bestEffortRemove(uploaded);
      return outcome;
    }
    final old = original.remotePath;
    if (old != null && old != newPath) await _bestEffortRemove(old);
    if (att == null) {
      if (newPath == null) _deleteLocalFile(original.localAttachmentPath);
      return outcome;
    }
    _deleteLocalFile(original.localAttachmentPath);
    final cached = outcome.item.copyWith(
      localAttachmentPath: Value(await _keepLocalCopy(original.id, att)),
    );
    await _db.upsertItem(cached);
    return Updated(cached);
  }

  Future<UpdateOutcome> setArchived(
    SavedItem item,
    bool archived, {
    int? baseVersion,
  }) {
    _requireOnline();
    return _conditionalUpdate(item, {
      'archived': archived,
    }, baseVersion: baseVersion);
  }

  Future<UpdateOutcome> setTags(
    SavedItem item,
    List<String> tags, {
    int? baseVersion,
  }) {
    _requireOnline();
    return _conditionalUpdate(item, {
      'tags': normalizeTags(tags),
    }, baseVersion: baseVersion);
  }

  /// "Keep theirs" after a conflict.
  Future<void> acceptServerVersion(SavedItem server) async {
    final local = await _db.getItem(_uid, server.id);
    await _db.upsertItem(
      server.copyWith(
        localAttachmentPath: Value(
          local != null && local.remotePath == server.remotePath
              ? local.localAttachmentPath
              : null,
        ),
      ),
    );
  }

  /// Delete the row, then its file (best effort), then the cache.
  Future<void> delete(SavedItem item) async {
    _requireOnline();
    await _remote.delete(item.id);
    if (item.remotePath != null) await _bestEffortRemove(item.remotePath!);
    await _db.deleteItem(item.id);
    _deleteLocalFile(item.localAttachmentPath);
  }

  Future<UpdateOutcome> _conditionalUpdate(
    SavedItem item,
    Map<String, dynamic> changes, {
    int? baseVersion,
    String? newLocal,
  }) async {
    final row = await _remote.updateIfVersion(
      item.id,
      baseVersion ?? item.version,
      changes,
    );
    if (row != null) {
      final keepLocal = changes.containsKey('attachment_path')
          ? newLocal
          : item.localAttachmentPath;
      final cached = row.copyWith(localAttachmentPath: Value(keepLocal));
      await _db.upsertItem(cached);
      return Updated(cached);
    }
    final server = await _remote.fetchOne(item.id);
    if (server == null) {
      await _db.deleteItem(item.id);
      _deleteLocalFile(item.localAttachmentPath);
      return const Gone();
    }
    return Conflict(server);
  }

  // ---- Drafts ------------------------------------------------------------

  Future<ItemInput?> loadDraft(String key) async =>
      ItemInput.fromDraft(await _db.getDraft(key));

  Future<void> saveDraft(String key, ItemInput input) =>
      _db.saveDraft(key, input.toDraft());

  Future<void> deleteDraft(String key) => _db.deleteDraft(key);

  Future<String?> rawDraft(String key) => _db.getDraft(key);
  Future<void> saveRawDraft(String key, String payload) =>
      _db.saveDraft(key, payload);

  // ---- Files -------------------------------------------------------------

  /// Copies a picked file into `<docs>/pending/` so drafts survive restarts.
  Future<PickedAttachment> stagePickedFile(
    String sourcePath, {
    String? name,
  }) async {
    final src = File(sourcePath);
    if (!src.existsSync()) {
      throw const ValidationException('Could not read the selected file');
    }
    final fileName = name ?? p.basename(sourcePath);
    final mime = mimeForPath(fileName) ?? mimeForPath(sourcePath);
    if (mime == null) {
      throw const ValidationException('Only JPEG, PNG, WebP or PDF files');
    }
    final size = await src.length();
    if (size > maxAttachmentBytes) {
      throw ValidationException(
        mime == pdfMime ? Messages.pdfTooLarge : Messages.fileTooLarge,
      );
    }
    final dir = Directory(p.join((await _docs()).path, 'pending'));
    await dir.create(recursive: true);
    final dest = p.join(
      dir.path,
      '${_now().microsecondsSinceEpoch}.${extensionForMime(mime)}',
    );
    await src.copy(dest);
    return PickedAttachment(path: dest, mime: mime, name: fileName);
  }

  Future<String> _keepLocalCopy(String id, PickedAttachment att) async {
    final dir = Directory(p.join((await _docs()).path, 'attachments'));
    await dir.create(recursive: true);
    final dest = p.join(dir.path, '$id.${extensionForMime(att.mime)}');
    if (att.path != dest) await File(att.path).copy(dest);
    return dest;
  }

  void _deleteLocalFile(String? path) {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  Future<void> _bestEffortRemove(String path) async {
    try {
      await _storage.remove(path);
    } catch (_) {
      // Logged only; an orphaned file is harmless and stays private.
    }
  }

  static String _storagePath(String uid, String itemId, String name) {
    final safe = name
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final trimmed = safe.length > 80 ? safe.substring(safe.length - 80) : safe;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '$uid/$itemId/${stamp}_$trimmed';
  }

  static ItemWrite _withAttachment(ItemWrite w, String? path, String? mime) =>
      ItemWrite(
        type: w.type,
        title: w.title,
        content: w.content,
        url: w.url,
        attachmentPath: path,
        attachmentMime: path == null ? null : mime,
        tags: w.tags,
        archived: w.archived,
      );

  /// Deletes every cached row, draft and file on this device (logout).
  Future<void> wipeLocal() async {
    _storage.clearCache();
    await _db.wipe();
    final docs = await _docs();
    for (final name in ['attachments', 'pending']) {
      final dir = Directory(p.join(docs.path, name));
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
  }
}

/// File name shown for an attachment: storage path basename without the
/// timestamp prefix.
String attachmentDisplayName(SavedItem item) =>
    _nameFromPath(item.remotePath) ??
    (item.localAttachmentPath == null
        ? 'file'
        : p.basename(item.localAttachmentPath!));

String? _nameFromPath(String? remotePath) {
  if (remotePath == null) return null;
  final base = p.basename(remotePath);
  final m = RegExp(r'^\d+_(.+)$').firstMatch(base);
  return m?.group(1) ?? base;
}
