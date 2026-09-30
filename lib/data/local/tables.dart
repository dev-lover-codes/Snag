import 'dart:convert';

import 'package:drift/drift.dart';

/// Stores `List<String>` tags as a JSON array in a TEXT column.
class TagsConverter extends TypeConverter<List<String>, String> {
  const TagsConverter();

  @override
  List<String> fromSql(String fromDb) {
    try {
      final decoded = jsonDecode(fromDb);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {}
    return const [];
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// Per-user cache of the `items` table (Supabase is the source of truth).
@DataClassName('SavedItem')
class Items extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();

  /// `note`, `link` or `image`.
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get content => text().nullable()();
  TextColumn get url => text().nullable()();

  /// Copy of the attachment on this device (`<docs>/attachments/<id>.<ext>`).
  TextColumn get localAttachmentPath => text().nullable()();

  /// Storage path in the `chat-files` bucket: `<user_id>/<item_id>/<file>`.
  TextColumn get remotePath => text().nullable()();
  TextColumn get attachmentMime => text().nullable()();
  TextColumn get tags =>
      text().map(const TagsConverter()).withDefault(const Constant('[]'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Unsaved editor state. Key: `new`, `share`, or an item id.
class Drafts extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
