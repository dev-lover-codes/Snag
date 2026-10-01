import 'package:supabase_flutter/supabase_flutter.dart';

/// A row of `public.drive_files` (Drive "My Files").
class DriveFile {
  const DriveFile({
    required this.id,
    required this.name,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPdf => mimeType == 'application/pdf';

  factory DriveFile.fromRow(Map<String, dynamic> row) => DriveFile(
    id: row['id'] as String,
    name: row['name'] as String,
    storagePath: row['storage_path'] as String,
    mimeType: row['mime_type'] as String,
    sizeBytes: (row['size_bytes'] as num).toInt(),
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}

/// Remote access to `drive_files`. RLS limits every call to the caller's rows.
abstract class DriveRemote {
  Future<List<DriveFile>> fetchAll();
  Future<DriveFile> insert({
    required String id,
    required String name,
    required String storagePath,
    required String mimeType,
    required int sizeBytes,
  });

  /// Null when the row is gone (or not the caller's).
  Future<DriveFile?> rename(String id, String name);
  Future<bool> delete(String id);
}

class SupabaseDriveRemote implements DriveRemote {
  SupabaseDriveRemote(this._client);
  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 20);

  SupabaseQueryBuilder get _table => _client.from('drive_files');

  @override
  Future<List<DriveFile>> fetchAll() async {
    final rows = await _table
        .select()
        .order('created_at', ascending: false)
        .timeout(_timeout);
    return rows.map(DriveFile.fromRow).toList();
  }

  @override
  Future<DriveFile> insert({
    required String id,
    required String name,
    required String storagePath,
    required String mimeType,
    required int sizeBytes,
  }) async {
    final row = await _table
        .insert({
          'id': id,
          'name': name,
          'storage_path': storagePath,
          'mime_type': mimeType,
          'size_bytes': sizeBytes,
        })
        .select()
        .single()
        .timeout(_timeout);
    return DriveFile.fromRow(row);
  }

  @override
  Future<DriveFile?> rename(String id, String name) async {
    final rows = await _table
        .update({'name': name})
        .eq('id', id)
        .select()
        .timeout(_timeout);
    return rows.isEmpty ? null : DriveFile.fromRow(rows.first);
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
