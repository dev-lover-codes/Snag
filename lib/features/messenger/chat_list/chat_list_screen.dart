import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/errors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/remote/chats_remote.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/items_repository.dart';
import '../../common/common_widgets.dart';
import '../../profile/profile_avatar.dart';
import '../direct/chat_screen.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(allItemsProvider).value ?? const <SavedItem>[];
    final inbox = items.where((i) => !i.archived).toList();
    final last = inbox.isEmpty ? null : inbox.last;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snag'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => startNewChat(context, ref),
          ),
          const ProfileAvatarButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const SyncBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(chatsProvider);
                await ref.read(syncProvider.notifier).refresh();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: scheme.primary,
                      child: Icon(
                        Icons.bookmark_rounded,
                        color: scheme.onPrimary,
                        size: 28,
                      ),
                    ),
                    title: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Saved Messages',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.5,
                            ),
                          ),
                        ),
                        if (last != null)
                          Text(
                            chatListTime(last.createdAt),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            last == null
                                ? 'Your private inbox for notes, links & files'
                                : _preview(last),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.push_pin_rounded,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    onTap: () => context.go('/messenger/saved'),
                  ),
                  const Divider(indent: 88, height: 1),
                  const _DirectChats(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New item',
        onPressed: () => context.push('/item/new'),
        child: const Icon(Icons.edit_rounded),
      ),
    );
  }

  static String _preview(SavedItem i) {
    if (i.type == 'image') return '🖼 ${i.title}';
    if (i.attachmentMime == pdfMime) return '📄 ${i.title}';
    if (i.type == 'link') return '🔗 ${i.title}';
    final c = (i.content ?? i.title).replaceAll('\n', ' ');
    return c.isEmpty ? i.title : c;
  }
}

/// 1:1 conversations, below the pinned Saved Messages.
class _DirectChats extends ConsumerWidget {
  const _DirectChats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(currentUserIdProvider);
    return ref
        .watch(chatsProvider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 24),
            child: ErrorView(
              message: userMessageFor(e),
              onRetry: () => ref.invalidate(chatsProvider),
            ),
          ),
          data: (chats) => chats.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                  child: Text(
                    'Tap the new-chat button above to message someone by '
                    'their username.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              : Column(
                  children: [
                    for (final c in chats) ...[
                      _ChatTile(chat: c, mine: c.lastSenderId == me),
                      const Divider(indent: 88, height: 1),
                    ],
                  ],
                ),
        );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.mine});
  final ChatSummary chat;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = chat.lastBody == null
        ? 'No messages yet'
        : '${mine ? 'You: ' : ''}${chat.lastBody!.replaceAll('\n', ' ')}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: scheme.secondaryContainer,
        child: Text(
          chat.otherUsername.characters.first.toUpperCase(),
          style: TextStyle(
            color: scheme.onSecondaryContainer,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '@${chat.otherUsername}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16.5,
              ),
            ),
          ),
          Text(
            chatListTime(chat.lastAt),
            style: TextStyle(
              fontSize: 12.5,
              color: chat.unread > 0 ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (chat.unread > 0)
            Badge(
              label: Text(chat.unread > 99 ? '99+' : '${chat.unread}'),
              backgroundColor: scheme.primary,
              textColor: scheme.onPrimary,
            ),
        ],
      ),
      onTap: () => context.push('/chat/${chat.conversationId}'),
    );
  }
}
