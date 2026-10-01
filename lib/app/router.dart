import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screens.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/calendar/event_detail_screen.dart';
import '../features/calendar/event_editor_screen.dart';
import '../features/drive/drive_screen.dart';
import '../features/messenger/chat_list/chat_list_screen.dart';
import '../features/messenger/direct/chat_screen.dart';
import '../features/messenger/item_detail/item_detail_screen.dart';
import '../features/messenger/item_editor/item_editor_screen.dart';
import '../features/messenger/saved/saved_screen.dart';
import '../features/profile/profile_screen.dart';
import 'providers.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Bumps go_router whenever sign-in state or a pending share changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(currentUserIdProvider, (_, _) => notifyListeners());
    ref.listen(pendingShareProvider, (_, _) => notifyListeners());
  }
}

/// Only in-app paths are allowed as a post-login target.
String? _safeFrom(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  if (from.startsWith('/login') || from.startsWith('/signup')) return null;
  // Email-link leftovers such as `/error=otp_expired&…` or `/access_token=…`
  // are not app routes.
  if (from.split('?').first.contains('=')) return null;
  return from;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/messenger',
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(currentUserIdProvider) != null;
      final loc = state.matchedLocation;
      final onAuth = loc == '/login' || loc == '/signup';

      if (!signedIn) {
        if (onAuth) return null;
        final from = state.uri.toString();
        return from == '/messenger'
            ? '/login'
            : '/login?from=${Uri.encodeComponent(from)}';
      }

      final hasShare = ref.read(pendingShareProvider) != null;
      if (hasShare && loc != '/share') return '/share';
      if (!hasShare && loc == '/share') return '/messenger/saved';

      if (onAuth) {
        return _safeFrom(state.uri.queryParameters['from']) ?? '/messenger';
      }
      if (loc == '/') return '/messenger';
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(
        child: FilledButton.tonal(
          onPressed: () => context.go('/messenger'),
          child: const Text('Page not found — go to Snag'),
        ),
      ),
    ),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/messenger'),
      GoRoute(
        path: '/login',
        builder: (_, s) => LoginScreen(from: s.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, s) => SignUpScreen(from: s.uri.queryParameters['from']),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messenger',
                builder: (_, _) => const ChatListScreen(),
                routes: [
                  GoRoute(
                    path: 'saved',
                    builder: (_, _) => const SavedScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/drive', builder: (_, _) => const DriveScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (_, _) => const CalendarScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/item/new',
        builder: (_, s) => ItemEditorScreen.create(
          initialType: s.uri.queryParameters['type'],
          args: s.extra is NewItemArgs ? s.extra as NewItemArgs : null,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/item/:id',
        builder: (_, s) => ItemDetailScreen(itemId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            parentNavigatorKey: _rootKey,
            path: 'edit',
            builder: (_, s) =>
                ItemEditorScreen.edit(itemId: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/share',
        builder: (context, s) => Consumer(
          builder: (context, ref, _) {
            final text = ref.watch(pendingShareProvider);
            if (text == null) return const SizedBox.shrink();
            return ItemEditorScreen.share(key: ValueKey(text), shareText: text);
          },
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/profile',
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/calendar/event/new',
        builder: (_, _) => const EventEditorScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/calendar/event/:id',
        builder: (_, s) => EventDetailScreen(eventId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            parentNavigatorKey: _rootKey,
            path: 'edit',
            builder: (_, s) =>
                EventEditorScreen(eventId: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/chat/:conversationId',
        builder: (_, s) =>
            ChatScreen(conversationId: s.pathParameters['conversationId']!),
      ),
    ],
  );
});

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Messenger',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Drive',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
}
