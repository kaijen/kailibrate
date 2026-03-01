import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// --- Tables ---

class Questions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get text => text()();
  TextColumn get category => text()(); // 'epistemic' | 'aleatory'
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get source => text().nullable()();
  BoolColumn get hasKnownAnswer =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get knownAnswer => boolean().nullable()();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Estimates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questionId => integer().references(Questions, #id)();
  RealColumn get probability => real()(); // 0.0 – 1.0
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {questionId}
      ];
}

class Resolutions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questionId => integer().references(Questions, #id)();
  BoolColumn get outcome => boolean()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get resolvedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class ImportBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get filename => text()();
  TextColumn get source => text().nullable()();
  IntColumn get questionCount => integer()();
  DateTimeColumn get importedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// --- View model ---

enum PredictionStatus { pending, needsResolution, resolved }

class PredictionView {
  final Question question;
  final Estimate? estimate;
  final Resolution? resolution;

  const PredictionView({
    required this.question,
    this.estimate,
    this.resolution,
  });

  PredictionStatus get status {
    if (estimate == null) return PredictionStatus.pending;
    if (resolution == null) return PredictionStatus.needsResolution;
    return PredictionStatus.resolved;
  }

  List<String> get tagList {
    try {
      final decoded = jsonDecode(question.tags) as List;
      return decoded.cast<String>();
    } catch (_) {
      return [];
    }
  }
}

// --- Database ---

@DriftDatabase(tables: [Questions, Estimates, Resolutions, ImportBatches])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // --- Questions ---

  Stream<List<Question>> watchAllQuestions() => select(questions).watch();

  Future<List<Question>> getAllQuestions() => select(questions).get();

  Future<Question> getQuestion(int id) =>
      (select(questions)..where((q) => q.id.equals(id))).getSingle();

  Future<int> insertQuestion(QuestionsCompanion q) =>
      into(questions).insert(q);

  Future<void> deleteQuestion(int id) =>
      (delete(questions)..where((q) => q.id.equals(id))).go();

  // --- Estimates ---

  Future<Estimate?> getEstimateForQuestion(int questionId) =>
      (select(estimates)..where((e) => e.questionId.equals(questionId)))
          .getSingleOrNull();

  Future<int> upsertEstimate(EstimatesCompanion e) =>
      into(estimates).insertOnConflictUpdate(e);

  Future<List<Estimate>> getAllEstimates() => select(estimates).get();

  // --- Resolutions ---

  Future<Resolution?> getResolutionForQuestion(int questionId) =>
      (select(resolutions)..where((r) => r.questionId.equals(questionId)))
          .getSingleOrNull();

  Future<int> insertResolution(ResolutionsCompanion r) =>
      into(resolutions).insert(r);

  Future<List<Resolution>> getAllResolutions() => select(resolutions).get();

  // --- ImportBatches ---

  Future<int> insertImportBatch(ImportBatchesCompanion b) =>
      into(importBatches).insert(b);

  // --- Combined queries ---

  Future<List<PredictionView>> getAllPredictionViews() async {
    final qs = await getAllQuestions();
    final result = <PredictionView>[];
    for (final q in qs) {
      final estimate = await getEstimateForQuestion(q.id);
      final resolution = await getResolutionForQuestion(q.id);
      result.add(PredictionView(
        question: q,
        estimate: estimate,
        resolution: resolution,
      ));
    }
    return result;
  }

  Stream<List<PredictionView>> watchAllPredictionViews() {
    return watchAllQuestions().asyncMap((qs) async {
      final result = <PredictionView>[];
      for (final q in qs) {
        final estimate = await getEstimateForQuestion(q.id);
        final resolution = await getResolutionForQuestion(q.id);
        result.add(PredictionView(
          question: q,
          estimate: estimate,
          resolution: resolution,
        ));
      }
      return result;
    });
  }

  Future<List<PredictionView>> getResolvedPredictionViews(
      {String? category}) async {
    final all = await getAllPredictionViews();
    return all.where((v) {
      if (v.status != PredictionStatus.resolved) return false;
      if (category != null && v.question.category != category) return false;
      return true;
    }).toList();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'callibrate.db'));
    return NativeDatabase.createInBackground(file);
  });
}
