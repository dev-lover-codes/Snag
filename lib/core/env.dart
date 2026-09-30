/// Build-time configuration, read from `--dart-define-from-file=env.json`.
///
/// Never hard-code the Supabase URL or key in source code.
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Keep in sync with `version:` in pubspec.yaml.
  static const appVersion = '1.0.0';
}
