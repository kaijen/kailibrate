import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/import_parser.dart';

// State for the import screen
class _ImportState {
  final ImportFile? parsedFile;
  final String? filename;
  final String? errorMessage;
  final bool importing;
  final bool imported;

  const _ImportState({
    this.parsedFile,
    this.filename,
    this.errorMessage,
    this.importing = false,
    this.imported = false,
  });

  _ImportState copyWith({
    ImportFile? parsedFile,
    String? filename,
    String? errorMessage,
    bool? importing,
    bool? imported,
    bool clearError = false,
    bool clearFile = false,
  }) {
    return _ImportState(
      parsedFile: clearFile ? null : (parsedFile ?? this.parsedFile),
      filename: clearFile ? null : (filename ?? this.filename),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      importing: importing ?? this.importing,
      imported: imported ?? this.imported,
    );
  }
}

class _ImportNotifier extends StateNotifier<_ImportState> {
  _ImportNotifier() : super(const _ImportState());

  void setParsed(ImportFile file, String name) {
    state = _ImportState(parsedFile: file, filename: name);
  }

  void setError(String message) {
    state = state.copyWith(errorMessage: message, clearFile: false);
  }

  void setImporting() {
    state = state.copyWith(importing: true);
  }

  void setImported() {
    state = const _ImportState(imported: true);
  }

  void reset() {
    state = const _ImportState();
  }
}

final _importNotifierProvider =
    StateNotifierProvider.autoDispose<_ImportNotifier, _ImportState>(
        (_) => _ImportNotifier());

class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(_importNotifierProvider);
    final notifier = ref.read(_importNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Importieren')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FormatInfoCard(),
            const SizedBox(height: 16),
            const _TemplateSection(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Datei auswählen (.json oder .yaml)'),
                onPressed: importState.importing
                    ? null
                    : () => _pickFile(context, notifier),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.content_paste),
                label: const Text('Aus Zwischenablage einfügen'),
                onPressed: importState.importing
                    ? null
                    : () => _pasteFromClipboard(context, notifier),
              ),
            ),
            if (importState.errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorCard(message: importState.errorMessage!),
            ],
            if (importState.imported) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green.withOpacity(0.15),
                child: const ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Import erfolgreich'),
                ),
              ),
            ],
            if (importState.parsedFile != null) ...[
              const SizedBox(height: 24),
              _PreviewSection(
                file: importState.parsedFile!,
                filename: importState.filename ?? '',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: importState.importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload),
                  label: Text(importState.importing
                      ? 'Importiere...'
                      : '${importState.parsedFile!.questions.length} Fragen importieren'),
                  onPressed: importState.importing
                      ? null
                      : () => _doImport(context, ref, importState),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pasteFromClipboard(
      BuildContext context, _ImportNotifier notifier) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final content = data?.text;
    if (content == null || content.trim().isEmpty) {
      notifier.setError('Zwischenablage ist leer oder enthält keinen Text.');
      return;
    }
    try {
      final parsed = ImportParser.parseAutoDetect(content);
      notifier.setParsed(parsed, 'Zwischenablage');
    } on ImportParseException catch (e) {
      notifier.setError(e.message);
    }
  }

  Future<void> _pickFile(
      BuildContext context, _ImportNotifier notifier) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'yaml', 'yml'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        notifier.setError('Datei konnte nicht gelesen werden.');
        return;
      }

      final content = utf8.decode(file.bytes!);
      final filename = file.name;

      try {
        final parsed = ImportParser.parse(content, filename);
        notifier.setParsed(parsed, filename);
      } on ImportParseException catch (e) {
        notifier.setError(e.message);
      }
    } catch (e) {
      notifier.setError('Fehler beim Öffnen der Datei: $e');
    }
  }

  Future<void> _doImport(
      BuildContext context, WidgetRef ref, _ImportState state) async {
    if (state.parsedFile == null) return;

    final notifier = ref.read(_importNotifierProvider.notifier);
    notifier.setImporting();

    final db = ref.read(appDatabaseProvider);
    final file = state.parsedFile!;

    try {
      await db.transaction(() async {
        for (final q in file.questions) {
          final tagsJson = jsonEncode(q.tags);
          final id = await db.insertQuestion(
            QuestionsCompanion.insert(
              questionText: q.text,
              category: q.category ?? file.category,
              tags: drift.Value(tagsJson),
              source: drift.Value(file.source),
              hasKnownAnswer: drift.Value(q.answer != null),
              knownAnswer: drift.Value(q.answer),
              deadline: drift.Value(q.deadline),
              predictionType: drift.Value(q.predictionType),
              unit: drift.Value(q.unit),
            ),
          );

          if (q.hasResolution) {
            await db.insertResolution(
              ResolutionsCompanion.insert(
                questionId: id,
                outcome: q.resolution!.outcome,
                notes: drift.Value(q.resolution!.notes),
                numericOutcome: drift.Value(q.resolution!.numericOutcome),
              ),
            );
          }

          if (q.hasEstimateData) {
            double probability;
            drift.Value<bool?> binaryChoice = const drift.Value(null);
            drift.Value<double?> lowerBound = const drift.Value(null);
            drift.Value<double?> upperBound = const drift.Value(null);
            drift.Value<String?> unit = const drift.Value(null);
            final cl = q.confidenceLevel ?? 0.9;

            if (q.predictionType == 'binary' || q.predictionType == 'factual') {
              probability = q.binaryChoice! ? cl : 1.0 - cl;
              binaryChoice = drift.Value(q.binaryChoice);
            } else {
              // interval
              probability = cl;
              lowerBound = drift.Value(q.lowerBound);
              upperBound = drift.Value(q.upperBound);
              if (q.unit != null) unit = drift.Value(q.unit);
            }

            await db.upsertEstimate(
              EstimatesCompanion.insert(
                questionId: id,
                probability: probability,
                confidenceLevel: drift.Value(cl),
                binaryChoice: binaryChoice,
                lowerBound: lowerBound,
                upperBound: upperBound,
                unit: unit,
              ),
            );
          }
        }

        await db.insertImportBatch(
          ImportBatchesCompanion.insert(
            filename: state.filename ?? 'unknown',
            source: drift.Value(file.source),
            questionCount: file.questions.length,
          ),
        );
      });

      ref.invalidate(predictionsStreamProvider);
      notifier.setImported();
    } catch (e) {
      notifier.setError('Import fehlgeschlagen: $e');
    }
  }
}

class _FormatInfoCard extends StatelessWidget {
  const _FormatInfoCard();

  static final _docsUri = Uri.parse(
    'https://kaijen.github.io/kailibrate/latest/import-export/format/',
  );

  Future<void> _openDocs(BuildContext context) async {
    if (!await launchUrl(_docsUri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Dokumentation konnte nicht geöffnet werden.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'JSON oder YAML – Version 1 (manuell) oder Version 2 (App-Export)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () => _openDocs(context),
              child: const Text('Format →'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Template-Sektion
// ---------------------------------------------------------------------------

class _TemplateSection extends StatelessWidget {
  const _TemplateSection();

  static const _binaryTemplate = '''
version: 1
category: aleatory
source: Meine Vorhersagen
questions:
  - text: Wird es morgen regnen?
    tags: [beispiel]
    predictionType: binary
    binaryChoice: true        # Ja = true, Nein = false
    confidenceLevel: 0.70     # Konfidenz 0.50–1.00 (5%-Schritte)
    deadline: "2026-12-31"    # optional, ISO-8601
''';

  static const _factualTemplate = '''
version: 1
category: epistemic
source: Meine Trivia
questions:
  - text: Liegt Santiago de Chile östlich von New York?
    tags: [beispiel]
    predictionType: factual
    binaryChoice: true        # Wahr = true, Falsch = false
    confidenceLevel: 0.70     # Konfidenz 0.50–1.00 (5%-Schritte)
    answer: true              # bekannte Antwort (optional)
''';

  static const _intervalTemplate = '''
version: 1
category: aleatory
source: Meine Schätzungen
questions:
  - text: Wie viele Kilometer werde ich im März laufen?
    tags: [beispiel]
    predictionType: interval
    lowerBound: 20
    upperBound: 45
    confidenceLevel: 0.80     # Konfidenz 0.50–1.00 (5%-Schritte)
    unit: km                  # optional
    deadline: "2026-03-31"    # optional, ISO-8601
''';

  Future<void> _share(String yaml, String name) async {
    await Share.shareXFiles(
      [
        XFile.fromData(
          utf8.encode(yaml.trim()),
          name: name,
          mimeType: 'application/yaml',
        ),
      ],
      subject: 'Kailibrate-Vorlage',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vorlagen', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.toggle_on_outlined, size: 18),
              label: const Text('Ja/Nein'),
              onPressed: () =>
                  _share(_binaryTemplate, 'vorlage_binary.yaml'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('Wahr/Falsch'),
              onPressed: () =>
                  _share(_factualTemplate, 'vorlage_factual.yaml'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.straighten, size: 18),
              label: const Text('Intervall'),
              onPressed: () =>
                  _share(_intervalTemplate, 'vorlage_interval.yaml'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer),
        title: Text(
          message,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

String _categoryLabel(ImportFile file) {
  final perQuestion =
      file.questions.map((q) => q.category).whereType<String>().toSet();
  if (perQuestion.length > 1) return 'Gemischt';
  final cat = perQuestion.firstOrNull ?? file.category;
  return cat == 'epistemic' ? 'Epistemisch' : 'Aleatorisch';
}

class _PreviewSection extends StatelessWidget {
  final ImportFile file;
  final String filename;

  const _PreviewSection({required this.file, required this.filename});

  @override
  Widget build(BuildContext context) {
    final estimateCount = file.questions.where((q) => q.hasEstimateData).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vorschau', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PreviewRow('Datei', filename),
                _PreviewRow('Kategorie', _categoryLabel(file)),
                if (file.source != null)
                  _PreviewRow('Quelle', file.source!),
                _PreviewRow('Fragen', '${file.questions.length}'),
                if (estimateCount > 0)
                  _PreviewRow('Mit Schätzung', '$estimateCount'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Fragen (erste 5)',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        ...file.questions.take(5).map(
              (q) => Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  leading: q.answer != null
                      ? Icon(
                          q.answer! ? Icons.check : Icons.close,
                          color: q.answer! ? Colors.green : Colors.red,
                          size: 20,
                        )
                      : const Icon(Icons.question_mark, size: 20),
                  title: Text(q.text,
                      style: Theme.of(context).textTheme.bodyMedium),
                  subtitle: q.tags.isNotEmpty
                      ? Text(q.tags.join(', '),
                          style: Theme.of(context).textTheme.bodySmall)
                      : null,
                  trailing: q.hasEstimateData
                      ? const Icon(Icons.percent,
                          size: 16, color: Colors.blue)
                      : null,
                ),
              ),
            ),
        if (file.questions.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '... und ${file.questions.length - 5} weitere',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child:
                Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
