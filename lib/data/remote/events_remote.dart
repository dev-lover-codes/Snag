import 'package:supabase_flutter/supabase_flutter.dart';

/// A row of `public.events` (Calendar).
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    this.note,
    required this.startsAt,
    this.endsAt,
    this.remindMinutesBefore,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? note;
  final DateTime startsAt;
  final DateTime? endsAt;

  /// null = no reminder, 0 = at start.
  final int? remindMinutesBefore;
  final DateTime updatedAt;

  DateTime? get remindAt => remindMinutesBefore == null
      ? null
      : startsAt.subtract(Duration(minutes: remindMinutesBefore!));

  factory CalendarEvent.fromRow(Map<String, dynamic> row) => CalendarEvent(
    id: row['id'] as String,
    title: row['title'] as String,
    note: row['note'] as String?,
    startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
    endsAt: row['ends_at'] == null
        ? null
        : DateTime.parse(row['ends_at'] as String).toLocal(),
    remindMinutesBefore: (row['remind_minutes_before'] as num?)?.toInt(),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}

/// Fields the app writes; owner and timestamps come from the database.
class EventInput {
  const EventInput({
    required this.title,
    this.note,
    required this.startsAt,
    this.endsAt,
    this.remindMinutesBefore,
  });

  final String title;
  final String? note;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int? remindMinutesBefore;

  Map<String, dynamic> toJson() => {
    'title': title,
    'note': note,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt?.toUtc().toIso8601String(),
    'remind_minutes_before': remindMinutesBefore,
  };
}

abstract class EventsRemote {
  Future<List<CalendarEvent>> fetchAll();

  /// Null when the event does not exist *or* belongs to someone else.
  Future<CalendarEvent?> fetchOne(String id);
  Future<CalendarEvent> insert(EventInput input);
  Future<CalendarEvent?> update(String id, EventInput input);
  Future<bool> delete(String id);
}

class SupabaseEventsRemote implements EventsRemote {
  SupabaseEventsRemote(this._client);
  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 20);
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  SupabaseQueryBuilder get _table => _client.from('events');

  @override
  Future<List<CalendarEvent>> fetchAll() async {
    final rows = await _table
        .select()
        .order('starts_at', ascending: true)
        .timeout(_timeout);
    return rows.map(CalendarEvent.fromRow).toList();
  }

  @override
  Future<CalendarEvent?> fetchOne(String id) async {
    if (!_uuid.hasMatch(id)) return null;
    final row = await _table
        .select()
        .eq('id', id)
        .maybeSingle()
        .timeout(_timeout);
    return row == null ? null : CalendarEvent.fromRow(row);
  }

  @override
  Future<CalendarEvent> insert(EventInput input) async {
    final row = await _table
        .insert(input.toJson())
        .select()
        .single()
        .timeout(_timeout);
    return CalendarEvent.fromRow(row);
  }

  @override
  Future<CalendarEvent?> update(String id, EventInput input) async {
    final rows = await _table
        .update(input.toJson())
        .eq('id', id)
        .select()
        .timeout(_timeout);
    return rows.isEmpty ? null : CalendarEvent.fromRow(rows.first);
  }

  @override
  Future<bool> delete(String id) async {
    final rows = await _table
        .delete()
        .eq('id', id)
        .select('id')
        .timeout(_timeout);
    return rows.isNotEmpty;
  }
}
