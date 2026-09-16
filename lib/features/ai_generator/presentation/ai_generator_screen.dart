import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:share_plus/share_plus.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/services/api_key_service.dart';
import '../../../core/services/prompt_template_service.dart';
import '../../../core/utils/obfuscation.dart';
import '../../../core/utils/import_parser.dart';
import 'ai_generator_provider.dart';

class AiGeneratorScreen extends ConsumerStatefulWidget {
  const AiGeneratorScreen({super.key});

  @override
  ConsumerState<AiGeneratorScreen> createState() => _AiGeneratorScreenState();
}

class _AiGeneratorScreenState extends ConsumerState<AiGeneratorScreen> {
  final _topicController = TextEditingController();
  final _tagsController = TextEditingController();
  final Set<String> _selectedTags = {};
  bool _hasApiKey = false;
  Set<int>? _selectedQuestionIndices;

  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }

  void _syncTagsToNotifier() {
    final notifier = ref.read(aiGeneratorProvider.notifier);
    final fromChips = _selectedTags.toList();
    final fromText = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    notifier.setTags({...fromChips, ...fromText}.join(', '));
  }

  Future<void> _checkApiKey() async {
    final key = await ApiKeyService.getKey();
    if (mounted) {
      setState(() => _hasApiKey = key != null && key.isNotEmpty);
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final genState = ref.watch(aiGeneratorProvider);
    final notifier = ref.read(aiGeneratorProvider.notifier);

    // Auto-select first template when templates load
    ref.listen(templatesProvider, (_, next) {
      next.whenData((templates) {
        if (templates.isNotEmpty &&
            ref.read(aiGeneratorProvider).selectedTemplate == null) {
          notifier.selectTemplate(templates.first);
        }
      });
    });

    // Reset question selection when a new generation starts
    ref.listen(aiGeneratorProvider.select((s) => s.phase), (_, next) {
      if (next == AiGeneratorPhase.loading) {
        setState(() => _selectedQuestionIndices = null);
      }
    });

    // Auto-select initial model (last used or first in list)
    ref.listen(initialModelProvider, (_, next) {
      next.whenData((model) {
        if (model != null &&
            ref.read(aiGeneratorProvider).selectedModel == null) {
          notifier.setModel(model);
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('KI-Generator')),
      body: switch (genState.phase) {
        AiGeneratorPhase.loading => _buildLoading(),
        AiGeneratorPhase.preview => _buildPreview(context, ref, genState),
        AiGeneratorPhase.imported => _buildImported(context, genState),
        AiGeneratorPhase.form => _buildForm(context, ref, genState, notifier),
      },
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Fragen werden generiert…'),
        ],
      ),
    );
  }

  Widget _buildImported(BuildContext context, AiGeneratorState genState) {
    final hasCost = genState.generationCost != null ||
        genState.generationTokens != null;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasCost) ...[
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.toll,
                        size: 36,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 8),
                    if (genState.generationCost != null)
                      Text(
                        '\$${genState.generationCost!.toStringAsFixed(4)}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    if (genState.generationTokens != null)
                      Text(
                        '${genState.generationTokens} Tokens',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          Text(
            genState.importedCount == 1
                ? '1 Frage importiert'
                : '${genState.importedCount} Fragen importiert',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fertig'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    WidgetRef ref,
    AiGeneratorState genState,
    AiGeneratorNotifier notifier,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_hasApiKey) _buildNoKeyCard(context),
          if (genState.errorMessage != null) ...[
            _ErrorCard(message: genState.errorMessage!),
            const SizedBox(height: 16),
          ],
          _TemplateSelector(
            selectedTemplate: genState.selectedTemplate,
            onSelected: notifier.selectTemplate,
            onTemplatesChanged: () {
              ref.invalidate(templatesProvider);
              // Re-check if selected template still exists
              ref.read(templatesProvider.future).then((templates) {
                final current = ref.read(aiGeneratorProvider).selectedTemplate;
                if (current != null &&
                    !templates.any((t) => t.id == current.id)) {
                  if (templates.isNotEmpty) {
                    notifier.selectTemplate(templates.first);
                  }
                }
              });
            },
          ),
          const SizedBox(height: 20),
          Text('Modell', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ref.watch(modelListProvider).when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Fehler beim Laden der Modelle: $e'),
            data: (models) => models.isEmpty
                ? Text(
                    'Keine Modelle konfiguriert – bitte in den Einstellungen eintragen.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  )
                : DropdownButtonFormField<String>(
                    initialValue: genState.selectedModel,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: models
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (m) {
                      if (m != null) notifier.setModel(m);
                    },
                  ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _topicController,
            decoration: const InputDecoration(
              labelText: 'Thema',
              hintText: 'z.B. Europäische Geografie',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 20),
          Text('Anzahl Fragen',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _CountSelector(
            selected: genState.count,
            onChanged: notifier.setCount,
          ),
          const SizedBox(height: 20),
          Text('Tags (optional)',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ref.watch(predictionsStreamProvider).maybeWhen(
            data: (predictions) {
              final tags = <String>{};
              for (final p in predictions) {
                tags.addAll(p.tagList);
              }
              final sorted = tags.toList()..sort();
              if (sorted.isEmpty) return const SizedBox.shrink();
              return Wrap(
                spacing: 8,
                runSpacing: 4,
                children: sorted
                    .map((tag) => FilterChip(
                          label: Text(tag),
                          selected: _selectedTags.contains(tag),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            });
                            _syncTagsToNotifier();
                          },
                        ))
                    .toList(),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: 'Neuen Tag eingeben',
              hintText: 'z.B. history, science',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _syncTagsToNotifier(),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generieren'),
              onPressed: (!_hasApiKey ||
                          genState.selectedTemplate == null ||
                          genState.selectedModel == null)
                  ? null
                  : () => notifier.generate(_topicController.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoKeyCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(Icons.key_off,
            color: Theme.of(context).colorScheme.onErrorContainer),
        title: Text(
          'Kein API-Key hinterlegt',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer),
        ),
        subtitle: Text(
          'Bitte in den Einstellungen einen OpenRouter-Key eintragen.',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer),
        ),
        trailing: TextButton(
          onPressed: () async {
            await context.push('/settings');
            _checkApiKey();
          },
          child: const Text('Einstellungen'),
        ),
      ),
    );
  }

  Widget _buildPreview(
    BuildContext context,
    WidgetRef ref,
    AiGeneratorState genState,
  ) {
    final file = genState.result!;
    final notifier = ref.read(aiGeneratorProvider.notifier);

    // Initialize: all questions selected
    _selectedQuestionIndices ??=
        Set.from(Iterable.generate(file.questions.length));
    final selected = _selectedQuestionIndices!;

    final now = DateTime.now();
    final pastCount = file.questions
        .where((q) => q.deadline != null && q.deadline!.isBefore(now))
        .length;
    final importCount = selected.where((i) {
      if (!genState.excludePastDeadlines) return true;
      final q = file.questions[i];
      return q.deadline == null || !q.deadline!.isBefore(now);
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
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
                  _PreviewRow('Kategorie', _categoryLabel(file)),
                  if (file.source != null) _PreviewRow('Quelle', file.source!),
                  _PreviewRow('Fragen', '${file.questions.length}'),
                  _PreviewRow(
                    'Mit Auflösung',
                    '${file.questions.where((q) => q.hasResolution).length}',
                  ),
                  if (genState.generationTokens != null)
                    _PreviewRow('Token', '${genState.generationTokens}'),
                  if (genState.generationCost != null)
                    _PreviewRow(
                      'Kosten',
                      '\$${genState.generationCost!.toStringAsFixed(6)}',
                    ),
                ],
              ),
            ),
          ),
          if (pastCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$pastCount ${pastCount == 1 ? 'Frage hat' : 'Fragen haben'} '
                          'eine Deadline in der Vergangenheit.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: Checkbox(
                          value: genState.excludePastDeadlines,
                          onChanged: (_) => notifier.toggleExcludePast(),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => notifier.toggleExcludePast(),
                        child: Text(
                          'Vergangene Fragen beim Import ausschließen',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Fragen auswählen',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  if (selected.length == file.questions.length) {
                    selected.clear();
                  } else {
                    selected.addAll(
                        Iterable.generate(file.questions.length));
                  }
                }),
                child: Text(
                  selected.length == file.questions.length
                      ? 'Keine'
                      : 'Alle',
                ),
              ),
            ],
          ),
          ...file.questions.asMap().entries.map((entry) {
            final i = entry.key;
            final q = entry.value;
            return CheckboxListTile(
              value: selected.contains(i),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  selected.add(i);
                } else {
                  selected.remove(i);
                }
              }),
              title: Text(q.text,
                  style: Theme.of(context).textTheme.bodyMedium),
              subtitle: q.tags.isNotEmpty
                  ? Text(q.tags.join(', '),
                      style: Theme.of(context).textTheme.bodySmall)
                  : null,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            );
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Neu generieren'),
                  onPressed: () => notifier.reset(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Als Datei teilen'),
                  onPressed: () => _shareAsFile(file),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.upload),
              label: Text('$importCount importieren'),
              onPressed: importCount == 0
                  ? null
                  : () => _doImport(context, ref, file, genState),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareAsFile(ImportFile file) async {
    final questions = file.questions.map((q) {
      final map = <String, dynamic>{
        'text': q.text,
        'category': q.category ?? file.category,
        'tags': q.tags,
        'predictionType': q.predictionType,
        if (q.unit != null) 'unit': q.unit,
        if (q.deadline != null)
          'deadline': q.deadline!.toIso8601String(),
      };
      if (q.hasResolution) {
        map['resolution'] = obfuscateResolution({
          'outcome': q.resolution!.outcome,
          if (q.resolution!.numericOutcome != null)
            'numericOutcome': q.resolution!.numericOutcome,
          if (q.resolution!.notes != null) 'notes': q.resolution!.notes,
        });
      }
      return map;
    }).toList();

    final data = <String, dynamic>{
      'version': 2,
      if (file.source != null) 'source': file.source,
      'exportedAt': DateTime.now().toIso8601String(),
      'questions': questions,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    await Share.shareXFiles(
      [
        XFile.fromData(
          utf8.encode(jsonString),
          name: 'kailibrate_ki_$date.json',
          mimeType: 'application/json',
        ),
      ],
      subject: 'kailibrate-Fragenkatalog',
    );
  }

  Future<void> _doImport(
    BuildContext context,
    WidgetRef ref,
    ImportFile file,
    AiGeneratorState genState,
  ) async {
    final notifier = ref.read(aiGeneratorProvider.notifier);
    final db = ref.read(appDatabaseProvider);

    try {
      final now = DateTime.now();
      final selectedIndices = _selectedQuestionIndices ?? {};

      final existingTexts =
          (await db.getAllQuestions()).map((q) => q.questionText).toSet();

      final questionsToImport = file.questions
          .asMap()
          .entries
          .where((e) => selectedIndices.contains(e.key))
          .where((e) =>
              !genState.excludePastDeadlines ||
              e.value.deadline == null ||
              !e.value.deadline!.isBefore(now))
          .where((e) => !existingTexts.contains(e.value.text))
          .map((e) => e.value)
          .toList();
      final skippedCount = selectedIndices.length - questionsToImport.length;

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
            filename: 'KI-Generator',
            source: drift.Value(file.source),
            questionCount: questionsToImport.length,
          ),
        );
      });

      notifier.setImported(questionsToImport.length);

      if (context.mounted && skippedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$skippedCount ${skippedCount == 1 ? 'Duplikat' : 'Duplikate'} übersprungen',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import fehlgeschlagen: $e')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Template selector widget
// ---------------------------------------------------------------------------

class _TemplateSelector extends ConsumerWidget {
  final PromptTemplate? selectedTemplate;
  final ValueChanged<PromptTemplate> onSelected;
  final VoidCallback onTemplatesChanged;

  const _TemplateSelector({
    required this.selectedTemplate,
    required this.onSelected,
    required this.onTemplatesChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesProvider);

    return templatesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Fehler beim Laden der Vorlagen: $e'),
      data: (templates) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vorlage', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedTemplate?.id,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: templates
                      .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    final t = templates.firstWhere((t) => t.id == id);
                    onSelected(t);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Vorlage bearbeiten',
                onPressed: selectedTemplate == null
                    ? null
                    : () async {
                        final edited = await showDialog<PromptTemplate>(
                          context: context,
                          builder: (_) => TemplateEditorDialog(
                            template: selectedTemplate!,
                          ),
                        );
                        if (edited != null) {
                          await PromptTemplateService.save(edited);
                          onTemplatesChanged();
                          onSelected(edited);
                        }
                      },
              ),
              IconButton.outlined(
                icon: const Icon(Icons.add),
                tooltip: 'Neue Vorlage',
                onPressed: () async {
                  final created = await showDialog<PromptTemplate>(
                    context: context,
                    builder: (_) => TemplateEditorDialog(
                      template: PromptTemplate(
                        id: PromptTemplateService.generateId(),
                        name: '',
                        body: '',
                      ),
                    ),
                  );
                  if (created != null && created.name.isNotEmpty) {
                    await PromptTemplateService.save(created);
                    onTemplatesChanged();
                    onSelected(created);
                  }
                },
              ),
            ],
          ),
          if (selectedTemplate != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Vorlage löschen'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () async {
                  await PromptTemplateService.delete(selectedTemplate!.id);
                  onTemplatesChanged();
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Count selector
// ---------------------------------------------------------------------------

class _CountSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _CountSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 5, label: Text('5')),
        ButtonSegment(value: 10, label: Text('10')),
        ButtonSegment(value: 15, label: Text('15')),
        ButtonSegment(value: 20, label: Text('20')),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// ---------------------------------------------------------------------------
// Template editor dialog (used here and in settings)
// ---------------------------------------------------------------------------

class TemplateEditorDialog extends StatefulWidget {
  final PromptTemplate template;

  const TemplateEditorDialog({super.key, required this.template});

  @override
  State<TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<TemplateEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template.name);
    _bodyController = TextEditingController(text: widget.template.body);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDefault = widget.template.isDefault;

    return AlertDialog(
      title: Text(isDefault ? 'Vorlage ansehen' : 'Vorlage bearbeiten'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              enabled: !isDefault,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              enabled: !isDefault,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Prompt-Text',
                hintText: 'Verwende {topic} und {count} als Platzhalter.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Platzhalter: {topic} = Thema, {count} = Anzahl',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        if (!isDefault)
          FilledButton(
            onPressed: () {
              final updated = widget.template.copyWith(
                name: _nameController.text,
                body: _bodyController.text,
              );
              Navigator.of(context).pop(updated);
            },
            child: const Text('Speichern'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helper widgets
// ---------------------------------------------------------------------------

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
            width: 110,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
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
