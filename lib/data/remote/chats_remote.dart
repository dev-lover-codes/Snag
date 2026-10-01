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
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromRow(Map<String, dynamic> row) => ChatMessage(
    id: row['id'] as String,
    conversationId: row['conversation_id'] as String,
    senderId: row['sender_id'] as String,
    body: row['body'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

/// Remote access to 1:1 chats. Membership RLS decides what is visible.
abstract class ChatsRemote {
  Future<List<ChatSummary>> myChats();

  /// Returns the conversation id; throws [PostgrestException] with the
  /// RPC's message for unknown users and self-chats.
  Future<String> startDirectChat(String username);
  Future<List<ChatMessage>> messages(String conversationId);
  Future<ChatMessage> send(String conversationId, String body);
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

  @override
  Future<List<ChatMessage>> messages(String conversationId) async {
    final rows = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at')
        .limit(500)
        .timeout(_timeout);
    return rows.map(ChatMessage.fromRow).toList();
  }

  @override
  Future<ChatMessage> send(String conversationId, String body) async {
    final row = await _client
        .from('messages')
        .insert({'conversation_id': conversationId, 'body': body})
        .select()
        .single()
        .timeout(_timeout);
    return ChatMessage.fromRow(row);
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
