import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/items_repository.dart';
import '../../common/common_widgets.dart';
import '../../profile/profile_avatar.dart';

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
        actions: const [ProfileAvatarButton(), SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          const SyncBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(syncProvider.notifier).refresh(),
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
                  const SizedBox(height: 32),
                  const ComingSoon(
                    icon: Icons.forum_outlined,
                    message: 'Chats with friends will appear here.',
                    compact: true,
                  ),
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
