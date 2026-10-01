import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors.dart';
import '../data/local/app_database.dart';
import '../data/remote/auth_remote.dart';
import '../data/remote/items_remote.dart';
import '../data/remote/storage_remote.dart';
import '../data/remote/chats_remote.dart';
import '../data/remote/drive_remote.dart';
import '../data/remote/events_remote.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/chats_repository.dart';
import '../data/repositories/drive_repository.dart';
import '../data/repositories/events_repository.dart';
import '../data/repositories/items_repository.dart';
import '../data/repositories/reminders_repository.dart';
import '../features/messenger/saved/saved_filter.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';

/// Overridden in `main.dart` with the real database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseProvider).auth.onAuthStateChange,
);

final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authChangesProvider);
  return ref.watch(supabaseProvider).auth.currentUser?.id;
});

final connectivityServiceProvider = Provider((ref) => ConnectivityService());

final onlineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityServiceProvider).watch(),
);

bool isOnline(Ref ref) => ref.watch(onlineProvider).value ?? true;

final storageRemoteProvider = Provider<StorageRemote>(
  (ref) => SupabaseStorageRemote(ref.watch(supabaseProvider)),
);

final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return ItemsRepository(
    db: ref.watch(databaseProvider),
    remote: SupabaseItemsRemote(client),
    storage: ref.watch(storageRemoteProvider),
    currentUserId: () => client.auth.currentUser?.id,
    isOnline: () => connectivity.isOnline,
    documentsDir: getApplicationDocumentsDirectory,
  );
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    AuthRemote(ref.watch(supabaseProvider)),
    ref.watch(itemsRepositoryProvider),
  ),
);

final usernameProvider = FutureProvider<String?>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(authRepositoryProvider).username();
});

/// The signed-in user's items (all of them, oldest first), from the cache.
final allItemsProvider = StreamProvider<List<SavedItem>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(itemsRepositoryProvider).watchAll();
});

final itemProvider = StreamProvider.family<SavedItem?, String>((ref, id) {
  ref.watch(currentUserIdProvider);
  return ref.watch(itemsRepositoryProvider).watchOne(id);
});

class SavedFilterNotifier extends Notifier<SavedFilter> {
  @override
  SavedFilter build() {
    ref.watch(currentUserIdProvider);
    return const SavedFilter();
  }

  void setQuery(String q) => state = state.copyWith(query: q);
  void setType(TypeFilter t) => state = state.copyWith(type: t);
  void setTag(String? tag) => state = state.copyWith(tag: () => tag);
  void setArchived(bool v) => state = state.copyWith(archived: v);
  void clear() => state = SavedFilter(archived: state.archived);
}

final savedFilterProvider = NotifierProvider<SavedFilterNotifier, SavedFilter>(
  SavedFilterNotifier.new,
);

final filteredItemsProvider = Provider<AsyncValue<List<SavedItem>>>((ref) {
  final filter = ref.watch(savedFilterProvider);
  return ref.watch(allItemsProvider).whenData((l) => applyFilter(l, filter));
});

/// Items with an attachment, newest first — Drive "From Chats".
final fromChatsProvider = Provider<AsyncValue<List<SavedItem>>>((ref) {
  return ref
      .watch(allItemsProvider)
      .whenData(
        (l) =>
            l.where((i) => i.remotePath != null && !i.archived).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
});

class SyncState {
  const SyncState({this.loading = false, this.error, this.lastSynced});
  final bool loading;
  final String? error;
  final DateTime? lastSynced;
}

/// Runs [ItemsRepository.refresh] and exposes loading / error for the UI.
class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    ref.watch(currentUserIdProvider);
    return const SyncState();
  }

  Future<void> refresh() async {
    if (ref.read(currentUserIdProvider) == null) return;
    if (state.loading) return;
    state = SyncState(loading: true, lastSynced: state.lastSynced);
    try {
      await ref.read(itemsRepositoryProvider).refresh();
      if (!ref.mounted) return;
      state = SyncState(lastSynced: DateTime.now());
    } catch (e) {
      if (!ref.mounted) return;
      state = SyncState(
        error: ref.read(connectivityServiceProvider).isOnline
            ? userMessageFor(e)
            : "You're offline — showing saved items.",
        lastSynced: state.lastSynced,
      );
    }
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);

/// Text shared into the app that is waiting for the confirm screen.
/// Persisted so it survives the login detour and app restarts.
class PendingShareNotifier extends Notifier<String?> {
  static const draftKey = 'share_incoming';

  @override
  String? build() => null;

  Future<void> restore() async {
    final saved = await ref.read(databaseProvider).getDraft(draftKey);
    if (saved != null && saved.trim().isNotEmpty) state = saved;
  }

  Future<void> set(String text) async {
    state = text;
    await ref.read(databaseProvider).saveDraft(draftKey, text);
  }

  Future<void> clear() async {
    state = null;
    await ref.read(databaseProvider).deleteDraft(draftKey);
  }
}

final pendingShareProvider = NotifierProvider<PendingShareNotifier, String?>(
  PendingShareNotifier.new,
);

// ---- Notifications (Calendar + item reminders) ---------------------------

/// Overridden in `main.dart` with the initialised service.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

/// Route of the notification that cold-started the app, if any.
final launchRouteProvider = Provider<String?>((ref) => null);

final remindersRepositoryProvider = Provider<RemindersRepository>(
  (ref) => RemindersRepository(
    db: ref.watch(databaseProvider),
    notifications: ref.watch(notificationServiceProvider),
  ),
);

final itemReminderProvider = FutureProvider.family<DateTime?, String>((
  ref,
  itemId,
) {
  ref.watch(currentUserIdProvider);
  return ref.watch(remindersRepositoryProvider).activeFor(itemId);
});

// ---- Drive "My Files" ----------------------------------------------------

final driveRepositoryProvider = Provider<DriveRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return DriveRepository(
    remote: SupabaseDriveRemote(client),
    storage: SupabaseStorageRemote(client, bucket: 'drive'),
    currentUserId: () => client.auth.currentUser?.id,
    isOnline: () => connectivity.isOnline,
  );
});

final driveFilesProvider = FutureProvider<List<DriveFile>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(driveRepositoryProvider).list();
});

final driveSignedUrlProvider = FutureProvider.family<String, DriveFile>(
  (ref, f) => ref.watch(driveRepositoryProvider).signedUrl(f),
);

// ---- Calendar ------------------------------------------------------------

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  return EventsRepository(
    remote: SupabaseEventsRemote(ref.watch(supabaseProvider)),
    notifications: ref.watch(notificationServiceProvider),
    isOnline: () => connectivity.isOnline,
  );
});

final eventsProvider = FutureProvider<List<CalendarEvent>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(eventsRepositoryProvider).list();
});

final eventProvider = FutureProvider.family<CalendarEvent, String>((ref, id) {
  ref.watch(currentUserIdProvider);
  return ref.watch(eventsRepositoryProvider).load(id);
});

// ---- 1:1 chats -----------------------------------------------------------

final chatsRepositoryProvider = Provider<ChatsRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return ChatsRepository(
    remote: SupabaseChatsRemote(client),
    storage: SupabaseStorageRemote(client, bucket: 'direct-files'),
    currentUserId: () => client.auth.currentUser?.id,
    isOnline: () => connectivity.isOnline,
  );
});

/// Signed link for a 1:1 chat attachment (cached for the session).
final directFileUrlProvider = FutureProvider.family<String, String>(
  (ref, path) => ref.watch(chatsRepositoryProvider).signedUrl(path),
);

/// Images and PDFs from my 1:1 chats, newest first (Drive → From Chats).
final chatFilesProvider = FutureProvider<List<ChatMessage>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(chatsRepositoryProvider).attachments();
});

/// My conversations, refreshed whenever a new message arrives in any of them.
final chatsProvider = StreamProvider<List<ChatSummary>>((ref) async* {
  if (ref.watch(currentUserIdProvider) == null) {
    yield const [];
    return;
  }
  final repo = ref.watch(chatsRepositoryProvider);
  yield await repo.chats();
  await for (final _ in repo.newMessages()) {
    try {
      yield await repo.chats();
    } catch (_) {
      // Keep showing the last list; pull to refresh retries.
    }
  }
});
