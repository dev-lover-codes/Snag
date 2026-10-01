import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// One row of the `my_chats()` RPC.
class ChatSummary {
  const ChatSummary({
    required this.conversationId,
    required this.otherUsername,
    this.lastBody,
    required this.lastAt,
    this.lastSenderId,
    required this.unread,
  });

  final String conversationId;
  final String otherUsername;
  final String? lastBody;
  final DateTime lastAt;
  final String? lastSenderId;
  final int unread;

  factory ChatSummary.fromRow(Map<String, dynamic> row) => ChatSummary(
    conversationId: row['conversation_id'] as String,
    otherUsername: (row['other_username'] as String?) ?? 'unknown',
    lastBody: row['last_body'] as String?,
    lastAt: DateTime.parse(row['last_at'] as String),
    lastSenderId: row['last_sender_id'] as String?,
    unread: (row['unread'] as num?)?.toInt() ?? 0,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.attachment,
  });

  final String id;
  final String conversationId;
  final String senderId;

  /// May be empty when the message is only an attachment.
  final String body;
  final DateTime createdAt;
  final ChatAttachment? attachment;

  factory ChatMessage.fromRow(Map<String, dynamic> row) => ChatMessage(
    id: row['id'] as String,
    conversationId: row['conversation_id'] as String,
    senderId: row['sender_id'] as String,
    body: (row['body'] as String?) ?? '',
    createdAt: DateTime.parse(row['created_at'] as String),
    attachment: row['attachment_path'] == null
        ? null
        : ChatAttachment(
            path: row['attachment_path'] as String,
            mime: row['attachment_mime'] as String,
            name: (row['attachment_name'] as String?) ?? 'file',
            size: (row['attachment_size'] as num?)?.toInt() ?? 0,
          ),
  );
}

/// An image or PDF in the private `direct-files` bucket at
/// `<conversation_id>/<uuid>/<file_name>`. Only the two members can read it.
class ChatAttachment {
  const ChatAttachment({
    required this.path,
    required this.mime,
    required this.name,
    required this.size,
  });

  final String path;
  final String mime;
  final String name;
  final int size;

  bool get isPdf => mime == 'application/pdf';

  Map<String, dynamic> toJson() => {
    'attachment_path': path,
    'attachment_mime': mime,
    'attachment_name': name,
    'attachment_size': size,
  };
}

/// Remote access to 1:1 chats. Membership RLS decides what is visible.
abstract class ChatsRemote {
  Future<List<ChatSummary>> myChats();

  /// Returns the conversation id; throws [PostgrestException] with the
  /// RPC's message for unknown users and self-chats.
  Future<String> startDirectChat(String username);
  Future<List<ChatMessage>> messages(String conversationId);

  /// Every image/PDF sent in my conversations, newest first (Drive).
  Future<List<ChatMessage>> attachments();
  Future<ChatMessage> send(
    String conversationId,
    String body, {
    ChatAttachment? attachment,
  });

  /// Deletes my own message. Returns false if nothing was deleted.
  Future<bool> delete(String messageId);
  Future<void> markRead(String conversationId, String userId, DateTime at);

  /// New messages visible to the caller (all chats when [conversationId]
  /// is null).
  Stream<ChatMessage> inserts({String? conversationId});
}

class SupabaseChatsRemote implements ChatsRemote {
  SupabaseChatsRemote(this._client);
  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 20);

  @override
  Future<List<ChatSummary>> myChats() async {
    final rows = await _client.rpc('my_chats').timeout(_timeout) as List;
    return rows.cast<Map<String, dynamic>>().map(ChatSummary.fromRow).toList();
  }

  @override
  Future<String> startDirectChat(String username) async {
    final id = await _client
        .rpc('start_direct_chat', params: {'p_username': username})
        .timeout(_timeout);
    return id as String;
  }

  /// The latest 500 messages, oldest first (chat order).
  @override
  Future<List<ChatMessage>> messages(String conversationId) async {
    // postgrest's order() is descending by default: take the newest 500,
    // then flip them so the chat reads top-to-bottom in time order.
    final rows = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(500)
        .timeout(_timeout);
    return rows.map(ChatMessage.fromRow).toList().reversed.toList();
  }

  @override
  Future<ChatMessage> send(
    String conversationId,
    String body, {
    ChatAttachment? attachment,
  }) async {
    final row = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'body': body,
          ...?attachment?.toJson(),
        })
        .select()
        .single()
        .timeout(_timeout);
    return ChatMessage.fromRow(row);
  }

  @override
  Future<List<ChatMessage>> attachments() async {
    final rows = await _client
        .from('messages')
        .select()
        .not('attachment_path', 'is', null)
        .order('created_at', ascending: false)
        .limit(300)
        .timeout(_timeout);
    return rows.map(ChatMessage.fromRow).toList();
  }

  @override
  Future<bool> delete(String messageId) async {
    final rows = await _client
        .from('messages')
        .delete()
        .eq('id', messageId)
        .select('id')
        .timeout(_timeout);
    return rows.isNotEmpty;
  }

  @override
  Future<void> markRead(String conversationId, String userId, DateTime at) =>
      _client
          .from('conversation_members')
          .update({'last_read_at': at.toUtc().toIso8601String()})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .timeout(_timeout);

  @override
  Stream<ChatMessage> inserts({String? conversationId}) {
    late final RealtimeChannel channel;
    final controller = StreamController<ChatMessage>(
      onCancel: () => _client.removeChannel(channel),
    );
    channel = _client
        .channel(
          'messages:${conversationId ?? 'all'}:${DateTime.now().microsecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: conversationId == null
              ? null
              : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'conversation_id',
                  value: conversationId,
                ),
          callback: (payload) {
            try {
              controller.add(ChatMessage.fromRow(payload.newRecord));
            } catch (_) {}
          },
        )
        .subscribe();
    return controller.stream;
  }
}
