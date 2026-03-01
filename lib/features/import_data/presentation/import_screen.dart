import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
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
          await db.insertQuestion(
            QuestionsCompanion.insert(
              text: q.text,
              category: file.category,
              tags: drift.Value(tagsJson),
              source: drift.Value(file.source),
              hasKnownAnswer: drift.Value(q.answer != null),
              knownAnswer: drift.Value(q.answer),
              deadline: drift.Value(q.deadline),
            ),
          );
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

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Unterstützte Formate',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'JSON oder YAML mit den Feldern: version, category (epistemic/aleatory), questions[]. '
              'Jede Frage braucht mindestens "text". Optional: tags, answer, deadline.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
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

class _PreviewSection extends StatelessWidget {
  final ImportFile file;
  final String filename;

  const _PreviewSection({required this.file, required this.filename});

  @override
  Widget build(BuildContext context) {
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
                _PreviewRow('Kategorie',
                    file.category == 'epistemic' ? 'Epistemisch' : 'Aleatorisch'),
                if (file.source != null)
                  _PreviewRow('Quelle', file.source!),
                _PreviewRow('Fragen', '${file.questions.length}'),
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
            width: 80,
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
