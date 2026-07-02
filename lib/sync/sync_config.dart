/// Sync backend configuration, injected at build time:
///
///   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// When absent the app runs fully local (NoopSyncService).
abstract final class SyncConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// PowerSync service endpoint, e.g.
  /// https://xyz.powersync.journeyapps.com. When set (together with the
  /// Supabase keys for auth + upload), sync runs through PowerSync;
  /// otherwise the direct Supabase engine is used.
  static const powersyncUrl = String.fromEnvironment('POWERSYNC_URL');

  static bool get enabled =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get usePowerSync => enabled && powersyncUrl.isNotEmpty;
}
