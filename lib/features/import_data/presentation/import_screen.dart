import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
  final int importedCount;

  const _ImportState({
    this.parsedFile,
    this.filename,
    this.errorMessage,
    this.importing = false,
    this.imported = false,
    this.importedCount = 0,
  });

  _ImportState copyWith({
    ImportFile? parsedFile,
    String? filename,
    String? errorMessage,
    bool? importing,
    bool? imported,
    int? importedCount,
    bool clearError = false,
    bool clearFile = false,
  }) {
    return _ImportState(
      parsedFile: clearFile ? null : (parsedFile ?? this.parsedFile),
      filename: clearFile ? null : (filename ?? this.filename),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      importing: importing ?? this.importing,
      imported: imported ?? this.imported,
      importedCount: importedCount ?? this.importedCount,
    );
  }
}

class _ImportNotifier extends StateNotifier<_ImportState> {
  _ImportNotifier() : super(const _ImportState());

  void setParsed(ImportFile file, String name) {
    state = _ImportState(parsedFile: file, filename: name);
  }

  void setError(String message) {
    // importing explizit zurücksetzen – sonst bleibt der Import-Button
    // nach einem Fehler dauerhaft auf "Importiere…" und gesperrt.
    state = state.copyWith(
      errorMessage: message,
      importing: false,
      clearFile: false,
    );
  }

  void setImporting() {
    state = state.copyWith(importing: true);
  }

  void setImported(int count) {
    state = _ImportState(imported: true, importedCount: count);
  }

  void reset() {
    state = const _ImportState();
  }
}

final _importNotifierProvider =
    StateNotifierProvider.autoDispose<_ImportNotifier, _ImportState>(
        (_) => _ImportNotifier());

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  Set<int>? _selectedIndices;
  Set<int> _duplicateIndices = {};
  bool _loadingExisting = false;

  int get _selectedCount => _selectedIndices?.length ?? 0;

  @override
  Widget build(BuildContext context) {
    final importState = ref.watch(_importNotifierProvider);
    final notifier = ref.read(_importNotifierProvider.notifier);

    ref.listen(
      _importNotifierProvider.select((s) => s.parsedFile),
      (prev, next) {
        if (next == null) {
          setState(() {
            _selectedIndices = null;
            _duplicateIndices = {};
          });
        } else if (next != prev) {
          _loadExistingAndInitSelection(next);
        }
      },
    );

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
                color: Colors.green.withValues(alpha: 0.15),
                child: ListTile(
                  leading:
                      const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(
                    importState.importedCount == 1
                        ? '1 Frage importiert'
                        : '${importState.importedCount} Fragen importiert',
                  ),
                ),
              ),
            ],
            if (importState.parsedFile != null) ...[
              const SizedBox(height: 24),
              _PreviewSection(
                file: importState.parsedFile!,
                filename: importState.filename ?? '',
              ),
              const SizedBox(height: 8),
              if (_loadingExisting)
                const LinearProgressIndicator()
              else
                _buildQuestionList(importState.parsedFile!),
              const SizedBox(height: 16),
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
                      : '$_selectedCount ${_selectedCount == 1 ? 'Frage' : 'Fragen'} importieren'),
                  onPressed:
                      (importState.importing || _selectedCount == 0)
                          ? null
                          : () => _doImport(context, importState),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionList(ImportFile file) {
    final selected = _selectedIndices ?? {};
    final allNonDuplicateIndices = Set<int>.from(
      Iterable.generate(file.questions.length)
          .where((i) => !_duplicateIndices.contains(i)),
    );
    final allNonDuplicateSelected =
        allNonDuplicateIndices.isNotEmpty &&
            allNonDuplicateIndices.every(selected.contains);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Fragen auswählen',
                style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                if (allNonDuplicateSelected) {
                  selected.removeAll(allNonDuplicateIndices);
                } else {
                  selected.addAll(allNonDuplicateIndices);
                }
              }),
              child: Text(allNonDuplicateSelected ? 'Keine' : 'Alle'),
            ),
          ],
        ),
        ...file.questions.asMap().entries.map((entry) {
          final i = entry.key;
          final q = entry.value;
          final isDuplicate = _duplicateIndices.contains(i);
          return CheckboxListTile(
            value: isDuplicate ? false : selected.contains(i),
            onChanged: isDuplicate
                ? null
                : (checked) => setState(() {
                      if (checked == true) {
                        selected.add(i);
                      } else {
                        selected.remove(i);
                      }
                    }),
            title: Text(
              q.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    decoration:
                        isDuplicate ? TextDecoration.lineThrough : null,
                    color: isDuplicate
                        ? Theme.of(context).colorScheme.outline
                        : null,
                  ),
            ),
            subtitle: isDuplicate
                ? Text(
                    'Bereits vorhanden',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  )
                : q.tags.isNotEmpty
                    ? Text(q.tags.join(', '),
                        style: Theme.of(context).textTheme.bodySmall)
                    : null,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          );
        }),
      ],
    );
  }

  Future<void> _loadExistingAndInitSelection(ImportFile file) async {
    setState(() => _loadingExisting = true);
    final db = ref.read(appDatabaseProvider);
    final existing =
        (await db.getAllQuestions()).map((q) => q.questionText).toSet();
    final duplicates = <int>{};
    for (var i = 0; i < file.questions.length; i++) {
      if (existing.contains(file.questions[i].text)) {
        duplicates.add(i);
      }
    }
    if (!mounted) return;
    setState(() {
      _duplicateIndices = duplicates;
      _selectedIndices = Set.from(
        Iterable.generate(file.questions.length)
            .where((i) => !duplicates.contains(i)),
      );
      _loadingExisting = false;
    });
  }

  /// Größenlimit für Import-Inhalte (Zwischenablage und Datei) –
  /// verhindert, dass überlange Payloads den Parser überlasten (DoS/OOM).
  static const _maxImportBytes = 200 * 1024; // 200 KB

  Future<void> _pasteFromClipboard(
      BuildContext context, _ImportNotifier notifier) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final content = data?.text;
    if (content == null || content.trim().isEmpty) {
      notifier.setError('Zwischenablage ist leer oder enthält keinen Text.');
      return;
    }
    if (utf8.encode(content).length > _maxImportBytes) {
      notifier.setError('Inhalt zu groß (max. 200 KB).');
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
      if (file.bytes!.length > _maxImportBytes) {
        notifier.setError('Datei zu groß (max. 200 KB).');
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

  Future<void> _doImport(BuildContext context, _ImportState state) async {
    if (state.parsedFile == null || _selectedIndices == null) return;

    final notifier = ref.read(_importNotifierProvider.notifier);
    notifier.setImporting();

    final db = ref.read(appDatabaseProvider);
    final file = state.parsedFile!;
    final selectedIndices = Set<int>.from(_selectedIndices!);

    final questionsToImport = file.questions
        .asMap()
        .entries
        .where((e) => selectedIndices.contains(e.key))
        .map((e) => e.value)
        .toList();

    try {
      await db.transaction(() async {
        for (final q in questionsToImport) {
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
            await db.upsertResolution(
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

            if (q.predictionType == 'binary' ||
                q.predictionType == 'factual') {
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
            questionCount: questionsToImport.length,
          ),
        );
      });

      notifier.setImported(questionsToImport.length);
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
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsString(yaml.trim());
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/yaml')],
      subject: 'kailibrate-Vorlage',
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
