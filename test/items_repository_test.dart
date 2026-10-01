import 'dart:typed_data';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snag/core/errors.dart';
import 'package:snag/data/local/app_database.dart';
import 'package:snag/data/remote/items_remote.dart';
import 'package:snag/data/remote/storage_remote.dart';
import 'package:snag/data/repositories/items_repository.dart';

const me = '11111111-1111-1111-1111-111111111111';
const other = '22222222-2222-2222-2222-222222222222';

/// In-memory stand-in for Supabase that enforces "owner only" like RLS.
class FakeRemote implements ItemsRemote {
  final rows = <String, SavedItem>{};
  String caller = me;
  bool failNext = false;

  SavedItem? _visible(String id) {
    final r = rows[id];
    return r != null && r.ownerId == caller ? r : null;
  }

  void _maybeFail() {
    if (failNext) {
      failNext = false;
      throw const SocketException('down');
    }
  }

  @override
  Future<List<SavedItem>> fetchAll() async {
    _maybeFail();
    return rows.values.where((r) => r.ownerId == caller).toList();
  }

  @override
  Future<SavedItem?> fetchOne(String id) async => _visible(id);

  @override
  Future<SavedItem> insert(String id, ItemWrite d) async {
    _maybeFail();
    final now = DateTime.now().toUtc();
    final row = SavedItem(
      id: id,
      ownerId: caller,
      type: d.type,
      title: d.title,
      content: d.content,
      url: d.url,
      remotePath: d.attachmentPath,
      attachmentMime: d.attachmentMime,
      tags: d.tags,
      archived: d.archived,
      version: 1,
      createdAt: now,
      updatedAt: now,
    );
    rows[id] = row;
    return row;
  }

  @override
  Future<SavedItem?> updateIfVersion(
    String id,
    int expectedVersion,
    Map<String, dynamic> c,
  ) async {
    _maybeFail();
    final r = _visible(id);
    if (r == null || r.version != expectedVersion) return null;
    final next = r.copyWith(
      title: c['title'] as String? ?? r.title,
      archived: c['archived'] as bool? ?? r.archived,
      tags: (c['tags'] as List<String>?) ?? r.tags,
      version: r.version + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    rows[id] = next;
    return next;
  }

  @override
  Future<bool> delete(String id) async {
    _maybeFail();
    if (_visible(id) == null) return false;
    rows.remove(id);
    return true;
  }

  /// Simulates an edit made on another device.
  void editElsewhere(String id, String title) {
    final r = rows[id]!;
    rows[id] = r.copyWith(title: title, version: r.version + 1);
  }
}

class FakeStorage implements StorageRemote {
  final files = <String>{};
  @override
  Future<void> uploadBytes(String path, Uint8List bytes, String mime) async =>
      upload(path, File(path), mime);
  @override
  Future<void> upload(String path, File file, String mime) async =>
      files.add(path);
  @override
  Future<void> remove(String path) async => files.remove(path);
  @override
  Future<String> signedUrl(String path) async => 'https://signed/$path';
  @override
  void clearCache() {}
}

void main() {
  late AppDatabase db;
  late FakeRemote remote;
  late FakeStorage storage;
  late ItemsRepository repo;
  late Directory docs;
  var online = true;
  String? uid = me;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    remote = FakeRemote();
    storage = FakeStorage();
    online = true;
    uid = me;
    docs = await Directory.systemTemp.createTemp('snag_test');
    repo = ItemsRepository(
      db: db,
      remote: remote,
      storage: storage,
      currentUserId: () => uid,
      isOnline: () => online,
      documentsDir: () async => docs,
    );
  });

  tearDown(() async {
    await db.close();
    await docs.delete(recursive: true);
  });

  const idA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const idB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

  test('create caches the item with an auto title', () async {
    final item = await repo.create(
      const ItemInput(type: 'link', url: 'www.github.com/x'),
      id: idA,
    );
    expect(item.title, 'github.com');
    expect(item.url, 'https://www.github.com/x');
    expect(await db.getItem(me, idA), isNotNull);
  });

  test('validation rejects bad input without crashing', () {
    expect(
      () => repo.validate(const ItemInput(type: 'note', content: '   ')),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => repo.validate(const ItemInput(type: 'link', url: 'not a url')),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => repo.validate(ItemInput(type: 'note', content: 'x' * 20001)),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => repo.validate(const ItemInput(type: 'image')),
      throwsA(isA<ValidationException>()),
    );
    // Exactly 20,000 characters and emoji-only are fine.
    expect(
      repo.validate(ItemInput(type: 'note', content: 'x' * 20000)).type,
      'note',
    );
    expect(
      repo.validate(const ItemInput(type: 'note', content: '🔥🔥')).title,
      '🔥🔥',
    );
  });

  test('offline writes throw OfflineException', () async {
    online = false;
    expect(
      () => repo.create(
        const ItemInput(type: 'note', content: 'hi'),
        id: idA,
      ),
      throwsA(isA<OfflineException>()),
    );
  });

  test('update with a stale version reports a conflict', () async {
    final item = await repo.create(
      const ItemInput(type: 'note', content: 'v1'),
      id: idA,
    );
    remote.editElsewhere(idA, 'changed elsewhere');

    final outcome = await repo.update(
      item,
      const ItemInput(type: 'note', title: 'mine', content: 'v1'),
    );
    expect(outcome, isA<Conflict>());
    final server = (outcome as Conflict).server;
    expect(server.title, 'changed elsewhere');

    // "Overwrite" repeats the update against the server's version.
    final again = await repo.update(
      item,
      const ItemInput(type: 'note', title: 'mine', content: 'v1'),
      baseVersion: server.version,
    );
    expect(again, isA<Updated>());
    expect((again as Updated).item.title, 'mine');
    expect(again.item.version, server.version + 1);
    expect((await db.getItem(me, idA))!.title, 'mine');
  });

  test('keep theirs stores the server version locally', () async {
    final item = await repo.create(
      const ItemInput(type: 'note', content: 'v1'),
      id: idA,
    );
    remote.editElsewhere(idA, 'theirs');
    final outcome = await repo.setArchived(item, true) as Conflict;
    await repo.acceptServerVersion(outcome.server);
    final local = await db.getItem(me, idA);
    expect(local!.title, 'theirs');
    expect(local.archived, isFalse);
  });

  test('update on a deleted item returns Gone and clears the cache', () async {
    final item = await repo.create(
      const ItemInput(type: 'note', content: 'x'),
      id: idA,
    );
    remote.rows.remove(idA);
    expect(await repo.setArchived(item, true), isA<Gone>());
    expect(await db.getItem(me, idA), isNull);
  });

  test("another user's item looks exactly like a missing one", () async {
    remote.caller = other;
    await repo.create(
      const ItemInput(type: 'note', content: 'secret'),
      id: idB,
    );
    // Clear the cache the other user's create left behind.
    await db.wipe();
    remote.caller = me;

    await expectLater(repo.load(idB), throwsA(isA<ItemGoneException>()));
    await expectLater(
      repo.load('cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
      throwsA(isA<ItemGoneException>()),
    );
    await expectLater(
      repo.load('not-a-uuid'),
      throwsA(isA<ItemGoneException>()),
    );
  });

  test('archive / restore round trip', () async {
    final item = await repo.create(
      const ItemInput(type: 'note', content: 'x'),
      id: idA,
    );
    final archived = await repo.setArchived(item, true) as Updated;
    expect(archived.item.archived, isTrue);
    final restored = await repo.setArchived(archived.item, false) as Updated;
    expect(restored.item.archived, isFalse);
  });

  test(
    'refresh replaces the cache and removes rows deleted remotely',
    () async {
      await repo.create(
        const ItemInput(type: 'note', content: 'a'),
        id: idA,
      );
      await repo.create(
        const ItemInput(type: 'note', content: 'b'),
        id: idB,
      );
      remote.rows.remove(idA);
      await repo.refresh();
      final all = await db.allItems(me);
      expect(all.map((e) => e.id), [idB]);
    },
  );

  test('refresh failure keeps the cache', () async {
    await repo.create(
      const ItemInput(type: 'note', content: 'a'),
      id: idA,
    );
    remote.failNext = true;
    await expectLater(repo.refresh(), throwsA(isA<SocketException>()));
    expect(await db.getItem(me, idA), isNotNull);
  });

  test('failed insert removes the uploaded file', () async {
    final src = File('${docs.path}/pic.png')..writeAsBytesSync([1, 2, 3]);
    final staged = await repo.stagePickedFile(src.path);
    remote.failNext = true;
    await expectLater(
      repo.create(
        ItemInput(type: 'image', newAttachment: staged),
        id: idA,
      ),
      throwsA(isA<SocketException>()),
    );
    expect(storage.files, isEmpty);
  });

  test('delete removes row, file and cache', () async {
    final src = File('${docs.path}/doc.pdf')..writeAsBytesSync([1, 2, 3]);
    final staged = await repo.stagePickedFile(src.path);
    final item = await repo.create(
      ItemInput(type: 'note', newAttachment: staged),
      id: idA,
    );
    expect(item.remotePath, startsWith('$me/$idA/'));
    expect(storage.files, hasLength(1));
    await repo.delete(item);
    expect(storage.files, isEmpty);
    expect(remote.rows, isEmpty);
    expect(await db.getItem(me, idA), isNull);
  });

  test('drafts round-trip and logout wipes everything', () async {
    await repo.saveDraft(
      'new',
      const ItemInput(type: 'link', url: 'x.com', tags: ['a']),
    );
    final d = await repo.loadDraft('new');
    expect(d!.type, 'link');
    expect(d.tags, ['a']);
    await repo.create(
      const ItemInput(type: 'note', content: 'a'),
      id: idA,
    );
    await repo.wipeLocal();
    expect(await repo.loadDraft('new'), isNull);
    expect(await db.allItems(me), isEmpty);
  });
}
