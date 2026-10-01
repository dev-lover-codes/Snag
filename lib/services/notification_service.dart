import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications for Calendar events and Saved Messages reminders.
///
/// Uses **inexact** scheduling (no exact-alarm permission). The plugin's boot
/// receiver (AndroidManifest) restores pending notifications after a reboot.
/// The payload is always an in-app route such as `/item/<id>`.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  bool _ready = false;

  /// Routes from notifications tapped while the app is running.
  Stream<String> get taps => _taps.stream;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Calendar events and saved-item reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Returns the route of the notification that launched the app, if any.
  Future<String?> init() async {
    // Website: no local notifications; reminders ring on the phone app.
    if (kIsWeb) return null;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        // Unknown zone id: fall back to UTC; TZDateTime.from keeps the instant.
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_snag'),
        ),
        onDidReceiveNotificationResponse: (r) {
          final p = r.payload;
          if (p != null && p.startsWith('/')) _taps.add(p);
        },
      );
      _ready = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final p = launch!.notificationResponse?.payload;
        if (p != null && p.startsWith('/')) return p;
      }
    } catch (_) {
      // Notifications are optional; the rest of the app must still start.
    }
    return null;
  }

  /// Android 13+ runtime permission. Asked only when a reminder is first set.
  Future<bool> ensurePermission() async {
    if (!_ready) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    if (await android.areNotificationsEnabled() ?? false) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  /// Schedules (or replaces) notification [id]. Times in the past are skipped.
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    String? body,
    required String route,
  }) async {
    if (!_ready || !at.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: route,
    );
  }

  Future<void> cancel(int id) async {
    if (_ready) await _plugin.cancel(id: id);
  }

  Future<List<PendingNotificationRequest>> pending() async =>
      _ready ? _plugin.pendingNotificationRequests() : const [];

  Future<void> cancelWhere(bool Function(String route) test) async {
    for (final p in await pending()) {
      if (p.payload != null && test(p.payload!)) await cancel(p.id);
    }
  }

  Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }
}

/// Stable 31-bit notification id for a key such as `event:<uuid>` (FNV-1a).
int notificationIdFor(String key) {
  var h = 0x811c9dc5;
  for (final c in key.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}
