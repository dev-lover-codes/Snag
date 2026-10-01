import '../../services/notification_service.dart';
import '../local/app_database.dart';

/// "Remind me" on Saved Messages items. Stored on this device only, in the
/// drafts key/value table (key `reminder:<item_id>`), so logout wipes them.
/// They never appear in Calendar.
class RemindersRepository {
  RemindersRepository({
    required this._db,
    required this._notifications,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final NotificationService _notifications;
  final DateTime Function() _now;

  static String _key(String itemId) => 'reminder:$itemId';
  static int _id(String itemId) => notificationIdFor('item:$itemId');

  /// The active reminder for an item, or null (past reminders are cleared).
  Future<DateTime?> activeFor(String itemId) async {
    final raw = await _db.getDraft(_key(itemId));
    final at = raw == null ? null : DateTime.tryParse(raw);
    if (at == null) return null;
    if (!at.isAfter(_now())) {
      await _db.deleteDraft(_key(itemId));
      return null;
    }
    return at;
  }

  /// Returns false when notifications are not allowed on this device.
  Future<bool> set({
    required String itemId,
    required String title,
    required DateTime at,
  }) async {
    if (!at.isAfter(_now())) return false;
    if (!await _notifications.ensurePermission()) return false;
    await _notifications.schedule(
      id: _id(itemId),
      at: at,
      title: 'Snag reminder',
      body: title,
      route: '/item/$itemId',
    );
    await _db.saveDraft(_key(itemId), at.toIso8601String());
    return true;
  }

  Future<void> cancel(String itemId) async {
    await _notifications.cancel(_id(itemId));
    await _db.deleteDraft(_key(itemId));
  }
}

/// Preset times: tomorrow, in 3 days and in 7 days, each at 9:00.
DateTime reminderPreset(int days, {DateTime? now}) {
  final n = now ?? DateTime.now();
  return DateTime(n.year, n.month, n.day + days, 9);
}
