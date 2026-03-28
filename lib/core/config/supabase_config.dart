/// Supabase configuration for DearDays.
///
/// These values are injected at build time via `--dart-define` flags:
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=your-anon-key
/// ```
///
/// For CI/CD, set these as environment variables in your build pipeline.
/// The anon key is safe to embed in the client — Supabase Row Level Security
/// (RLS) policies protect data on the server side. The actual encryption key
/// is derived client-side and never touches the server.
class SupabaseConfig {
  SupabaseConfig._();

  /// The current environment (development, staging, or production).
  /// Set via `--dart-define=APP_ENV=development`.
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  /// Whether the app is running in development mode.
  static bool get isDev => environment == 'development';

  /// Whether the app is running in staging mode.
  static bool get isStaging => environment == 'staging';

  /// Whether the app is running in production mode.
  static bool get isProd => environment == 'production' || environment.isEmpty;

  /// The Supabase project URL (e.g., https://abc123.supabase.co).
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// The Supabase anonymous/public API key. This key is safe to include in
  /// client-side code — it only grants access allowed by RLS policies.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
}
