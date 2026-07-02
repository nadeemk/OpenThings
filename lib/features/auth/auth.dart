import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import '../../core/theme/tokens.dart';
import '../../sync/sync_config.dart';

/// Notifies GoRouter whenever the signed-in state changes so the auth
/// gate can re-evaluate. Only active when sync is configured.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    if (SyncConfig.enabled) {
      _sub = Supabase.instance.client.auth.onAuthStateChange
          .listen((_) => notifyListeners());
    }
  }

  StreamSubscription<AuthState>? _sub;

  bool get isSignedIn =>
      SyncConfig.enabled &&
      Supabase.instance.client.auth.currentSession != null;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final authNotifierProvider = Provider<AuthNotifier>((ref) {
  final notifier = AuthNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Whether the app should force sign-in before use. True only on the web
/// with sync configured — native apps stay offline-first.
bool get authGateEnabled => kIsWeb && SyncConfig.enabled;

/// Turns raw Supabase auth errors into plain language.
String friendlyAuthError(Object e) {
  final s = '$e';
  if (s.contains('anonymous_provider_disabled')) {
    return 'Enter your email and a password.';
  }
  if (s.contains('invalid_credentials') ||
      s.contains('Invalid login credentials')) {
    return 'Wrong email or password.';
  }
  if (s.contains('email_not_confirmed')) {
    return 'Check your inbox and confirm your email first.';
  }
  if (s.contains('user_already_exists') || s.contains('already registered')) {
    return 'That email already has an account — try signing in.';
  }
  final m = RegExp(r'message: ([^,]+)').firstMatch(s);
  return m != null ? m.group(1)! : s;
}

/// Full-screen sign-in shown by the web auth gate.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  String? _info;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action,
      {String? successInfo}) async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and a password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
      if (mounted && successInfo != null) setState(() => _info = successInfo);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sync = ref.read(syncServiceProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(OtSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: OtSpacing.md),
                Text('Morrow',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: OtSpacing.xs),
                Text('Sign in — your to-dos sync across all your devices.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: OtSpacing.xl),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: OtSpacing.md),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _run(() => sync.signIn(
                      email: _email.text.trim(), password: _password.text)),
                  decoration: const InputDecoration(
                      labelText: 'Password', border: OutlineInputBorder()),
                ),
                if (_error != null) ...[
                  const SizedBox(height: OtSpacing.sm),
                  Text(_error!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: OtColors.deadlineRed)),
                ],
                if (_info != null) ...[
                  const SizedBox(height: OtSpacing.sm),
                  Text(_info!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: OtColors.logbookGreen)),
                ],
                const SizedBox(height: OtSpacing.lg),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => sync.signIn(
                          email: _email.text.trim(),
                          password: _password.text)),
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sign in'),
                ),
                const SizedBox(height: OtSpacing.sm),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () => sync.signUp(
                                email: _email.text.trim(),
                                password: _password.text),
                            successInfo:
                                'Account created. If email confirmation is '
                                'on, check your inbox, then sign in.',
                          ),
                  child: const Text('Create account'),
                ),
                const SizedBox(height: OtSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => sync.signInWithOAuth('apple')),
                        icon: const Icon(Icons.apple_rounded, size: 16),
                        label: const Text('Apple'),
                      ),
                    ),
                    const SizedBox(width: OtSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => sync.signInWithOAuth('google')),
                        icon: const Icon(Icons.g_mobiledata_rounded, size: 18),
                        label: const Text('Google'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
