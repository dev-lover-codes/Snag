import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/remote/events_remote.dart';
import '../common/common_widgets.dart';
import '../profile/profile_avatar.dart';
import 'month_view.dart';

enum _View { month, upcoming }

/// Calendar: a month view with the selected day's events, plus the
/// Upcoming list. Never shows Messenger or Drive data.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _View _view = _View.month;
  bool _showPast = false;
  DateTime _selected = startOfDay(DateTime.now());
  late DateTime _month = DateTime(_selected.year, _selected.month);

  void _select(DateTime day) => setState(() {
    _selected = startOfDay(day);
    _month = DateTime(day.year, day.month);
  });

  void _today() => _select(DateTime.now());

  String _dateParam(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          if (_view == _View.month)
            TextButton(onPressed: _today, child: const Text('Today')),
          const ProfileAvatarButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                SegmentedButton<_View>(
                  segments: const [
                    ButtonSegment(
                      value: _View.month,
                      icon: Icon(Icons.calendar_view_month_rounded),
                      label: Text('Month'),
                    ),
                    ButtonSegment(
                      value: _View.upcoming,
                      icon: Icon(Icons.view_agenda_outlined),
                      label: Text('Upcoming'),
                    ),
                  ],
                  selected: {_view},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => setState(() => _view = v.first),
                ),
                const Spacer(),
                if (_view == _View.upcoming)
                  FilterChip(
                    label: const Text('Show past'),
                    selected: _showPast,
                    onSelected: (v) => setState(() => _showPast = v),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(eventsProvider.future),
              child: events.when(
                loading: () => const LoadingView(),
                error: (e, _) => _scrollable(
                  ErrorView(
                    message: userMessageFor(e),
                    onRetry: () => ref.invalidate(eventsProvider),
                  ),
                ),
                data: (list) => _view == _View.month
                    ? _monthLayout(list)
                    : _EventList(
                        events: _upcoming(list),
                        emptyMessage: _showPast
                            ? 'No events yet — tap + to add one.'
                            : 'Nothing coming up — tap + to add an event.',
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'calendar-new',
        tooltip: 'New event',
        onPressed: () => context.push(
          '/calendar/event/new'
          '${_view == _View.month ? '?date=${_dateParam(_selected)}' : ''}',
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Event'),
      ),
    );
  }

  Widget _monthLayout(List<CalendarEvent> all) {
    final perDay = <DateTime, int>{};
    for (final e in all) {
      final d = startOfDay(e.startsAt);
      perDay[d] = (perDay[d] ?? 0) + 1;
    }
    final dayEvents =
        all.where((e) => startOfDay(e.startsAt) == _selected).toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final month = MonthView(
      month: _month,
      selected: _selected,
      eventCounts: perDay,
      onSelect: _select,
      onMonthChanged: (m) => setState(() => _month = m),
    );
    final agenda = _DayAgenda(day: _selected, events: dayEvents);

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 760) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 400,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [month],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [agenda],
                ),
              ),
            ],
          );
        }
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: month,
            ),
            const Divider(height: 24),
            agenda,
          ],
        );
      },
    );
  }

  List<CalendarEvent> _upcoming(List<CalendarEvent> all) {
    final now = DateTime.now();
    final list = _showPast
        ? [...all]
        : all.where((e) => !(e.endsAt ?? e.startsAt).isBefore(now)).toList();
    return list..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }
}

/// The selected day's events, under (or beside) the month grid.
class _DayAgenda extends StatelessWidget {
  const _DayAgenda({required this.day, required this.events});
  final DateTime day;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        eventDayLabel(day) == formatShortDate(day)
            ? eventDayLabel(day)
            : '${eventDayLabel(day)} · ${formatShortDate(day)}',
        style: theme.textTheme.titleMedium,
      ),
    );
    final body = events.isEmpty
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text(
              'No events — tap + Event to add one.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        : Column(children: [for (final e in events) EventTile(event: e)]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [header, body],
    );
  }
}

Widget _scrollable(Widget child) => LayoutBuilder(
  builder: (context, c) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [SizedBox(height: c.maxHeight, child: child)],
  ),
);

class _EventList extends StatelessWidget {
  const _EventList({required this.events, required this.emptyMessage});
  final List<CalendarEvent> events;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return _scrollable(
        EmptyState(icon: Icons.event_available_outlined, message: emptyMessage),
      );
    }
    final rows = <Widget>[];
    DateTime? day;
    for (final e in events) {
      final d = startOfDay(e.startsAt);
      if (day != d) {
        day = d;
        rows.add(_DayHeader(label: eventDayLabel(e.startsAt)));
      }
      rows.add(EventTile(event: e));
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 88),
      children: rows,
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final past = (event.endsAt ?? event.startsAt).isBefore(DateTime.now());
    final note = event.note?.split('\n').first;
    return ListTile(
      enabled: true,
      leading: SizedBox(
        width: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatTime(event.startsAt),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (event.endsAt != null)
              Text(
                formatTime(event.endsAt!),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
      title: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: past ? TextStyle(color: scheme.onSurfaceVariant) : null,
      ),
      subtitle: note == null || note.isEmpty
          ? null
          : Text(note, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: event.remindMinutesBefore == null
          ? null
          : Icon(
              Icons.notifications_active_outlined,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
      onTap: () => context.push('/calendar/event/${event.id}'),
    );
  }
}
