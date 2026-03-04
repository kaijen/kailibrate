import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/calibration_math.dart';
import '../../../core/utils/format_utils.dart';
import '../../../shared/widgets/feedback_sheet.dart';

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
  final _numericController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    _numericController.dispose();
    super.dispose();
  }

  Future<void> _resolve(bool outcome, {double? numericOutcome}) async {
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
          numericOutcome: drift.Value(numericOutcome),
        ),
      );
      ref.invalidate(predictionsStreamProvider);
      if (mounted) {
        await _showFeedback(outcome);
        if (mounted) context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showFeedback(bool outcome) async {
    final db = ref.read(appDatabaseProvider);
    final allViews = await db.getAllPredictionViews();
    if (!mounted) return;

    final resolved = allViews
        .where((v) => v.status == PredictionStatus.resolved)
        .toList();
    final type = widget.data.question.predictionType;

    List<({double probability, double outcome})> toPairs(
            List<PredictionView> views) =>
        views
            .map((v) => (
                  probability: v.estimate!.probability,
                  outcome: v.resolution!.outcome ? 1.0 : 0.0,
                ))
            .toList();

    final overallStats = CalibrationStats.compute(toPairs(resolved));
    final typeResolved = resolved
        .where((v) => v.question.predictionType == type)
        .toList();
    final typeStats = CalibrationStats.compute(toPairs(typeResolved));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CalibrationFeedbackSheet(
        outcome: outcome,
        estimate: widget.data.estimate,
        predictionType: type,
        overallStats: overallStats,
        typeStats: typeStats,
      ),
    );
  }

  Future<void> _resolveInterval() async {
    final raw = _numericController.text.trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gib einen gültigen Zahlenwert ein.')),
      );
      return;
    }

    final estimate = widget.data.estimate;
    final lower = estimate?.lowerBound;
    final upper = estimate?.upperBound;
    final outcome =
        (lower != null && upper != null) ? (value >= lower && value <= upper) : false;

    await _resolve(outcome, numericOutcome: value);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.data.question;
    final estimate = widget.data.estimate;
    final type = q.predictionType;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.questionText,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          if (estimate != null) ...[
            _EstimateCard(estimate: estimate, type: type),
            const SizedBox(height: 24),
          ],
          if (q.hasKnownAnswer && q.knownAnswer != null) ...[
            _KnownAnswerCard(knownAnswer: q.knownAnswer!, type: type),
            const SizedBox(height: 24),
          ],
          if (type == 'interval') ...[
            _IntervalResolveInput(
              controller: _numericController,
              estimate: estimate,
              saving: _saving,
              onResolve: _resolveInterval,
            ),
          ] else ...[
            Text(
              type == 'factual' ? 'Was ist der Fakt?' : 'Was ist eingetreten?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(type == 'factual' ? 'Wahr' : 'Ja'),
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
                    label: Text(type == 'factual' ? 'Falsch' : 'Nein'),
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
          ],
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

class _EstimateCard extends StatelessWidget {
  final Estimate estimate;
  final String type;

  const _EstimateCard({required this.estimate, required this.type});

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      'binary' => estimate.binaryChoice == true
          ? 'JA – ${(estimate.confidenceLevel * 100).round()} %'
          : 'NEIN – ${(estimate.confidenceLevel * 100).round()} %',
      'factual' => estimate.binaryChoice == true
          ? 'WAHR – ${(estimate.confidenceLevel * 100).round()} %'
          : 'FALSCH – ${(estimate.confidenceLevel * 100).round()} %',
      'interval' => () {
          final lower = estimate.lowerBound;
          final upper = estimate.upperBound;
          final unit = estimate.unit ?? '';
          final unitStr = unit.isNotEmpty ? ' $unit' : '';
          return '[${formatNum(lower)} – ${formatNum(upper)}$unitStr] @ ${(estimate.confidenceLevel * 100).round()} %';
        }(),
      _ => '${(estimate.probability * 100).round()} %',
    };

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.percent),
        title: const Text('Deine Schätzung'),
        trailing: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _KnownAnswerCard extends StatelessWidget {
  final bool knownAnswer;
  final String type;

  const _KnownAnswerCard({required this.knownAnswer, required this.type});

  @override
  Widget build(BuildContext context) {
    final isYes = knownAnswer;
    final label = type == 'factual'
        ? (isYes ? 'Wahr' : 'Falsch')
        : (isYes ? 'Ja' : 'Nein');

    return Card(
      color: isYes ? Colors.green.shade50 : Colors.red.shade50,
      child: ListTile(
        leading: Icon(
          isYes ? Icons.check_circle : Icons.cancel,
          color: isYes ? Colors.green.shade700 : Colors.red.shade700,
        ),
        title: const Text('Bekannte Antwort'),
        trailing: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isYes ? Colors.green.shade700 : Colors.red.shade700,
              ),
        ),
      ),
    );
  }
}

class _IntervalResolveInput extends StatelessWidget {
  final TextEditingController controller;
  final Estimate? estimate;
  final bool saving;
  final VoidCallback onResolve;

  const _IntervalResolveInput({
    required this.controller,
    required this.estimate,
    required this.saving,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final lower = estimate?.lowerBound;
    final upper = estimate?.upperBound;
    final unit = estimate?.unit ?? '';
    final unitStr = unit.isNotEmpty ? ' $unit' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tatsächlicher Wert$unitStr',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (lower != null && upper != null) ...[
          const SizedBox(height: 4),
          Text(
            'Schätzintervall: ${formatNum(lower)} – ${formatNum(upper)}$unitStr',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
          ],
          decoration: InputDecoration(
            labelText: 'Messwert$unitStr',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Auflösen'),
            onPressed: saving ? null : onResolve,
          ),
        ),
      ],
    );
  }
}

