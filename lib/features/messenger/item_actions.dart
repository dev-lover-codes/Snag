import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/tag_utils.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/items_repository.dart';
import '../../data/repositories/reminders_repository.dart';
import '../common/common_widgets.dart';

/// Runs a conditional update and walks the user through conflicts (6.3).
Future<bool> runItemUpdate(
  BuildContext context,
  WidgetRef ref,
  Future<UpdateOutcome> Function(int? baseVersion) op, {
  String? successMessage,
}) async {
  final repo = ref.read(itemsRepositoryProvider);
  try {
    var outcome = await op(null);
    while (outcome is Conflict) {
      if (!context.mounted) return false;
      final server = outcome.server;
      final choice = await showConflictDialog(context);
      if (choice == ConflictChoice.overwrite) {
        outcome = await op(server.version);
      } else {
        if (choice == ConflictChoice.keepTheirs) {
          await repo.acceptServerVersion(server);
        }
        return false;
      }
    }
    if (outcome is Gone) {
      showSnack(Messages.itemGone);
      return false;
    }
    if (successMessage != null) showSnack(successMessage);
    return true;
  } catch (e) {
    showSnack(
      userMessageFor(e),
      actionLabel: e is OfflineException ? null : 'Retry',
      onAction: () {
        if (context.mounted) {
          runItemUpdate(context, ref, op, successMessage: successMessage);
        }
      },
    );
    return false;
  }
}

Future<void> toggleArchive(
  BuildContext context,
  WidgetRef ref,
  SavedItem item,
) {
  final repo = ref.read(itemsRepositoryProvider);
  final archive = !item.archived;
  return runItemUpdate(
    context,
    ref,
    (v) => repo.setArchived(item, archive, baseVersion: v),
    successMessage: archive ? 'Archived' : 'Restored to Saved Messages',
  );
}

Future<bool> deleteWithConfirm(
  BuildContext context,
  WidgetRef ref,
  SavedItem item,
) async {
  final ok = await confirmDialog(
    context,
    title: 'Delete this item?',
    message: item.remotePath != null
        ? 'The item and its attached file will be deleted on all devices.'
        : 'It will be deleted on all your devices.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!ok) return false;
  try {
    await ref.read(itemsRepositoryProvider).delete(item);
    await cancelReminder(ref, item.id);
    showSnack('Deleted');
    return true;
  } catch (e) {
    showSnack(userMessageFor(e));
    return false;
  }
}

Future<void> copyItem(SavedItem item) async {
  final text = item.type == 'link'
      ? item.url ?? item.title
      : (item.content?.isNotEmpty ?? false)
      ? item.content!
      : item.title;
  await Clipboard.setData(ClipboardData(text: text));
  showSnack('Copied');
}

Future<void> openLink(String url) async {
  final uri = Uri.tryParse(url);
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
  if (!ok) showSnack("Couldn't open this link");
}

/// Opens an attachment (PDF or image) in another app via a signed URL.
Future<void> openAttachment(WidgetRef ref, SavedItem item) async {
  if (item.remotePath == null) return;
  try {
    final url = await ref
        .read(itemsRepositoryProvider)
        .signedUrl(item.remotePath!);
    await openLink(url);
  } catch (e) {
    showSnack(userMessageFor(e));
  }
}

Future<void> editTags(
  BuildContext context,
  WidgetRef ref,
  SavedItem item,
) async {
  final existing = allTagsOf(ref);
  final result = await showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => TagEditorSheet(initial: item.tags, suggestions: existing),
  );
  if (result == null || !context.mounted) return;
  final repo = ref.read(itemsRepositoryProvider);
  await runItemUpdate(
    context,
    ref,
    (v) => repo.setTags(item, result, baseVersion: v),
    successMessage: 'Tags updated',
  );
}

List<String> allTagsOf(WidgetRef ref) {
  final items = ref.read(allItemsProvider).value ?? const [];
  return {for (final i in items) ...i.tags}.toList()..sort();
}

/// Long-press menu from the Saved Messages chat.
Future<void> showItemMenu(
  BuildContext context,
  WidgetRef ref,
  SavedItem item,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          _menuTile(ctx, Icons.edit_outlined, 'Edit', 'edit'),
          _menuTile(ctx, Icons.sell_outlined, 'Tags', 'tags'),
          _menuTile(
            ctx,
            item.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            item.archived ? 'Restore' : 'Archive',
            'archive',
          ),
          _menuTile(ctx, Icons.copy_rounded, 'Copy', 'copy'),
          if (!kIsWeb)
            _menuTile(ctx, Icons.alarm_add_outlined, 'Remind me', 'remind'),
          _menuTile(
            ctx,
            Icons.delete_outline,
            'Delete',
            'delete',
            color: Theme.of(ctx).colorScheme.error,
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case 'edit':
      context.push('/item/${item.id}/edit');
    case 'tags':
      await editTags(context, ref, item);
    case 'archive':
      await toggleArchive(context, ref, item);
    case 'copy':
      await copyItem(item);
    case 'remind':
      await remindMe(context, ref, item);
    case 'delete':
      await deleteWithConfirm(context, ref, item);
  }
}

Widget _menuTile(
  BuildContext ctx,
  IconData icon,
  String label,
  String value, {
  Color? color,
}) => ListTile(
  leading: Icon(icon, color: color),
  title: Text(label, style: TextStyle(color: color)),
  onTap: () => Navigator.pop(ctx, value),
);

/// Bottom sheet for editing an item's tags.
class TagEditorSheet extends StatefulWidget {
  const TagEditorSheet({
    super.key,
    required this.initial,
    required this.suggestions,
  });
  final List<String> initial;
  final List<String> suggestions;

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  late List<String> _tags = [...widget.initial];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tags', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TagInput(
            tags: _tags,
            suggestions: widget.suggestions,
            onChanged: (t) => setState(() => _tags = t),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, _tags),
            child: const Text('Save tags'),
          ),
        ],
      ),
    );
  }
}

/// Chip-based tag editor with suggestions. Used by the editor and the sheet.
class TagInput extends StatefulWidget {
  const TagInput({
    super.key,
    required this.tags,
    required this.onChanged,
    this.suggestions = const [],
  });
  final List<String> tags;
  final List<String> suggestions;
  final ValueChanged<List<String>> onChanged;

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final added = parseTagInput(raw);
    if (added.isEmpty) {
      _controller.clear();
      return;
    }
    if (widget.tags.length >= maxTagsPerItem) {
      showSnack('Up to $maxTagsPerItem tags per item');
      return;
    }
    widget.onChanged(normalizeTags([...widget.tags, ...added]));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = {
      ...defaultTagSuggestions,
      ...widget.suggestions,
    }.where((t) => !widget.tags.contains(t)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in widget.tags)
                InputChip(
                  label: Text('#$t'),
                  onDeleted: () => widget.onChanged(
                    widget.tags.where((x) => x != t).toList(),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Add a tag (e.g. dsa)',
            prefixIcon: const Icon(Icons.tag),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _add(_controller.text),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: _add,
          onChanged: (v) {
            if (v.endsWith(',') || v.endsWith(' ')) _add(v);
          },
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 0,
            children: [
              for (final s in suggestions.take(12))
                ActionChip(
                  label: Text('#$s'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _add(s),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// "Remind me": Tomorrow / In 3 days / In 7 days at 9:00, or a custom time.
/// Reminders live on this device only and never appear in Calendar.
Future<void> remindMe(
  BuildContext context,
  WidgetRef ref,
  SavedItem item,
) async {
  final now = DateTime.now();
  final choice = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (days, label) in const [
            (1, 'Tomorrow, 9:00'),
            (3, 'In 3 days, 9:00'),
            (7, 'In 7 days, 9:00'),
          ])
            ListTile(
              leading: const Icon(Icons.alarm_outlined),
              title: Text(label),
              subtitle: Text(formatShortDate(reminderPreset(days, now: now))),
              onTap: () => Navigator.pop(ctx, reminderPreset(days, now: now)),
            ),
          ListTile(
            leading: const Icon(Icons.edit_calendar_outlined),
            title: const Text('Custom…'),
            onTap: () => Navigator.pop(ctx, 'custom'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  var at = choice is DateTime ? choice : null;
  if (choice == 'custom') {
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null || !context.mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (t == null) return;
    at = DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }
  if (at == null) return;
  if (!at.isAfter(DateTime.now())) {
    showSnack('Pick a time in the future');
    return;
  }
  final ok = await ref
      .read(remindersRepositoryProvider)
      .set(itemId: item.id, title: item.title, at: at);
  ref.invalidate(itemReminderProvider(item.id));
  showSnack(
    ok
        ? 'Reminder set for ${formatDateTime(at)}'
        : 'Notifications are off — allow them in Settings to get reminders.',
  );
}

Future<void> cancelReminder(WidgetRef ref, String itemId) async {
  await ref.read(remindersRepositoryProvider).cancel(itemId);
  ref.invalidate(itemReminderProvider(itemId));
}
