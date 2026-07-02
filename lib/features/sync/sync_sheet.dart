import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../sync/sync_config.dart';
import '../../sync/sync_service.dart';

/// Compact sync status button for the sidebar footer.
class SyncStatusButton extends ConsumerWidget {
  const SyncStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(syncStatusProvider).value ?? SyncStatus.disabled;
    final (icon, color, label) = switch (status) {
      SyncStatus.disabled => (
          Icons.cloud_off_rounded,
          OtColors.trashGray,
          'Local only'
        ),
      SyncStatus.offline => (
          Icons.cloud_outlined,
          OtColors.trashGray,
          'Sign in'
        ),
      SyncStatus.connecting => (
          Icons.cloud_sync_rounded,
          OtColors.somedaySand,
          'Connecting…'
        ),
      SyncStatus.syncing => (
          Icons.cloud_sync_rounded,
          OtColors.accent,
          'Syncing…'
        ),
      SyncStatus.upToDate => (
          Icons.cloud_done_rounded,
          OtColors.logbookGreen,
          'Synced'
        ),
      SyncStatus.error => (
          Icons.cloud_off_rounded,
          OtColors.deadlineRed,
          'Sync error'
        ),
    };
    return TextButton.icon(
      onPressed: () => _showSyncSheet(context, ref),
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  void _showSyncSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _SyncSheet(),
    );
  }
}

class _SyncSheet extends ConsumerStatefulWidget {
  const _SyncSheet();

  @override
  ConsumerState<_SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends ConsumerState<_SyncSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sync = ref.read(syncServiceProvider);

    if (!SyncConfig.enabled) {
      return Padding(
        padding: const EdgeInsets.all(OtSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sync is off', style: theme.textTheme.titleLarge),
            const SizedBox(height: OtSpacing.sm),
            Text(
              'This build runs fully local. To enable multi-device sync, '
              'create a Supabase project, apply supabase/migrations, and '
              'rebuild with:\n\n'
              'flutter run --dart-define=SUPABASE_URL=… '
              '--dart-define=SUPABASE_ANON_KEY=…',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: OtSpacing.xl),
          ],
        ),
      );
    }

    if (sync.isSignedIn) {
      return Padding(
        padding: const EdgeInsets.all(OtSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Morrow Cloud', style: theme.textTheme.titleLarge),
            const SizedBox(height: OtSpacing.md),
            Row(
              children: [
                FilledButton.icon(
                  onPressed:
                      _busy ? null : () => _run(() => sync.syncNow()),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Sync now'),
                ),
                const SizedBox(width: OtSpacing.md),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            await sync.signOut();
                            // On the web (this could be a shared/public
                            // computer) erase the local copy so no to-dos
                            // are left behind. Native devices keep their
                            // cache for fast restart.
                            if (kIsWeb) {
                              await ref
                                  .read(databaseProvider)
                                  .wipeLocalData();
                            }
                          }),
                  child: Text(kIsWeb ? 'Sign out & clear' : 'Sign out'),
                ),
                const Spacer(),
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: OtColors.deadlineRed),
                  onPressed: _busy
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Delete account?'),
                              content: const Text(
                                  'This permanently deletes your account '
                                  'and all synced data. Data on this '
                                  'device is kept.'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Cancel')),
                                FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor:
                                            OtColors.deadlineRed),
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await _run(() async {
                              await sync.deleteAccount();
                              // Remove the local copy too, on every
                              // platform — the account is gone.
                              await ref
                                  .read(databaseProvider)
                                  .wipeLocalData();
                            });
                          }
                        },
                  child: const Text('Delete account'),
                ),
              ],
            ),
            const SizedBox(height: OtSpacing.xl),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: OtSpacing.xl,
        right: OtSpacing.xl,
        top: OtSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + OtSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sign in to sync', style: theme.textTheme.titleLarge),
          const SizedBox(height: OtSpacing.md),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                labelText: 'Email', border: OutlineInputBorder()),
          ),
          const SizedBox(height: OtSpacing.md),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Password', border: OutlineInputBorder()),
          ),
          if (_error != null) ...[
            const SizedBox(height: OtSpacing.sm),
            Text(_error!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: OtColors.deadlineRed)),
          ],
          const SizedBox(height: OtSpacing.lg),
          Row(
            children: [
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => sync.signIn(
                        email: _email.text.trim(),
                        password: _password.text)),
                child: const Text('Sign in'),
              ),
              const SizedBox(width: OtSpacing.md),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => sync.signUp(
                        email: _email.text.trim(),
                        password: _password.text)),
                child: const Text('Create account'),
              ),
            ],
          ),
          const SizedBox(height: OtSpacing.md),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() => sync.signInWithOAuth('apple')),
                icon: const Icon(Icons.apple_rounded, size: 16),
                label: const Text('Apple'),
              ),
              const SizedBox(width: OtSpacing.md),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() => sync.signInWithOAuth('google')),
                icon: const Icon(Icons.g_mobiledata_rounded, size: 18),
                label: const Text('Google'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
