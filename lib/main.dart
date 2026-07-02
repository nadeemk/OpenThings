import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/theme/tokens.dart';

void main() {
  runApp(const ProviderScope(child: OpenThingsApp()));
}

class OpenThingsApp extends StatelessWidget {
  const OpenThingsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OpenThings',
      debugShowCheckedModeBanner: false,
      theme: OtTheme.light(),
      darkTheme: OtTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
