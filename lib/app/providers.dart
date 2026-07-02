import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';

/// The single app-wide database instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
