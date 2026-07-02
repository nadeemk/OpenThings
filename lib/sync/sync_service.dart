/// Connection state of the sync backend.
enum SyncStatus { disabled, offline, connecting, syncing, upToDate, error }

/// The seam between the local-first app and any sync backend.
///
/// The app is fully functional with [NoopSyncService]; a
/// Supabase/PowerSync implementation plugs in behind this interface
/// without touching feature code. Implementations observe the local
/// drift database (all writes already go through repositories that
/// stamp `modifiedAt`) and reconcile with the remote store using
/// per-field last-writer-wins.
abstract interface class SyncService {
  /// Current status, as a stream for status UI.
  Stream<SyncStatus> get status;

  /// Signs in and begins syncing. No-op when already signed in.
  Future<void> signIn({required String email, required String password});

  Future<void> signUp({required String email, required String password});

  /// OAuth sign-in; [provider] is 'apple' or 'google'.
  Future<void> signInWithOAuth(String provider);

  Future<void> signOut();

  /// Permanently deletes the account and all synced data (local data is
  /// untouched). Signs out afterwards.
  Future<void> deleteAccount();

  /// Whether a user session exists.
  bool get isSignedIn;

  /// Force an immediate sync pass (pull + push). Implementations that
  /// sync continuously may treat this as a hint.
  Future<void> syncNow();

  /// Release resources.
  Future<void> dispose();
}

/// Local-only mode: sync disabled, everything stays on device.
class NoopSyncService implements SyncService {
  @override
  Stream<SyncStatus> get status => Stream.value(SyncStatus.disabled);

  @override
  bool get isSignedIn => false;

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw UnsupportedError('Sync is not configured in this build');

  @override
  Future<void> signUp({required String email, required String password}) =>
      throw UnsupportedError('Sync is not configured in this build');

  @override
  Future<void> signInWithOAuth(String provider) =>
      throw UnsupportedError('Sync is not configured in this build');

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> syncNow() async {}

  @override
  Future<void> dispose() async {}
}
