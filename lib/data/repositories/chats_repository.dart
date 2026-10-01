import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../remote/chats_remote.dart';

/// 1:1 text chats. Separate from Saved Messages, which stays private.
class ChatsRepository {
  ChatsRepository({
    required this._remote,
    required String? Function() currentUserId,
    required this._isOnline,
  }) : _userId = currentUserId;

  final ChatsRemote _remote;
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

  Future<ChatMessage> send(String conversationId, String raw) async {
    final body = raw.trim();
    if (body.isEmpty) throw const ValidationException('Type a message');
    if (body.length > maxLength) {
      throw const ValidationException('Messages can be up to 4,000 characters');
    }
    _requireOnline();
    return _remote.send(conversationId, body);
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
