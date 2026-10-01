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

/// One From Chats folder: Saved Messages, or a person you chat with.
class _Folder {
  const _Folder({
    required this.title,
    required this.count,
    required this.latest,
    this.conversationId,
    this.username,
  });
  final String title;
  final int count;
  final DateTime latest;

  /// Null for the Saved Messages folder.
  final String? conversationId;
  final String? username;

  bool get isSaved => conversationId == null;
}

/// From Chats: a folder for Saved Messages and one per person you chat
/// with. Read-only: files stay in their chat; Drive only shows them.
class _FromChats extends ConsumerWidget {
  const _FromChats();

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

    final byChat = <String, List<ChatMessage>>{};
    for (final m in chatList) {
      (byChat[m.conversationId] ??= []).add(m);
    }
    final folders = <_Folder>[
      if (savedList.isNotEmpty)
        _Folder(
          title: 'Saved Messages',
          count: savedList.length,
          latest: savedList.first.createdAt,
        ),
      ...(byChat.entries
          .map(
            (e) => _Folder(
              title: names[e.key] == null ? 'Chat' : '@${names[e.key]}',
              count: e.value.length,
              latest: e.value.first.createdAt,
              conversationId: e.key,
              username: names[e.key],
            ),
          )
          .toList()
        ..sort((x, y) => y.latest.compareTo(x.latest))),
    ];

    if (folders.isEmpty) {
      return LayoutBuilder(
        builder: (context, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: c.maxHeight,
              child: chats.isLoading
                  ? const LoadingView()
                  : chats.hasError
                  ? ErrorView(
                      message: userMessageFor(chats.error!),
                      onRetry: () => ref.invalidate(chatFilesProvider),
                    )
                  : const EmptyState(
                      icon: Icons.folder_open_outlined,
                      message:
                          'Images and PDFs from Saved Messages and your chats '
                          'show up here, in a folder for each chat.',
                    ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.25,
      ),
      itemCount: folders.length + (chats.isLoading ? 1 : 0),
      itemBuilder: (context, i) => i < folders.length
          ? _FolderCard(folder: folders[i])
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.folder});
  final _Folder folder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = folder.isSaved
        ? scheme.primaryContainer
        : scheme.secondaryContainer;
    final fg = folder.isSaved
        ? scheme.onPrimaryContainer
        : scheme.onSecondaryContainer;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => _FolderScreen(folder: folder)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: folder.isSaved
                    ? Icon(Icons.bookmark_rounded, color: fg)
                    : Center(
                        child: Text(
                          (folder.username ?? '?').characters.first
                              .toUpperCase(),
                          style: TextStyle(
                            color: fg,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.folder_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      folder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${folder.count} file${folder.count == 1 ? '' : 's'} · '
                '${formatShortDate(folder.latest)}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The files inside one From Chats folder (read-only).
class _FolderScreen extends ConsumerWidget {
  const _FolderScreen({required this.folder});
  final _Folder folder;

  static const _grid = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 180,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 0.82,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget body;
    if (folder.isSaved) {
      final files = ref.watch(fromChatsProvider).value ?? const <SavedItem>[];
      body = files.isEmpty
          ? const EmptyState(
              icon: Icons.folder_open_outlined,
              message: 'No files here any more.',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: _grid,
              itemCount: files.length,
              itemBuilder: (context, i) => _Tile(item: files[i]),
            );
    } else {
      final files =
          (ref.watch(chatFilesProvider).value ?? const <ChatMessage>[])
              .where((m) => m.conversationId == folder.conversationId)
              .toList();
      body = files.isEmpty
          ? const EmptyState(
              icon: Icons.folder_open_outlined,
              message: 'No files here any more.',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: _grid,
              itemCount: files.length,
              itemBuilder: (context, i) =>
                  _ChatFileTile(message: files[i], from: folder.username),
            );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(folder.title),
        actions: [
          if (!folder.isSaved)
            IconButton(
              tooltip: 'Open chat',
              icon: const Icon(Icons.forum_outlined),
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push('/chat/${folder.conversationId}');
              },
            )
          else
            IconButton(
              tooltip: 'Open Saved Messages',
              icon: const Icon(Icons.bookmark_outline_rounded),
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.go('/messenger/saved');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: body),
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Read-only. Manage files from their message.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
