import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/env.dart';
import 'data/local/app_database.dart';

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
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const SnagApp(),
    ),
  );
}
