/// Sync backend configuration, injected at build time:
///
///   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// When absent the app runs fully local (NoopSyncService).
abstract final class SyncConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get enabled =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
