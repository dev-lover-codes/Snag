import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/items_repository.dart';
import '../common/common_widgets.dart';
import '../messenger/attachment_views.dart';
import '../messenger/item_actions.dart';
import '../profile/profile_avatar.dart';

class DriveScreen extends ConsumerWidget {
  const DriveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(fromChatsProvider);
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
                  RefreshIndicator(
                    onRefresh: () => ref.read(syncProvider.notifier).refresh(),
                    child: files.when(
                      loading: () => const LoadingView(),
                      error: (e, _) => ErrorView(message: userMessageFor(e)),
                      data: (list) => list.isEmpty
                          ? LayoutBuilder(
                              builder: (context, c) => ListView(
                                children: [
                                  SizedBox(
                                    height: c.maxHeight,
                                    child: const EmptyState(
                                      icon: Icons.folder_open_outlined,
                                      message:
                                          'Images and PDFs you save in Saved '
                                          'Messages show up here.',
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _Grid(files: list),
                    ),
                  ),
                  const ComingSoon(
                    icon: Icons.cloud_upload_outlined,
                    message: 'Upload and organise your own files here.',
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: scheme.surfaceContainerLow,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'From Chats is read-only. Manage files from their message.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.files});
  final List<SavedItem> files;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: files.length,
      itemBuilder: (context, i) => _Tile(item: files[i]),
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
