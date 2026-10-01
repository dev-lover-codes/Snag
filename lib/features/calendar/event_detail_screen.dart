import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/remote/events_remote.dart';
import '../../data/repositories/events_repository.dart';
import '../common/common_widgets.dart';

/// Event detail. Deleted and foreign ids both show the same message.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final String eventId;

  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/calendar');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(eventProvider(eventId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: [
          if (event.hasValue) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/calendar/event/$eventId/edit'),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref),
            ),
          ],
        ],
      ),
      body: event.when(
        loading: () => const LoadingView(),
        error: (e, _) => e is ItemGoneException
            ? EmptyState(
                icon: Icons.event_busy_outlined,
                message: 'This event no longer exists.',
                action: FilledButton.tonal(
                  onPressed: () => context.go('/calendar'),
                  child: const Text('Back to Calendar'),
                ),
              )
            : ErrorView(
                message: userMessageFor(e),
                onRetry: () => ref.invalidate(eventProvider(eventId)),
              ),
        data: (e) => _Body(event: e),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this event?',
      message: 'It will be deleted on all your devices.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(eventsRepositoryProvider).delete(eventId);
      ref.invalidate(eventsProvider);
      showSnack('Event deleted');
      if (context.mounted) _back(context);
    } catch (e) {
      showSnack(userMessageFor(e));
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final time = event.endsAt == null
        ? formatTime(event.startsAt)
        : '${formatTime(event.startsAt)} – ${formatTime(event.endsAt!)}';
    final endDay =
        event.endsAt != null && !isSameDay(event.startsAt, event.endsAt!)
        ? ' (ends ${formatShortDate(event.endsAt!)})'
        : '';

    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SelectableText(event.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        row(
          Icons.calendar_today_outlined,
          '${eventDayLabel(event.startsAt)} · ${formatShortDate(event.startsAt)}',
        ),
        row(Icons.schedule_outlined, '$time$endDay'),
        row(
          event.remindMinutesBefore == null
              ? Icons.notifications_off_outlined
              : Icons.notifications_active_outlined,
          event.remindMinutesBefore == null
              ? 'No reminder'
              : 'Reminder: ${reminderChoices[event.remindMinutesBefore]}',
        ),
        if (event.note != null) ...[
          const Divider(height: 32),
          SelectableText(event.note!, style: theme.textTheme.bodyLarge),
        ],
      ],
    );
  }
}
