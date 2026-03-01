import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final predictionsStreamProvider =
    StreamProvider<List<PredictionView>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllPredictionViews();
});
