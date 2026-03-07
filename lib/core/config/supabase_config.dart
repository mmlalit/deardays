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

  /// The Supabase project URL (e.g., https://abc123.supabase.co).
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mcmlawztwyrjcwmieciw.supabase.co',
  );

  /// The Supabase anonymous/public API key. This key is safe to include in
  /// client-side code — it only grants access allowed by RLS policies.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1jbWxhd3p0d3lyamN3bWllY2l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4Nzc0NTgsImV4cCI6MjA4ODQ1MzQ1OH0.qFvDzJrHFUaJjucCxkJXvmtkRdumhm5wC0DxQu-Q-AE',
  );
}
