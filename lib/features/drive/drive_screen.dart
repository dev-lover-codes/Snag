import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/local/app_database.dart';
import '../../data/remote/chats_remote.dart';
import '../../data/repositories/items_repository.dart';
import '../common/common_widgets.dart';
import '../messenger/attachment_views.dart';
import '../messenger/direct/chat_screen.dart' show openChatAttachment;
import '../messenger/item_actions.dart';
import '../profile/profile_avatar.dart';
import 'my_files_tab.dart';

class DriveScreen extends ConsumerWidget {
  const DriveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Drive'),
          actions: const [ProfileAvatarButton(), SizedBox(width: 8)],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'From Chats'),
              Tab(text: 'My Files'),
            ],
          ),
        ),
        body: Column(
          children: [
            const SyncBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(chatFilesProvider);
                            await ref.read(syncProvider.notifier).refresh();
                          },
                          child: const _FromChats(),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        color: scheme.surfaceContainerLow,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'From Chats is read-only. Manage files from their '
                          'message.',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const MyFilesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});
  final SavedItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPdf = item.attachmentMime == pdfMime;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => FilePreviewScreen(item: item)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: isPdf
                  ? Container(
                      color: scheme.errorContainer.withValues(alpha: 0.5),
                      child: Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 48,
                        color: scheme.error,
                      ),
                    )
                  : AttachmentImage(item: item),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPdf ? attachmentDisplayName(item) : item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    formatShortDate(item.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only preview with "Go to message" (no rename, no delete).
class FilePreviewScreen extends ConsumerWidget {
  const FilePreviewScreen({super.key, required this.item});
  final SavedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPdf = item.attachmentMime == pdfMime;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPdf ? attachmentDisplayName(item) : item.title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: isPdf
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: PdfChip(item: item),
                    ),
                  )
                : InteractiveViewer(
                    maxScale: 5,
                    child: Center(
                      child: AttachmentImage(item: item, fit: BoxFit.contain),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (isPdf) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () => openAttachment(ref, item),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.push('/item/${item.id}');
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Go to message'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// From Chats: Saved Messages attachments, then files from 1:1 chats.
/// Read-only: files stay in their chat; Drive only shows them.
class _FromChats extends ConsumerWidget {
  const _FromChats();

  static const _grid = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 180,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 0.82,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(fromChatsProvider);
    final chats = ref.watch(chatFilesProvider);
    if (saved.isLoading && !saved.hasValue) return const LoadingView();

    final savedList = saved.value ?? const <SavedItem>[];
    final chatList = chats.value ?? const <ChatMessage>[];
    final names = {
      for (final c in ref.watch(chatsProvider).value ?? const <ChatSummary>[])
        c.conversationId: c.otherUsername,
    };

    if (savedList.isEmpty && chatList.isEmpty && !chats.isLoading) {
      return LayoutBuilder(
        builder: (context, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: c.maxHeight,
              child: chats.hasError
                  ? ErrorView(
                      message: userMessageFor(chats.error!),
                      onRetry: () => ref.invalidate(chatFilesProvider),
                    )
                  : const EmptyState(
                      icon: Icons.folder_open_outlined,
                      message:
                          'Images and PDFs from Saved Messages and your chats '
                          'show up here.',
                    ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (savedList.isNotEmpty) ...[
          _header(context, 'Saved Messages', savedList.length),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            sliver: SliverGrid.builder(
              gridDelegate: _grid,
              itemCount: savedList.length,
              itemBuilder: (context, i) => _Tile(item: savedList[i]),
            ),
          ),
        ],
        if (chatList.isNotEmpty) ...[
          _header(context, 'Conversations', chatList.length),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            sliver: SliverGrid.builder(
              gridDelegate: _grid,
              itemCount: chatList.length,
              itemBuilder: (context, i) => _ChatFileTile(
                message: chatList[i],
                from: names[chatList[i].conversationId],
              ),
            ),
          ),
        ] else if (chats.isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (chats.hasError)
          SliverToBoxAdapter(
            child: ErrorView(
              message: userMessageFor(chats.error!),
              onRetry: () => ref.invalidate(chatFilesProvider),
            ),
          ),
      ],
    );
  }

  Widget _header(BuildContext context, String title, int count) =>
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '$title · $count',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
}

class _ChatFileTile extends ConsumerWidget {
  const _ChatFileTile({required this.message, this.from});
  final ChatMessage message;
  final String? from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final a = message.attachment!;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => _ChatFilePreview(message: message, from: from),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: a.isPdf
                  ? Container(
                      color: scheme.errorContainer.withValues(alpha: 0.5),
                      child: Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 48,
                        color: scheme.error,
                      ),
                    )
                  : _DirectImage(path: a.path, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${from == null ? 'Chat' : '@$from'} · '
                    '${formatShortDate(message.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A chat image through a members-only signed link.
class _DirectImage extends ConsumerWidget {
  const _DirectImage({required this.path, required this.fit});
  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget icon(IconData i) => ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(child: Icon(i, color: scheme.onSurfaceVariant)),
    );
    return ref
        .watch(directFileUrlProvider(path))
        .when(
          data: (url) => Image.network(
            url,
            fit: fit,
            cacheWidth: fit == BoxFit.cover ? 400 : null,
            errorBuilder: (_, _, _) => icon(Icons.broken_image_outlined),
          ),
          loading: () => icon(Icons.image_outlined),
          error: (_, _) => icon(Icons.cloud_off_outlined),
        );
  }
}

/// Read-only preview of a chat file with "Go to chat".
class _ChatFilePreview extends ConsumerWidget {
  const _ChatFilePreview({required this.message, this.from});
  final ChatMessage message;
  final String? from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = message.attachment!;
    return Scaffold(
      appBar: AppBar(title: Text(a.name, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          Expanded(
            child: a.isPdf
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, size: 72),
                        const SizedBox(height: 12),
                        Text(a.name, textAlign: TextAlign.center),
                        Text('PDF · ${formatBytes(a.size)}'),
                      ],
                    ),
                  )
                : InteractiveViewer(
                    maxScale: 5,
                    child: Center(
                      child: _DirectImage(path: a.path, fit: BoxFit.contain),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (a.isPdf) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () => openChatAttachment(context, ref, a),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        final router = GoRouter.of(context);
                        Navigator.of(context).pop();
                        router.push('/chat/${message.conversationId}');
                      },
                      icon: const Icon(Icons.forum_outlined),
                      label: Text(
                        from == null ? 'Go to chat' : 'Go to chat with @$from',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
