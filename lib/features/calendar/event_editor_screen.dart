import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/remote/events_remote.dart';
import '../../data/repositories/events_repository.dart';
import '../common/common_widgets.dart';

/// Create (no [eventId]) or edit an event.
class EventEditorScreen extends ConsumerStatefulWidget {
  const EventEditorScreen({super.key, this.eventId});
  final String? eventId;

  @override
  ConsumerState<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends ConsumerState<EventEditorScreen> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date;
  late TimeOfDay _start;
  TimeOfDay? _end;
  int? _remind;

  bool _loading = false;
  bool _saving = false;
  bool _dirty = false;
  bool _gone = false;
  String? _error;

  bool get _isEdit => widget.eventId != null;

  @override
  void initState() {
    super.initState();
    final next = DateTime.now().add(const Duration(hours: 1));
    _date = startOfDay(next);
    _start = TimeOfDay(hour: next.hour, minute: 0);
    if (_isEdit) {
      _loading = true;
      _load();
    }
    _title.addListener(_markDirty);
    _note.addListener(_markDirty);
  }

  Future<void> _load() async {
    try {
      final e = await ref.read(eventsRepositoryProvider).load(widget.eventId!);
      if (!mounted) return;
      _title.text = e.title;
      _note.text = e.note ?? '';
      setState(() {
        _date = startOfDay(e.startsAt);
        _start = TimeOfDay.fromDateTime(e.startsAt);
        _end = e.endsAt == null ? null : TimeOfDay.fromDateTime(e.endsAt!);
        _remind = e.remindMinutesBefore;
        _loading = false;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _gone = e is ItemGoneException;
        _error = userMessageFor(e);
      });
    }
  }

  void _markDirty() {
    if (!_dirty && !_loading) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay t) =>
      DateTime(_date.year, _date.month, _date.day, t.hour, t.minute);

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final input = EventInput(
      title: _title.text,
      note: _note.text,
      startsAt: _at(_start),
      endsAt: _end == null ? null : _at(_end!),
      remindMinutesBefore: _remind,
    );
    try {
      final repo = ref.read(eventsRepositoryProvider);
      validateEvent(input);
      if (_remind != null &&
          !await ref.read(notificationServiceProvider).ensurePermission()) {
        showSnack(
          'Notifications are off — the event is saved without an alert.',
        );
      }
      final saved = _isEdit
          ? await repo.update(widget.eventId!, input)
          : await repo.create(input);
      ref.invalidate(eventsProvider);
      ref.invalidate(eventProvider(saved.id));
      if (!mounted) return;
      showSnack(_isEdit ? 'Event updated' : 'Event added');
      _dirty = false;
      _close();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = userMessageFor(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _close() => context.canPop() ? context.pop() : context.go('/calendar');

  Future<void> _leave() async {
    if (_dirty) {
      final discard = await confirmDialog(
        context,
        title: 'Discard changes?',
        confirmLabel: 'Discard',
        destructive: true,
      );
      if (!discard || !mounted) return;
    }
    _close();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (d != null) {
      setState(() {
        _date = d;
        _dirty = true;
      });
    }
  }

  Future<void> _pickTime({required bool end}) async {
    final t = await showTimePicker(
      context: context,
      initialTime: end ? (_end ?? _start) : _start,
    );
    if (t == null) return;
    setState(() {
      if (end) {
        _end = t;
      } else {
        _start = t;
      }
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit event' : 'New event';
    if (_gone) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: EmptyState(
          icon: Icons.event_busy_outlined,
          message: 'This event no longer exists.',
          action: FilledButton.tonal(
            onPressed: () => context.go('/calendar'),
            child: const Text('Back to Calendar'),
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: _leave,
          ),
          title: Text(title),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _loading || _saving ? null : _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
        body: _loading ? const LoadingView() : _form(context),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final endInvalid = _end != null && _at(_end!).isBefore(_at(_start));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _title,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today_outlined),
          title: const Text('Date'),
          trailing: Text('${eventDayLabel(_date)} · ${formatShortDate(_date)}'),
          onTap: _pickDate,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_outlined),
          title: const Text('Start time'),
          trailing: Text(_start.format(context)),
          onTap: () => _pickTime(end: false),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.timelapse_outlined),
          title: const Text('End time'),
          subtitle: endInvalid
              ? Text(
                  'Can’t be before the start',
                  style: TextStyle(color: scheme.error),
                )
              : null,
          trailing: _end == null
              ? const Text('Optional')
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_end!.format(context)),
                    IconButton(
                      tooltip: 'Remove end time',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _end = null;
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
          onTap: () => _pickTime(end: true),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          initialValue: _remind,
          decoration: const InputDecoration(
            labelText: 'Reminder',
            prefixIcon: Icon(Icons.notifications_outlined),
          ),
          items: [
            for (final c in reminderChoices.entries)
              DropdownMenuItem(value: c.key, child: Text(c.value)),
          ],
          onChanged: (v) => setState(() {
            _remind = v;
            _dirty = true;
          }),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 8,
          maxLength: 5000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Note',
            alignLabelWithHint: true,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Save'),
        ),
      ],
    );
  }
}
