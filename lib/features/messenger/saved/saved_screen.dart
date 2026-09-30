import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/errors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/share_parser.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/items_repository.dart';
import '../../common/common_widgets.dart';
import '../attachment_picker.dart';
import 'message_bubble.dart';
import 'saved_filter.dart';

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(savedFilterProvider).query;
    _searching = _search.text.isNotEmpty;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _closeSearch() {
    _search.clear();
    ref.read(savedFilterProvider.notifier).setQuery('');
    setState(() => _searching = false);
  }

  Future<void> _pickTag(List<String> tags) async {
    final current = ref.read(savedFilterProvider).tag;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: tags.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No tags yet. Add tags from the long-press menu.'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.clear_all),
                    title: const Text('All tags'),
                    selected: current == null,
                    onTap: () => Navigator.pop(ctx, ''),
                  ),
                  for (final t in tags)
                    ListTile(
                      leading: const Icon(Icons.tag),
                      title: Text(t),
                      selected: current == t,
                      onTap: () => Navigator.pop(ctx, t),
                    ),
                ],
              ),
      ),
    );
    if (picked == null) return;
    ref
        .read(savedFilterProvider.notifier)
        .setTag(picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(savedFilterProvider);
    final itemsAsync = ref.watch(filteredItemsProvider);
    final all = ref.watch(allItemsProvider).value ?? const <SavedItem>[];
    final tags = allTags(all);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.chatBackground,
      appBar: AppBar(
        titleSpacing: 0,
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search title, text, link or #tag',
                  filled: false,
                  border: InputBorder.none,
                ),
                onChanged: ref.read(savedFilterProvider.notifier).setQuery,
              )
            : Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: scheme.primary,
                    child: Icon(
                      filter.archived
                          ? Icons.archive_rounded
                          : Icons.bookmark_rounded,
                      color: scheme.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(filter.archived ? 'Archived' : 'Saved Messages'),
                        Text(
                          _subtitle(all, filter.archived),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          if (_searching)
            IconButton(
              tooltip: 'Close search',
              icon: const Icon(Icons.close),
              onPressed: _closeSearch,
            )
          else
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
          IconButton(
            tooltip: 'Filter by tag',
            icon: Badge(
              isLabelVisible: filter.tag != null,
              smallSize: 8,
              child: const Icon(Icons.sell_outlined),
            ),
            onPressed: () => _pickTag(tags),
          ),
          IconButton(
            tooltip: filter.archived ? 'Show inbox' : 'Show archived',
            isSelected: filter.archived,
            icon: const Icon(Icons.archive_outlined),
            selectedIcon: const Icon(Icons.archive_rounded),
            onPressed: () => ref
                .read(savedFilterProvider.notifier)
                .setArchived(!filter.archived),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(filter: filter),
          const SyncBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(syncProvider.notifier).refresh(),
              child: itemsAsync.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: userMessageFor(e),
                  onRetry: () => ref.invalidate(allItemsProvider),
                ),
                data: (items) =>
                    _MessageList(items: items, empty: _emptyState(all, filter)),
              ),
            ),
          ),
          if (!filter.archived) const _Composer(),
        ],
      ),
    );
  }

  String _subtitle(List<SavedItem> all, bool archived) {
    final n = all.where((i) => i.archived == archived).length;
    return n == 1 ? '1 item' : '$n items';
  }

  Widget _emptyState(List<SavedItem> all, SavedFilter filter) {
    final hasAny = all.any((i) => i.archived == filter.archived);
    if (hasAny && filter.isActive) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        message: 'No matches. Try another word or clear the filters.',
        action: TextButton(
          onPressed: () {
            _closeSearch();
            ref.read(savedFilterProvider.notifier).clear();
          },
          child: const Text('Clear filters'),
        ),
      );
    }
    if (filter.archived) {
      return const EmptyState(
        icon: Icons.archive_outlined,
        message: 'Nothing archived. Archived items show up here.',
      );
    }
    return const EmptyState(
      icon: Icons.bookmark_add_outlined,
      message: 'Nothing snagged yet — share a link from Chrome to start.',
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter});
  final SavedFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(savedFilterProvider.notifier);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          children: [
            for (final t in TypeFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(t.label),
                  selected: filter.type == t,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => notifier.setType(t),
                ),
              ),
            if (filter.tag != null)
              InputChip(
                label: Text('#${filter.tag}'),
                selected: true,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onDeleted: () => notifier.setTag(null),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.items, required this.empty});
  final List<SavedItem> items;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      // Scrollable so pull-to-refresh still works.
      return LayoutBuilder(
        builder: (context, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: c.maxHeight, child: empty)],
        ),
      );
    }
    // Newest at the bottom: reverse the list so index 0 is the newest.
    final newestFirst = items.reversed.toList();
    return ListView.builder(
      reverse: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: newestFirst.length,
      itemBuilder: (context, i) {
        final item = newestFirst[i];
        final older = i + 1 < newestFirst.length ? newestFirst[i + 1] : null;
        final showDate =
            older == null || !isSameDay(older.createdAt, item.createdAt);
        return Column(
          key: ValueKey(item.id),
          children: [
            if (showDate) DateSeparator(date: item.createdAt),
            MessageBubble(item: item),
          ],
        );
      },
    );
  }
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer();

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    final parsed = parseSharedText(text);
    final ItemInput input;
    switch (parsed) {
      case ShareEmpty():
        return;
      case SharedLink(:final url, :final title):
        input = ItemInput(type: 'link', url: url, title: title ?? '');
      case SharedNote(:final text):
        input = ItemInput(type: 'note', content: text);
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(itemsRepositoryProvider)
          .create(input, id: const Uuid().v4());
      _controller.clear();
    } catch (e) {
      showSnack(
        userMessageFor(e),
        actionLabel: e is OfflineException || e is ValidationException
            ? null
            : 'Retry',
        onAction: _send,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    final kind = await chooseAttachKind(context);
    if (kind == null || !mounted) return;
    final picked = await pickAttachment(ref, kind);
    if (picked == null || !mounted) return;
    context.push(
      '/item/new?type=${picked.isPdf ? 'note' : 'image'}',
      extra: NewItemArgs(attachment: picked, text: _controller.text),
    );
    _controller.clear();
  }

  void _expand() {
    context.push('/item/new', extra: NewItemArgs(text: _controller.text));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = _controller.text.trim().isNotEmpty;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Attach image or PDF',
                icon: const Icon(Icons.attach_file_rounded),
                onPressed: _sending ? null : _attach,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: maxNoteLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Snag a note or link…',
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Open full editor',
                icon: const Icon(Icons.open_in_full_rounded),
                onPressed: _sending ? null : _expand,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : IconButton.filled(
                        tooltip: 'Send',
                        icon: const Icon(Icons.send_rounded),
                        onPressed: hasText ? _send : null,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prefill passed to `/item/new` through go_router's `extra`.
class NewItemArgs {
  const NewItemArgs({this.text = '', this.attachment});
  final String text;
  final PickedAttachment? attachment;
}
