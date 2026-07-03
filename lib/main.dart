import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'core/theme/tokens.dart';
import 'sync/sync_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SyncConfig.enabled) {
    await Supabase.initialize(
      url: SyncConfig.supabaseUrl,
      // anon keys remain the common setup; legacy projects don't have
      // publishable keys.
      // ignore: deprecated_member_use
      anonKey: SyncConfig.supabaseAnonKey,
    );
  }
  runApp(const ProviderScope(child: OpenThingsApp()));
}

class OpenThingsApp extends ConsumerWidget {
  const OpenThingsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Morrow',
      debugShowCheckedModeBanner: false,
      theme: OtTheme.light(),
      darkTheme: OtTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
