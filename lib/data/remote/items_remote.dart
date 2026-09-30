import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/app_database.dart';

/// Fields the app writes to `public.items`. `owner_id`, `version` and the
/// timestamps are set by the database (defaults + trigger).
class ItemWrite {
  const ItemWrite({
    required this.type,
    required this.title,
    this.content,
    this.url,
    this.attachmentPath,
    this.attachmentMime,
    this.tags = const [],
    this.archived = false,
  });

  final String type;
  final String title;
  final String? content;
  final String? url;
  final String? attachmentPath;
  final String? attachmentMime;
  final List<String> tags;
  final bool archived;

  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'content': content,
    'url': url,
    'attachment_path': attachmentPath,
    'attachment_mime': attachmentMime,
    'tags': tags,
    'archived': archived,
  };
}

/// Remote access to the `items` table. Every call runs as the signed-in user,
/// so Row Level Security decides what is visible — the app never filters
/// by owner on the server side itself.
abstract class ItemsRemote {
  Future<List<SavedItem>> fetchAll();

  /// Null when the row does not exist *or* belongs to another user.
  Future<SavedItem?> fetchOne(String id);

  Future<SavedItem> insert(String id, ItemWrite data);

  /// Updates only if the server row still has [expectedVersion].
  /// Returns null when 0 rows matched (changed elsewhere, or gone).
  Future<SavedItem?> updateIfVersion(
    String id,
    int expectedVersion,
    Map<String, dynamic> changes,
  );

  /// Returns true if a row was deleted.
  Future<bool> delete(String id);
}

class SupabaseItemsRemote implements ItemsRemote {
  SupabaseItemsRemote(this._client);
  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 20);

  SupabaseQueryBuilder get _table => _client.from('items');

  @override
  Future<List<SavedItem>> fetchAll() async {
    final rows = await _table
        .select()
        .order('updated_at', ascending: false)
        .timeout(_timeout);
    return rows.map(itemFromRow).toList();
  }

  @override
  Future<SavedItem?> fetchOne(String id) async {
    if (!_isUuid(id)) return null;
    final row = await _table
        .select()
        .eq('id', id)
        .maybeSingle()
        .timeout(_timeout);
    return row == null ? null : itemFromRow(row);
  }

  @override
  Future<SavedItem> insert(String id, ItemWrite data) async {
    final row = await _table
        .insert({'id': id, ...data.toJson()})
        .select()
        .single()
        .timeout(_timeout);
    return itemFromRow(row);
  }

  @override
  Future<SavedItem?> updateIfVersion(
    String id,
    int expectedVersion,
    Map<String, dynamic> changes,
  ) async {
    final rows = await _table
        .update(changes)
        .eq('id', id)
        .eq('version', expectedVersion)
        .select()
        .timeout(_timeout);
    return rows.isEmpty ? null : itemFromRow(rows.first);
  }

  @override
  Future<bool> delete(String id) async {
    final rows = await _table
        .delete()
        .eq('id', id)
        .select('id')
        .timeout(_timeout);
    return rows.isNotEmpty;
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
bool _isUuid(String s) => _uuid.hasMatch(s);

SavedItem itemFromRow(Map<String, dynamic> row) => SavedItem(
  id: row['id'] as String,
  ownerId: row['owner_id'] as String,
  type: row['type'] as String,
  title: (row['title'] as String?) ?? '',
  content: row['content'] as String?,
  url: row['url'] as String?,
  remotePath: row['attachment_path'] as String?,
  attachmentMime: row['attachment_mime'] as String?,
  tags: ((row['tags'] as List?) ?? const []).whereType<String>().toList(),
  archived: (row['archived'] as bool?) ?? false,
  version: (row['version'] as num?)?.toInt() ?? 1,
  createdAt: DateTime.parse(row['created_at'] as String),
  updatedAt: DateTime.parse(row['updated_at'] as String),
);
