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
  TextColumn get questionText => text().named('text')();
  TextColumn get category => text()(); // 'epistemic' | 'aleatory'
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get source => text().nullable()();
  BoolColumn get hasKnownAnswer =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get knownAnswer => boolean().nullable()();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  // v2: Vorhersagetyp
  TextColumn get predictionType =>
      text().withDefault(const Constant('probability'))();
  // 'probability' | 'binary' | 'interval'
  // v3: Einheit für interval-Typ (z. B. "m", "°C")
  TextColumn get unit => text().nullable()();
}

class Estimates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get questionId => integer().references(Questions, #id)();
  RealColumn get probability => real()(); // 0.0 – 1.0 (kanonischer Kalibrierwert)
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  // v2: erweiterte Schätzfelder
  RealColumn get lowerBound => real().nullable()();
  RealColumn get upperBound => real().nullable()();
  TextColumn get unit => text().nullable()(); // z. B. "m", "°C"
  RealColumn get confidenceLevel =>
      real().withDefault(const Constant(0.9))();
  BoolColumn get binaryChoice => boolean().nullable()(); // true=JA, false=NEIN

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
  // v2: tatsächlicher Messwert für interval-Typ
  RealColumn get numericOutcome => real().nullable()();
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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(questions, questions.predictionType);
            await m.addColumn(estimates, estimates.lowerBound);
            await m.addColumn(estimates, estimates.upperBound);
            await m.addColumn(estimates, estimates.unit);
            await m.addColumn(estimates, estimates.confidenceLevel);
            await m.addColumn(estimates, estimates.binaryChoice);
            await m.addColumn(resolutions, resolutions.numericOutcome);
          }
          if (from < 3) {
            await m.addColumn(questions, questions.unit);
          }
        },
      );

  // --- Questions ---

  Stream<List<Question>> watchAllQuestions() => select(questions).watch();

  Future<List<Question>> getAllQuestions() => select(questions).get();

  Future<Question> getQuestion(int id) =>
      (select(questions)..where((q) => q.id.equals(id))).getSingle();

  Future<int> insertQuestion(QuestionsCompanion q) =>
      into(questions).insert(q);

  Future<void> deleteQuestion(int id) =>
      (delete(questions)..where((q) => q.id.equals(id))).go();

  Future<void> deleteQuestions(List<int> ids) => transaction(() async {
        await (delete(resolutions)..where((r) => r.questionId.isIn(ids))).go();
        await (delete(estimates)..where((e) => e.questionId.isIn(ids))).go();
        await (delete(questions)..where((q) => q.id.isIn(ids))).go();
      });

  Future<void> updateQuestionTags(int id, List<String> tags) =>
      (update(questions)..where((q) => q.id.equals(id)))
          .write(QuestionsCompanion(tags: Value(jsonEncode(tags))));

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

  Future<void> updateResolutionOutcome(int questionId, bool outcome) =>
      (update(resolutions)..where((r) => r.questionId.equals(questionId)))
          .write(ResolutionsCompanion(outcome: Value(outcome)));

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
      {String? category, List<String>? tags}) async {
    final all = await getAllPredictionViews();
    return all.where((v) {
      if (v.status != PredictionStatus.resolved) return false;
      if (category != null && v.question.category != category) return false;
      if (tags != null && tags.isNotEmpty) {
        if (!tags.any((t) => v.tagList.contains(t))) return false;
      }
      return true;
    }).toList();
  }

  // --- Reset ---

  Future<void> resetDatabase() async {
    await transaction(() async {
      await delete(resolutions).go();
      await delete(estimates).go();
      await delete(importBatches).go();
      await delete(questions).go();
    });
  }

  // --- Export ---

  /// Exportiert aufgelöste Vorhersagen ohne eigene Schätzungen – zum Weitergeben.
  Future<Map<String, dynamic>> exportForSharing(
      {String? category, List<String>? tags}) async {
    final views = await getResolvedPredictionViews(category: category, tags: tags);
    final result = <Map<String, dynamic>>[];
    for (final v in views) {
      final q = v.question;
      final effectiveUnit = q.predictionType == 'interval'
          ? (q.unit ?? v.estimate?.unit)
          : null;
      result.add({
        'text': q.questionText,
        'category': q.category,
        if (q.predictionType != 'probability')
          'predictionType': q.predictionType,
        'tags': jsonDecode(q.tags),
        if (q.deadline != null) 'deadline': q.deadline!.toIso8601String(),
        'hasKnownAnswer': q.hasKnownAnswer,
        if (q.knownAnswer != null) 'knownAnswer': q.knownAnswer,
        if (effectiveUnit != null && effectiveUnit.isNotEmpty) 'unit': effectiveUnit,
        'resolution': _obfuscateResolution({
          'outcome': v.resolution!.outcome,
          if (v.resolution!.numericOutcome != null)
            'numericOutcome': v.resolution!.numericOutcome,
          if (v.resolution!.notes != null) 'notes': v.resolution!.notes,
        }),
      });
    }
    return {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'questions': result,
    };
  }

  Future<Map<String, dynamic>> exportAll() async {
    final qs = await getAllQuestions();
    final result = <Map<String, dynamic>>[];
    for (final q in qs) {
      final estimate = await getEstimateForQuestion(q.id);
      final resolution = await getResolutionForQuestion(q.id);
      result.add({
        'id': q.id,
        'text': q.questionText,
        'category': q.category,
        'predictionType': q.predictionType,
        'tags': jsonDecode(q.tags),
        'source': q.source,
        'hasKnownAnswer': q.hasKnownAnswer,
        'knownAnswer': q.knownAnswer,
        'deadline': q.deadline?.toIso8601String(),
        'createdAt': q.createdAt.toIso8601String(),
        if (estimate != null)
          'estimate': {
            'probability': estimate.probability,
            'lowerBound': estimate.lowerBound,
            'upperBound': estimate.upperBound,
            'unit': estimate.unit,
            'confidenceLevel': estimate.confidenceLevel,
            'binaryChoice': estimate.binaryChoice,
            'createdAt': estimate.createdAt.toIso8601String(),
          },
        if (resolution != null)
          'resolution': _obfuscateResolution({
            'outcome': resolution.outcome,
            'numericOutcome': resolution.numericOutcome,
            'notes': resolution.notes,
            'resolvedAt': resolution.resolvedAt.toIso8601String(),
          }),
      });
    }
    return {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'questions': result,
    };
  }
}

/// ROT13 anwenden, dann Base64 kodieren.
String _obfuscateResolution(Map<String, dynamic> resolution) {
  final plain = jsonEncode(resolution);
  final rot13 = _rot13(plain);
  return base64Encode(utf8.encode(rot13));
}

String _rot13(String input) {
  return String.fromCharCodes(input.codeUnits.map((c) {
    if (c >= 65 && c <= 90) return (c - 65 + 13) % 26 + 65;
    if (c >= 97 && c <= 122) return (c - 97 + 13) % 26 + 97;
    return c;
  }));
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'calibrate.db'));
    return NativeDatabase.createInBackground(file);
  });
}
