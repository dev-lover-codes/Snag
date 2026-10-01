import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/remote/events_remote.dart';
import '../common/common_widgets.dart';
import '../profile/profile_avatar.dart';

/// Calendar: upcoming events grouped by day. Never shows Messenger or
/// Drive data.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _showPast = false;

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: const [ProfileAvatarButton(), SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Text(
                  'Upcoming',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                FilterChip(
                  label: const Text('Show past events'),
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
                data: (list) => _EventList(
                  events: _visible(list),
                  emptyMessage: _showPast
                      ? 'No events yet — tap + to add one.'
                      : 'Nothing coming up — tap + to add an event.',
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar-new',
        tooltip: 'New event',
        onPressed: () => context.push('/calendar/event/new'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  List<CalendarEvent> _visible(List<CalendarEvent> all) {
    final now = DateTime.now();
    final list = _showPast
        ? [...all]
        : all.where((e) => !(e.endsAt ?? e.startsAt).isBefore(now)).toList();
    return list..sort((a, b) => a.startsAt.compareTo(b.startsAt));
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
