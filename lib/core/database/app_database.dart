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
      text().withDefault(const Constant('binary'))();
  // 'binary' | 'factual' | 'interval'
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
  int get schemaVersion => 5;

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
            await m.addColumn(questions, questions.unit as GeneratedColumn<Object>);
          }
          if (from < 4) {
            // Migrate epistemic binary questions to the new 'factual' type.
            await m.database.customStatement(
              "UPDATE questions SET prediction_type = 'factual' "
              "WHERE prediction_type = 'binary' AND category = 'epistemic'",
            );
          }
          if (from < 5) {
            // v5: probability type removed; remap to binary (aleatory) or factual (epistemic).
            await m.database.customStatement(
              "UPDATE questions SET prediction_type = 'binary' "
              "WHERE prediction_type = 'probability' AND category = 'aleatory'",
            );
            await m.database.customStatement(
              "UPDATE questions SET prediction_type = 'factual' "
              "WHERE prediction_type = 'probability' AND category = 'epistemic'",
            );
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

  Future<void> deleteTagGlobally(String tag) async {
    final all = await select(questions).get();
    for (final q in all) {
      final current = List<String>.from(jsonDecode(q.tags) as List);
      if (current.contains(tag)) {
        await updateQuestionTags(q.id, current..remove(tag));
      }
    }
  }

  Future<void> renameTagGlobally(String oldTag, String newTag) async {
    final all = await select(questions).get();
    for (final q in all) {
      final current = List<String>.from(jsonDecode(q.tags) as List);
      if (current.contains(oldTag)) {
        final updated = current.map((t) => t == oldTag ? newTag : t).toList();
        await updateQuestionTags(q.id, updated);
      }
    }
  }

  /// Rundet alle confidenceLevel-Werte auf den nächsten 5%-Schritt (50–100 %)
  /// und berechnet probability daraus neu. Einmalige Datenmigration.
  Future<void> roundAllConfidenceLevels() async {
    final all = await getAllEstimates();
    for (final e in all) {
      final rounded =
          ((e.confidenceLevel / 0.05).round() * 0.05).clamp(0.5, 1.0);
      if ((rounded - e.confidenceLevel).abs() < 1e-10) continue;

      final q = await getQuestion(e.questionId);
      final double newProbability;
      if (q.predictionType == 'binary' || q.predictionType == 'factual') {
        newProbability = e.binaryChoice == true ? rounded : 1.0 - rounded;
      } else {
        newProbability = rounded;
      }

      await (update(estimates)..where((est) => est.id.equals(e.id))).write(
        EstimatesCompanion(
          confidenceLevel: Value(rounded),
          probability: Value(newProbability),
        ),
      );
    }
  }

  Future<void> updateDeadline(int id, DateTime? deadline) =>
      (update(questions)..where((q) => q.id.equals(id)))
          .write(QuestionsCompanion(deadline: Value(deadline)));

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

  /// Exportiert eine bereits gefilterte Liste von Vorhersagen ohne eigene
  /// Schätzungen – zum Weitergeben aus der Vorhersage-Liste heraus.
  Future<Map<String, dynamic>> exportViewsForSharing(
      List<PredictionView> views) async {
    final result = <Map<String, dynamic>>[];
    for (final v in views) {
      final q = v.question;
      final effectiveUnit = q.predictionType == 'interval'
          ? (q.unit ?? v.estimate?.unit)
          : null;
      result.add({
        'text': q.questionText,
        'category': q.category,
        'predictionType': q.predictionType,
        'tags': jsonDecode(q.tags),
        if (q.deadline != null) 'deadline': q.deadline!.toIso8601String(),
        if (effectiveUnit != null && effectiveUnit.isNotEmpty)
          'unit': effectiveUnit,
        if (v.resolution != null)
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

  /// Unobfuscated full export for encrypted backup use only.
  Future<Map<String, dynamic>> exportForBackup() async {
    final qs = await getAllQuestions();
    final result = <Map<String, dynamic>>[];
    for (final q in qs) {
      final estimate = await getEstimateForQuestion(q.id);
      final resolution = await getResolutionForQuestion(q.id);
      result.add({
        'text': q.questionText,
        'category': q.category,
        'predictionType': q.predictionType,
        'tags': jsonDecode(q.tags),
        if (q.source != null) 'source': q.source,
        'hasKnownAnswer': q.hasKnownAnswer,
        if (q.knownAnswer != null) 'knownAnswer': q.knownAnswer,
        if (q.deadline != null) 'deadline': q.deadline!.toIso8601String(),
        'createdAt': q.createdAt.toIso8601String(),
        if (q.unit != null) 'unit': q.unit,
        if (estimate != null)
          'estimate': {
            'probability': estimate.probability,
            if (estimate.lowerBound != null) 'lowerBound': estimate.lowerBound,
            if (estimate.upperBound != null) 'upperBound': estimate.upperBound,
            if (estimate.unit != null) 'unit': estimate.unit,
            'confidenceLevel': estimate.confidenceLevel,
            if (estimate.binaryChoice != null)
              'binaryChoice': estimate.binaryChoice,
            'createdAt': estimate.createdAt.toIso8601String(),
          },
        if (resolution != null)
          'resolution': {
            'outcome': resolution.outcome,
            if (resolution.numericOutcome != null)
              'numericOutcome': resolution.numericOutcome,
            if (resolution.notes != null) 'notes': resolution.notes,
            'resolvedAt': resolution.resolvedAt.toIso8601String(),
          },
      });
    }
    return {'version': 1, 'questions': result};
  }

  /// Restores all questions, estimates, and resolutions from backup data.
  Future<void> restoreFromBackup(Map<String, dynamic> backup) async {
    await resetDatabase();
    final questions = (backup['questions'] as List?) ?? [];
    await transaction(() async {
      for (final q in questions) {
        final qMap = q as Map<String, dynamic>;
        final id = await insertQuestion(QuestionsCompanion.insert(
          questionText: qMap['text'] as String,
          category: qMap['category'] as String? ?? 'epistemic',
          tags: Value(jsonEncode(qMap['tags'] ?? [])),
          source: Value(qMap['source'] as String?),
          hasKnownAnswer: Value(qMap['hasKnownAnswer'] as bool? ?? false),
          knownAnswer: Value(qMap['knownAnswer'] as bool?),
          deadline: Value(qMap['deadline'] != null
              ? DateTime.tryParse(qMap['deadline'] as String)
              : null),
          predictionType:
              Value(qMap['predictionType'] as String? ?? 'binary'),
          unit: Value(qMap['unit'] as String?),
        ));

        final est = qMap['estimate'] as Map<String, dynamic>?;
        if (est != null) {
          await upsertEstimate(EstimatesCompanion.insert(
            questionId: id,
            probability: (est['probability'] as num).toDouble(),
            confidenceLevel:
                Value((est['confidenceLevel'] as num?)?.toDouble() ?? 0.9),
            binaryChoice: Value(est['binaryChoice'] as bool?),
            lowerBound: Value((est['lowerBound'] as num?)?.toDouble()),
            upperBound: Value((est['upperBound'] as num?)?.toDouble()),
            unit: Value(est['unit'] as String?),
          ));
        }

        final res = qMap['resolution'] as Map<String, dynamic>?;
        if (res != null) {
          await insertResolution(ResolutionsCompanion.insert(
            questionId: id,
            outcome: res['outcome'] as bool,
            notes: Value(res['notes'] as String?),
            numericOutcome:
                Value((res['numericOutcome'] as num?)?.toDouble()),
          ));
        }
      }
    });
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
    final file = File(p.join(dir.path, 'kailibrate.db'));
    return NativeDatabase.createInBackground(file);
  });
}
