import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Items, Drafts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'snag'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // ---- Items -------------------------------------------------------------

  /// All of [ownerId]'s items, oldest first (chat order).
  Stream<List<SavedItem>> watchItems(String ownerId) =>
      (select(items)
            ..where((t) => t.ownerId.equals(ownerId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .watch();

  Stream<SavedItem?> watchItem(String ownerId, String id) =>
      (select(items)..where((t) => t.ownerId.equals(ownerId) & t.id.equals(id)))
          .watchSingleOrNull();

  Future<SavedItem?> getItem(String ownerId, String id) =>
      (select(items)..where((t) => t.ownerId.equals(ownerId) & t.id.equals(id)))
          .getSingleOrNull();

  Future<List<SavedItem>> allItems(String ownerId) =>
      (select(items)..where((t) => t.ownerId.equals(ownerId))).get();

  Future<void> upsertItem(SavedItem item) =>
      into(items).insertOnConflictUpdate(item);

  Future<void> deleteItem(String id) =>
      (delete(items)..where((t) => t.id.equals(id))).go();

  /// Replaces [ownerId]'s cache with [remote] in one transaction, keeping
  /// local attachment paths for rows that still exist.
  Future<void> replaceAllForOwner(
    String ownerId,
    List<SavedItem> remote,
  ) => transaction(() async {
    final existing = {for (final i in await allItems(ownerId)) i.id: i};
    final remoteIds = remote.map((e) => e.id).toSet();
    for (final r in remote) {
      final local = existing[r.id];
      final keepLocal =
          local?.localAttachmentPath != null &&
          local!.remotePath == r.remotePath;
      await upsertItem(
        keepLocal
            ? r.copyWith(localAttachmentPath: Value(local.localAttachmentPath))
            : r,
      );
    }
    await (delete(
      items,
    )..where((t) => t.ownerId.equals(ownerId) & t.id.isNotIn(remoteIds))).go();
  });

  // ---- Drafts ------------------------------------------------------------

  Future<String?> getDraft(String key) async => (await (select(
    drafts,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.payload;

  Future<void> saveDraft(String key, String payload) =>
      into(drafts).insertOnConflictUpdate(
        Draft(key: key, payload: payload, updatedAt: DateTime.now()),
      );

  Future<void> deleteDraft(String key) =>
      (delete(drafts)..where((t) => t.key.equals(key))).go();

  // ---- Logout ------------------------------------------------------------

  Future<void> wipe() => transaction(() async {
    await delete(items).go();
    await delete(drafts).go();
  });
}
