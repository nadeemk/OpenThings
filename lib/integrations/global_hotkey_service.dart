import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

/// OS-global Quick Entry hotkey (⌃Space) on desktop: brings the window
/// to the front and opens the capture dialog even when OpenThings is in
/// the background — Things' Quick Entry.
class GlobalHotkeyService {
  GlobalHotkeyService(this._onActivate);

  final Future<void> Function() _onActivate;
  bool _registered = false;

  static bool get isSupported =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  Future<void> init() async {
    if (!isSupported || _registered) return;
    try {
      await windowManager.ensureInitialized();
      await hotKeyManager.unregisterAll();
      await hotKeyManager.register(
        HotKey(
          key: PhysicalKeyboardKey.space,
          modifiers: [HotKeyModifier.control],
          scope: HotKeyScope.system,
        ),
        keyDownHandler: (_) async {
          await windowManager.show();
          await windowManager.focus();
          await _onActivate();
        },
      );
      _registered = true;
    } catch (_) {
      // Registration can fail (e.g. hotkey taken); Quick Entry remains
      // available in-app via ⌃Space.
    }
  }

  Future<void> dispose() async {
    if (_registered) await hotKeyManager.unregisterAll();
  }
}
