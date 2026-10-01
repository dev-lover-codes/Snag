import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snag/core/errors.dart';
import 'package:snag/core/utils/date_utils.dart';
import 'package:snag/data/remote/chats_remote.dart';
import 'package:snag/data/remote/drive_remote.dart';
import 'package:snag/data/remote/events_remote.dart';
import 'package:snag/data/remote/storage_remote.dart';
import 'package:snag/data/repositories/chats_repository.dart';
import 'package:snag/data/repositories/drive_repository.dart';
import 'package:snag/data/repositories/events_repository.dart';
import 'package:snag/data/repositories/items_repository.dart';
import 'package:snag/data/repositories/reminders_repository.dart';
import 'package:snag/services/notification_service.dart';

void main() {
  group('Drive file names', () {
    test('keeps or adds the right extension', () {
      expect(cleanFileName('  report.pdf ', mime: pdfMime), 'report.pdf');
      expect(cleanFileName('report', mime: pdfMime), 'report.pdf');
      expect(
        cleanFileName('holiday', mime: 'image/jpeg', keepExtensionOf: 'a.JPG'),
        'holiday.JPG',
      );
      expect(cleanFileName('a/b', mime: 'image/png'), 'a_b.png');
    });

    test('rejects empty and too-long names', () {
      expect(
        () => cleanFileName('   ', mime: pdfMime),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => cleanFileName('x' * 201, mime: pdfMime),
        throwsA(isA<ValidationException>()),
      );
    });

    test('storage names are ASCII-safe and short', () {
      expect(storageSafeName('My file (1) 😀.pdf'), 'My_file_1_.pdf');
      expect(storageSafeName('${'a' * 100}.pdf').length, 80);
    });
  });

  group('Drive repository', () {
    test('removes the uploaded file when the row insert fails', () async {
      final storage = _FakeStorage();
      final repo = DriveRepository(
        remote: _FailingDriveRemote(),
        storage: storage,
        currentUserId: () => 'user-a',
        isOnline: () => true,
      );
      final tmp = File('${Directory.systemTemp.path}/snag_test.pdf')
        ..writeAsBytesSync([1, 2, 3]);
      await expectLater(
        repo.upload(
          PickedAttachment(path: tmp.path, mime: pdfMime, name: 'x.pdf'),
        ),
        throwsA(isA<StateError>()),
      );
      expect(storage.uploaded.single, startsWith('user-a/'));
      expect(storage.removed, storage.uploaded);
      tmp.deleteSync();
    });

    test('blocks writes offline', () {
      final repo = DriveRepository(
        remote: _FailingDriveRemote(),
        storage: _FakeStorage(),
        currentUserId: () => 'user-a',
        isOnline: () => false,
      );
      expect(
        repo.upload(
          const PickedAttachment(path: 'x', mime: pdfMime, name: 'x'),
        ),
        throwsA(isA<OfflineException>()),
      );
    });
  });

  group('Events', () {
    final start = DateTime(2026, 10, 3, 14);

    test('title is required and trimmed', () {
      expect(
        () => validateEvent(EventInput(title: '  ', startsAt: start)),
        throwsA(isA<ValidationException>()),
      );
      final ok = validateEvent(
        EventInput(title: ' Exam ', note: '  ', startsAt: start),
      );
      expect(ok.title, 'Exam');
      expect(ok.note, isNull);
    });

    test('end cannot be before start', () {
      expect(
        () => validateEvent(
          EventInput(
            title: 'x',
            startsAt: start,
            endsAt: start.subtract(const Duration(minutes: 1)),
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('only offered reminder choices are accepted', () {
      expect(
        () => validateEvent(
          EventInput(title: 'x', startsAt: start, remindMinutesBefore: 7),
        ),
        throwsA(isA<ValidationException>()),
      );
      final e = CalendarEvent(
        id: '1',
        title: 'x',
        startsAt: start,
        remindMinutesBefore: 60,
        updatedAt: start,
      );
      expect(e.remindAt, DateTime(2026, 10, 3, 13));
    });
  });

  group('Dates', () {
    final now = DateTime(2026, 10, 1, 12);
    test('event day labels', () {
      expect(eventDayLabel(DateTime(2026, 10, 1, 23), now: now), 'Today');
      expect(eventDayLabel(DateTime(2026, 10, 2, 0, 5), now: now), 'Tomorrow');
      expect(eventDayLabel(DateTime(2026, 9, 30), now: now), 'Yesterday');
      expect(eventDayLabel(DateTime(2026, 10, 5), now: now), 'Mon, Oct 5');
    });

    test('reminder presets are at 9:00', () {
      expect(reminderPreset(1, now: now), DateTime(2026, 10, 2, 9));
      expect(reminderPreset(7, now: now), DateTime(2026, 10, 8, 9));
    });
  });

  test('notification ids are stable, positive and distinct', () {
    final a = notificationIdFor('event:abc');
    expect(a, notificationIdFor('event:abc'));
    expect(a, isNonNegative);
    expect(a, lessThanOrEqualTo(0x7fffffff));
    expect(notificationIdFor('item:abc'), isNot(a));
  });

  group('Chats', () {
    late _FakeChats remote;
    late ChatsRepository repo;
    setUp(() {
      remote = _FakeChats();
      repo = ChatsRepository(
        remote: remote,
        currentUserId: () => 'me',
        isOnline: () => true,
      );
    });

    test('usernames are normalised and validated before the RPC', () async {
      await repo.start('  @Alice_01 ');
      expect(remote.started, 'alice_01');
      expect(() => repo.start('ab'), throwsA(isA<ValidationException>()));
      expect(() => repo.start('bad name'), throwsA(isA<ValidationException>()));
    });

    test('messages must be 1–4000 characters', () async {
      expect(() => repo.send('c', '   '), throwsA(isA<ValidationException>()));
      expect(
        () => repo.send('c', 'x' * 4001),
        throwsA(isA<ValidationException>()),
      );
      await repo.send('c', '  hi 👋 ');
      expect(remote.sent, 'hi 👋');
    });
  });
}

class _FakeStorage implements StorageRemote {
  final uploaded = <String>[];
  final removed = <String>[];
  @override
  Future<void> uploadBytes(String path, Uint8List bytes, String mime) async =>
      upload(path, File(path), mime);
  @override
  Future<void> upload(String path, File file, String mime) async =>
      uploaded.add(path);
  @override
  Future<void> remove(String path) async => removed.add(path);
  @override
  Future<String> signedUrl(String path) async => 'https://example.com/$path';
  @override
  void clearCache() {}
}

class _FailingDriveRemote implements DriveRemote {
  @override
  Future<List<DriveFile>> fetchAll() async => const [];
  @override
  Future<DriveFile> insert({
    required String id,
    required String name,
    required String storagePath,
    required String mimeType,
    required int sizeBytes,
  }) => throw StateError('insert failed');
  @override
  Future<DriveFile?> rename(String id, String name) async => null;
  @override
  Future<bool> delete(String id) async => false;
}

class _FakeChats implements ChatsRemote {
  String? started;
  String? sent;
  @override
  Future<List<ChatSummary>> myChats() async => const [];
  @override
  Future<String> startDirectChat(String username) async {
    started = username;
    return 'conv';
  }

  @override
  Future<List<ChatMessage>> messages(String conversationId) async => const [];
  @override
  Future<ChatMessage> send(String conversationId, String body) async {
    sent = body;
    return ChatMessage(
      id: '1',
      conversationId: conversationId,
      senderId: 'me',
      body: body,
      createdAt: DateTime(2026),
    );
  }

  @override
  Future<void> markRead(String c, String u, DateTime at) async {}
  @override
  Stream<ChatMessage> inserts({String? conversationId}) => const Stream.empty();
}
