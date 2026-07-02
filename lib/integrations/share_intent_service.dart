import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/repositories/task_repository.dart';

/// Android share-target: text shared to OpenThings lands in the Inbox.
/// (iOS needs a share extension target, which requires an Xcode-managed
/// project change — see README.)
class ShareIntentService {
  ShareIntentService(this._tasks);

  final TaskRepository _tasks;
  static const _channel = MethodChannel('openthings/share');

  Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText' && call.arguments is String) {
        await _capture(call.arguments as String);
      }
    });
    // Cold-start share.
    final initial =
        await _channel.invokeMethod<String>('getInitialSharedText');
    if (initial != null) await _capture(initial);
  }

  Future<void> _capture(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final lines = trimmed.split('\n');
    await _tasks.createTodo(
      title: lines.first,
      notes: lines.length > 1 ? lines.skip(1).join('\n') : '',
    );
  }
}
