import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/env.dart';
import 'data/local/app_database.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isConfigured) {
    runApp(const NotConfiguredApp());
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  final db = AppDatabase();
  final notifications = NotificationService();
  final launchRoute = await notifications.init();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notifications),
        launchRouteProvider.overrideWithValue(launchRoute),
      ],
      child: const SnagApp(),
    ),
  );
}
