import '../../core/errors.dart';
import '../../services/notification_service.dart';
import '../remote/events_remote.dart';

/// Reminder choices offered by the event editor (minutes before start).
const reminderChoices = <int?, String>{
  null: 'None',
  0: 'At start',
  10: '10 minutes before',
  60: '1 hour before',
  1440: '1 day before',
};

/// Calendar events. Supabase is the source of truth; reminders are local
/// notifications scheduled on this device.
class EventsRepository {
  EventsRepository({
    required this._remote,
    required this._notifications,
    required this._isOnline,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final EventsRemote _remote;
  final NotificationService _notifications;
  final bool Function() _isOnline;
  final DateTime Function() _now;

  static const routePrefix = '/calendar/event/';

  void _requireOnline() {
    if (!_isOnline()) throw const OfflineException();
  }

  Future<List<CalendarEvent>> list() => _remote.fetchAll();

  /// Throws [ItemGoneException] for deleted or foreign events.
  Future<CalendarEvent> load(String id) async {
    final e = await _remote.fetchOne(id);
    if (e == null) throw const ItemGoneException();
    return e;
  }

  Future<CalendarEvent> create(EventInput input) async {
    final clean = validateEvent(input);
    _requireOnline();
    final saved = await _remote.insert(clean);
    await _schedule(saved);
    return saved;
  }

  Future<CalendarEvent> update(String id, EventInput input) async {
    final clean = validateEvent(input);
    _requireOnline();
    final saved = await _remote.update(id, clean);
    if (saved == null) {
      await _notifications.cancel(_notificationId(id));
      throw const ItemGoneException();
    }
    await _schedule(saved);
    return saved;
  }

  Future<void> delete(String id) async {
    _requireOnline();
    await _remote.delete(id);
    await _notifications.cancel(_notificationId(id));
  }

  /// After login: (re)schedule reminders for events in the next 30 days.
  Future<void> rescheduleUpcoming() async {
    final events = await _remote.fetchAll();
    await _notifications.cancelWhere((r) => r.startsWith(routePrefix));
    final until = _now().add(const Duration(days: 30));
    for (final e in events) {
      final at = e.remindAt;
      if (at != null && at.isBefore(until)) await _schedule(e);
    }
  }

  Future<void> _schedule(CalendarEvent e) async {
    final id = _notificationId(e.id);
    await _notifications.cancel(id);
    final at = e.remindAt;
    if (at == null) return;
    await _notifications.schedule(
      id: id,
      at: at,
      title: e.title,
      body: eventReminderBody(e),
      route: '$routePrefix${e.id}',
    );
  }

  static int _notificationId(String eventId) =>
      notificationIdFor('event:$eventId');
}

String eventReminderBody(CalendarEvent e) {
  final m = e.remindMinutesBefore;
  final start =
      '${e.startsAt.hour.toString().padLeft(2, '0')}:'
      '${e.startsAt.minute.toString().padLeft(2, '0')}';
  return switch (m) {
    0 => 'Starting now · $start',
    10 => 'Starts in 10 minutes · $start',
    60 => 'Starts in 1 hour · $start',
    1440 => 'Tomorrow at $start',
    _ => 'Starts at $start',
  };
}

/// Trims and checks an event (title required, end not before start).
EventInput validateEvent(EventInput input) {
  final title = input.title.trim();
  if (title.isEmpty) throw const ValidationException('Add a title');
  if (title.length > 200) {
    throw const ValidationException('Title must be 200 characters or fewer');
  }
  final note = input.note?.trim();
  if (note != null && note.length > 5000) {
    throw const ValidationException('Note must be 5,000 characters or fewer');
  }
  final end = input.endsAt;
  if (end != null && end.isBefore(input.startsAt)) {
    throw const ValidationException('End time can’t be before the start');
  }
  if (!reminderChoices.containsKey(input.remindMinutesBefore)) {
    throw const ValidationException('Pick a reminder from the list');
  }
  return EventInput(
    title: title,
    note: (note == null || note.isEmpty) ? null : note,
    startsAt: input.startsAt,
    endsAt: end,
    remindMinutesBefore: input.remindMinutesBefore,
  );
}
