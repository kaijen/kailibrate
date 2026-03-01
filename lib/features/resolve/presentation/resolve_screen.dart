import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';

class ResolveScreen extends ConsumerWidget {
  final int questionId;

  const ResolveScreen({super.key, required this.questionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Auflösen')),
      body: FutureBuilder<_ResolveData>(
        future: _loadData(db),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final data = snapshot.data!;
          return _ResolveBody(data: data, questionId: questionId);
        },
      ),
    );
  }

  Future<_ResolveData> _loadData(AppDatabase db) async {
    final question = await db.getQuestion(questionId);
    final estimate = await db.getEstimateForQuestion(questionId);
    return _ResolveData(question: question, estimate: estimate);
  }
}

class _ResolveData {
  final Question question;
  final Estimate? estimate;
  const _ResolveData({required this.question, this.estimate});
}

class _ResolveBody extends ConsumerStatefulWidget {
  final _ResolveData data;
  final int questionId;

  const _ResolveBody({required this.data, required this.questionId});

  @override
  ConsumerState<_ResolveBody> createState() => _ResolveBodyState();
}

class _ResolveBodyState extends ConsumerState<_ResolveBody> {
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _resolve(bool outcome) async {
    if (_saving) return;
    setState(() => _saving = true);

    final db = ref.read(appDatabaseProvider);
    try {
      await db.insertResolution(
        ResolutionsCompanion.insert(
          questionId: widget.questionId,
          outcome: outcome,
          notes: drift.Value(_notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim()),
        ),
      );
      ref.invalidate(predictionsStreamProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Aufgelöst als: ${outcome ? "Ja" : "Nein"}'),
          ),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.data.question;
    final estimate = widget.data.estimate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.text,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          if (estimate != null) ...[
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.percent),
                title: const Text('Deine Schätzung'),
                trailing: Text(
                  '${(estimate.probability * 100).round()} %',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Was ist eingetreten?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Ja'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  onPressed: _saving ? null : () => _resolve(true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Nein'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  onPressed: _saving ? null : () => _resolve(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notizen (optional)',
              hintText: 'Was hat dich überrascht? Was hast du gelernt?',
              border: OutlineInputBorder(),
            ),
          ),
          if (_saving) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
