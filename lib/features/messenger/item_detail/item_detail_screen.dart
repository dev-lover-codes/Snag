import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/errors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/url_utils.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/items_repository.dart';
import '../../common/common_widgets.dart';
import '../attachment_views.dart';
import '../item_actions.dart';
import '../saved/message_bubble.dart' show looksLikeCode;

/// Loads an item for a deep link: cache first, then the server (RLS).
final itemLookupProvider = FutureProvider.autoDispose.family<SavedItem, String>(
  (ref, id) => ref.watch(itemsRepositoryProvider).load(id),
);

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});
  final String itemId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/messenger/saved');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookup = ref.watch(itemLookupProvider(itemId));
    final live = ref.watch(itemProvider(itemId)).value;

    return lookup.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: e is ItemGoneException
            ? ItemGoneView(onBack: () => context.go('/messenger/saved'))
            : ErrorView(
                message: userMessageFor(e),
                onRetry: () => ref.invalidate(itemLookupProvider(itemId)),
              ),
      ),
      data: (_) {
        // After the lookup, follow the cache so edits/deletes show live.
        if (live == null) {
          return Scaffold(
            appBar: AppBar(),
            body: ItemGoneView(onBack: () => context.go('/messenger/saved')),
          );
        }
        return _Detail(item: live, onBack: () => _back(context));
      },
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.item, required this.onBack});
  final SavedItem item;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isPdf = item.attachmentMime == pdfMime && item.remotePath != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (item.type) {
          'link' => 'Link',
          'image' => 'Image',
          _ => 'Note',
        }),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/item/${item.id}/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'tags':
                  await editTags(context, ref, item);
                case 'copy':
                  await copyItem(item);
                case 'delete':
                  if (await deleteWithConfirm(context, ref, item)) onBack();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'tags', child: Text('Edit tags')),
              PopupMenuItem(value: 'copy', child: Text('Copy')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (item.type == 'image') ...[
            GestureDetector(
              onTap: () => openFullScreenImage(context, item),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: AttachmentImage(item: item, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          SelectableText(
            item.title,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (item.type == 'link' && item.url != null) ...[
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.public, color: scheme.onPrimaryContainer),
                ),
                title: Text(domainOf(item.url!)),
                subtitle: Text(
                  item.url!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => openLink(item.url!),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (item.content?.isNotEmpty ?? false) ...[
            SelectableText(
              item.content!,
              style: TextStyle(
                fontSize: 16,
                height: 1.45,
                fontFamily: looksLikeCode(item.content!) ? 'monospace' : null,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (isPdf) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: PdfChip(item: item),
            ),
            const SizedBox(height: 12),
          ],
          if (item.tags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in item.tags)
                  ActionChip(
                    label: Text('#$t'),
                    onPressed: () {
                      final f = ref.read(savedFilterProvider.notifier);
                      f.setArchived(item.archived);
                      f.setTag(t);
                      context.go('/messenger/saved');
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          const Divider(height: 24),
          _meta(
            context,
            Icons.schedule,
            'Created',
            formatDateTime(item.createdAt),
          ),
          _meta(
            context,
            Icons.update,
            'Updated',
            formatDateTime(item.updatedAt),
          ),
          if (item.archived)
            _meta(context, Icons.archive_outlined, 'Status', 'Archived'),
          _ReminderRow(itemId: item.id),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.type == 'link' && item.url != null)
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => openLink(item.url!),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open link'),
                ),
              if (isPdf)
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => openAttachment(ref, item),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Open PDF'),
                ),
              OutlinedButton.icon(
                onPressed: () => context.push('/item/${item.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: () => remindMe(context, ref, item),
                icon: const Icon(Icons.alarm_add_outlined),
                label: const Text('Remind me'),
              ),
              OutlinedButton.icon(
                onPressed: () => toggleArchive(context, ref, item),
                icon: Icon(
                  item.archived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                label: Text(item.archived ? 'Restore' : 'Archive'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                onPressed: () async {
                  if (await deleteWithConfirm(context, ref, item)) onBack();
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String label, String v) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text('$label  ', style: TextStyle(color: scheme.onSurfaceVariant)),
          Text(v),
        ],
      ),
    );
  }
}

/// The active "Remind me" for this item (device-only), with Cancel.
class _ReminderRow extends ConsumerWidget {
  const _ReminderRow({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = ref.watch(itemReminderProvider(itemId)).value;
    if (at == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.alarm_on_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Text('Reminder  ', style: TextStyle(color: scheme.onSurfaceVariant)),
          Expanded(child: Text(formatDateTime(at))),
          TextButton(
            onPressed: () async {
              await cancelReminder(ref, itemId);
              showSnack('Reminder cancelled');
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
