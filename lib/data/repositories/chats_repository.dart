import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors.dart';
import '../remote/chats_remote.dart';
import '../remote/storage_remote.dart';
import 'drive_repository.dart' show storageSafeName;
import 'items_repository.dart';

/// 1:1 text chats. Separate from Saved Messages, which stays private.
class ChatsRepository {
  ChatsRepository({
    required this._remote,
    required this._storage,
    required String? Function() currentUserId,
    required this._isOnline,
  }) : _userId = currentUserId;

  final ChatsRemote _remote;

  /// The private `direct-files` bucket.
  final StorageRemote _storage;
  final String? Function() _userId;
  final bool Function() _isOnline;

  static const maxLength = 4000;
  static final usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

  String? get myId => _userId();

  void _requireOnline() {
    if (!_isOnline()) {
      throw const ValidationException(
        "You're offline — try again when connected.",
      );
    }
  }

  Future<List<ChatSummary>> chats() => _remote.myChats();

  /// Starts (or reopens) a chat. Unknown users and self-chats come back as
  /// [ValidationException] with the server's message.
  Future<String> start(String rawUsername) async {
    final username = rawUsername.trim().replaceFirst('@', '').toLowerCase();
    if (!usernamePattern.hasMatch(username)) {
      throw const ValidationException(
        'Usernames are 3–20 lowercase letters, numbers or _',
      );
    }
    _requireOnline();
    try {
      return await _remote.startDirectChat(username);
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') throw ValidationException(e.message);
      rethrow;
    }
  }

  Future<List<ChatMessage>> messages(String conversationId) =>
      _remote.messages(conversationId);

  /// Sends text, an attachment ([file], with [raw] as its caption), or both.
  /// The file is uploaded first; if the message insert then fails, the
  /// upload is removed again.
  Future<ChatMessage> send(
    String conversationId,
    String raw, {
    PickedAttachment? file,
  }) async {
    final body = raw.trim();
    if (body.isEmpty && file == null) {
      throw const ValidationException('Type a message');
    }
    if (body.length > maxLength) {
      throw const ValidationException('Messages can be up to 4,000 characters');
    }
    if (file != null) {
      if (!file.exists) {
        throw const ValidationException('The attached file is missing');
      }
      if (file.size > maxAttachmentBytes) {
        throw ValidationException(
          file.isPdf ? Messages.pdfTooLarge : Messages.fileTooLarge,
        );
      }
    }
    _requireOnline();
    if (file == null) return _remote.send(conversationId, body);

    final path =
        '$conversationId/${const Uuid().v4()}/${storageSafeName(file.name)}';
    if (file.bytes != null) {
      await _storage.uploadBytes(path, file.bytes!, file.mime);
    } else {
      await _storage.upload(path, File(file.path), file.mime);
    }
    try {
      return await _remote.send(
        conversationId,
        body,
        attachment: ChatAttachment(
          path: path,
          mime: file.mime,
          name: file.name.length > 200
              ? file.name.substring(0, 200)
              : file.name,
          size: file.size,
        ),
      );
    } catch (_) {
      await _bestEffortRemove(path);
      rethrow;
    }
  }

  /// Deletes my own message and its file. The other person sees it gone the
  /// next time they open the chat.
  Future<void> delete(ChatMessage m) async {
    _requireOnline();
    final deleted = await _remote.delete(m.id);
    if (!deleted) {
      throw const ValidationException('This message no longer exists.');
    }
    final a = m.attachment;
    if (a != null) await _bestEffortRemove(a.path);
  }

  /// Signed link (1 hour) to a chat attachment; members only.
  Future<String> signedUrl(String path) => _storage.signedUrl(path);

  Future<void> _bestEffortRemove(String path) async {
    try {
      await _storage.remove(path);
    } catch (_) {
      // Stays private to the two members; nothing to show the user.
    }
  }

  /// Moves my read marker to [lastSeen] (a server timestamp).
  Future<void> markRead(String conversationId, DateTime lastSeen) async {
    final me = _userId();
    if (me == null) return;
    try {
      await _remote.markRead(conversationId, me, lastSeen);
    } catch (_) {
      // Unread counts are cosmetic; never interrupt reading.
    }
  }

  Stream<ChatMessage> newMessages({String? conversationId}) =>
      _remote.inserts(conversationId: conversationId);
}
