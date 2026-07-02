import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../data/list_queries.dart';

/// Pushes the Today list summary to the Android home-screen widget.
/// (The iOS widget needs a WidgetKit extension target added in Xcode —
/// see README.)
class TodayWidgetService {
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Call whenever the Today view changes.
  Future<void> update(TodayView view) async {
    if (!isSupported) return;
    try {
      final count = view.day.length + view.evening.length;
      final titles = [
        for (final t in view.day.take(3)) t.title,
      ].join('\n');
      await HomeWidget.saveWidgetData<int>('today_count', count);
      await HomeWidget.saveWidgetData<String>('today_titles', titles);
      await HomeWidget.updateWidget(androidName: 'TodayWidgetProvider');
    } catch (_) {
      // Widget updates are best-effort.
    }
  }
}
