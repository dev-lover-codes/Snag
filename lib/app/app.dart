import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/share_parser.dart';
import '../features/common/common_widgets.dart';
import '../services/share_intent_service.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';
import 'web_frame.dart';

class SnagApp extends ConsumerStatefulWidget {
  const SnagApp({super.key, this.shareService});

  /// Injectable for tests.
  final ShareIntentService? shareService;

  @override
  ConsumerState<SnagApp> createState() => _SnagAppState();
}

class _SnagAppState extends ConsumerState<SnagApp> {
  late final ShareIntentService _share =
      widget.shareService ?? ShareIntentService();
  AppLifecycleListener? _lifecycle;
  StreamSubscription<String>? _notificationTaps;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    Future.microtask(() async {
      await ref.read(pendingShareProvider.notifier).restore();
      await _share.start(_onShare);
      _refresh();
      // Notification taps open their route (signed-out users go via login).
      final launch = ref.read(launchRouteProvider);
      if (launch != null) ref.read(routerProvider).push(launch);
      _notificationTaps = ref
          .read(notificationServiceProvider)
          .taps
          .listen((route) => ref.read(routerProvider).push(route));
    });
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _notificationTaps?.cancel();
    _share.dispose();
    super.dispose();
  }

  /// Calendar + reminders follow the session without touching auth code:
  /// reschedule after login, cancel everything after sign-out.
  Future<void> _onAuthChange(AuthState state) async {
    try {
      if (state.event == AuthChangeEvent.signedOut) {
        await ref.read(notificationServiceProvider).cancelAll();
      } else if (state.session != null &&
          (state.event == AuthChangeEvent.signedIn ||
              state.event == AuthChangeEvent.initialSession)) {
        await ref.read(eventsRepositoryProvider).rescheduleUpcoming();
      }
    } catch (_) {
      // Offline at login: reminders already scheduled on this device remain.
    }
  }

  void _refresh() => ref.read(syncProvider.notifier).refresh();

  Future<void> _onShare(String? text) async {
    if (parseSharedText(text) is ShareEmpty) {
      showSnack('Nothing to save from this share');
      return;
    }
    // The router redirect sends the user to /share (via login if needed).
    await ref.read(pendingShareProvider.notifier).set(text!);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authChangesProvider, (_, next) {
      if (next.value?.event == AuthChangeEvent.signedIn) _refresh();
      final state = next.value;
      if (state != null) _onAuthChange(state);
    });
    ref.listen(onlineProvider, (prev, next) {
      if (prev?.value == false && next.value == true) _refresh();
    });

    return MaterialApp.router(
      title: 'Snag',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => kIsWeb ? WebFrame(child: child!) : child!,
    );
  }
}

/// Shown instead of crashing when env.json values are missing.
class NotConfiguredApp extends StatelessWidget {
  const NotConfiguredApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    home: const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_suggest_outlined, size: 56),
              SizedBox(height: 16),
              Text(
                'App not configured',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Run with --dart-define-from-file=env.json '
                '(copy env.example.json and fill in your Supabase URL '
                'and anon key).',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
