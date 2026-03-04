import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/format_utils.dart';

class PredictionDetailScreen extends ConsumerWidget {
  final int questionId;

  const PredictionDetailScreen({super.key, required this.questionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: FutureBuilder<PredictionView?>(
        future: _load(db),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final prediction = snapshot.data;
          if (prediction == null) {
            return const Center(child: Text('Vorhersage nicht gefunden'));
          }
          return _DetailBody(prediction: prediction);
        },
      ),
    );
  }

  Future<PredictionView?> _load(AppDatabase db) async {
    final views = await db.getAllPredictionViews();
    return views.where((v) => v.question.id == questionId).firstOrNull;
  }
}

class _DetailBody extends StatelessWidget {
  final PredictionView prediction;

  const _DetailBody({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final q = prediction.question;
    final estimate = prediction.estimate;
    final resolution = prediction.resolution;
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Frage
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.questionText,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _Chip(
                      label: q.category == 'epistemic'
                          ? 'Epistemisch'
                          : 'Aleatorisch',
                      color: Theme.of(context).colorScheme.primaryContainer,
                      textColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    ...prediction.tagList.map(
                      (t) => _Chip(label: t),
                    ),
                  ],
                ),
                if (q.source != null) ...[
                  const SizedBox(height: 8),
                  Text('Quelle: ${q.source}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                if (q.deadline != null) ...[
                  const SizedBox(height: 4),
                  Text('Deadline: ${dateFormat.format(q.deadline!)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Schätzung
        if (estimate != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Schätzung',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    _estimateLabel(prediction),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Erfasst: ${dateFormat.format(estimate.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Auflösung
        if (resolution != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Auflösung',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final isBinaryCorrect =
                        (q.predictionType == 'binary' ||
                            q.predictionType == 'factual') &&
                            estimate?.binaryChoice == resolution.outcome;
                    final isPositive =
                        (q.predictionType == 'binary' ||
                            q.predictionType == 'factual')
                        ? isBinaryCorrect
                        : resolution.outcome;
                    return Row(
                      children: [
                        Icon(
                          isPositive
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: isPositive ? Colors.green : Colors.red,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          q.predictionType == 'factual'
                              ? (resolution.outcome ? 'Wahr' : 'Falsch')
                              : (resolution.outcome ? 'Ja' : 'Nein'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color:
                                    isPositive ? Colors.green : Colors.red,
                              ),
                        ),
                      ],
                    );
                  }),
                  if (resolution.numericOutcome != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Messwert: ${formatNum(resolution.numericOutcome)}${(estimate?.unit?.isNotEmpty ?? false) ? ' ${estimate!.unit}' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (resolution.notes != null &&
                      resolution.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Notizen',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(resolution.notes!,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Aufgelöst: ${dateFormat.format(resolution.resolvedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _estimateLabel(PredictionView prediction) {
  final estimate = prediction.estimate!;
  final type = prediction.question.predictionType;
  return switch (type) {
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
}

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;

  const _Chip({required this.label, this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor ?? cs.onSurfaceVariant,
            ),
      ),
    );
  }
}
