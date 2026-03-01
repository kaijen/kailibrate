import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';

class NewPredictionScreen extends ConsumerStatefulWidget {
  const NewPredictionScreen({super.key});

  @override
  ConsumerState<NewPredictionScreen> createState() =>
      _NewPredictionScreenState();
}

class _NewPredictionScreenState extends ConsumerState<NewPredictionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _tagsController = TextEditingController();

  String _category = 'epistemic';
  DateTime? _deadline;
  bool _saving = false;

  @override
  void dispose() {
    _textController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<String> get _parsedTags {
    final raw = _tagsController.text.trim();
    if (raw.isEmpty) return [];
    return raw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    setState(() => _saving = true);

    final db = ref.read(appDatabaseProvider);
    final tags = _parsedTags;

    try {
      await db.insertQuestion(
        QuestionsCompanion.insert(
          text: _textController.text.trim(),
          category: _category,
          tags: drift.Value(jsonEncode(tags)),
          deadline: drift.Value(_deadline),
        ),
      );
      ref.invalidate(predictionsStreamProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vorhersage erstellt.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neue Vorhersage')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Beschreibe deine Vorhersage',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _textController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Frage / Vorhersage',
                hintText:
                    'z.B. „Werde ich diese Woche mehr als 10.000 Schritte gehen?"',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Bitte gib eine Frage ein.';
                }
                if (v.trim().length < 5) {
                  return 'Die Frage ist zu kurz.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Kategorie',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'epistemic',
                  label: Text('Epistemisch'),
                  icon: Icon(Icons.book_outlined),
                ),
                ButtonSegment(
                  value: 'aleatory',
                  label: Text('Aleatorisch'),
                  icon: Icon(Icons.casino_outlined),
                ),
              ],
              selected: {_category},
              onSelectionChanged: (s) =>
                  setState(() => _category = s.first),
            ),
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _category == 'epistemic'
                      ? 'Epistemisch: Die Antwort steht fest, du kennst sie nur nicht – z.B. geografische Fakten oder historische Ereignisse.'
                      : 'Aleatorisch: Das Ergebnis ist genuinen Zufalls – z.B. Wetterereignisse oder persönliche Gewohnheiten.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tags (optional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'z.B. gesundheit, wetter, technik',
                helperText: 'Mehrere Tags durch Komma trennen',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Auflösungsfrist (optional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _deadline == null
                    ? 'Kein Datum gesetzt'
                    : 'Frist: ${_deadline!.day}.${_deadline!.month}.${_deadline!.year}',
              ),
              onPressed: _pickDeadline,
            ),
            if (_deadline != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Datum entfernen'),
                onPressed: () => setState(() => _deadline = null),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label:
                  Text(_saving ? 'Speichere...' : 'Vorhersage erstellen'),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
