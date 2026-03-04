import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/format_utils.dart';

class PredictionCard extends StatelessWidget {
  final PredictionView prediction;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// null  = kein Auswahlmodus
  /// false = nicht ausgewählt
  /// true  = ausgewählt
  final bool? selected;

  const PredictionCard({
    super.key,
    required this.prediction,
    this.onTap,
    this.onLongPress,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = prediction.question;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: selected == true
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selected != null) ...[
                    Checkbox(
                      value: selected,
                      onChanged: null,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      q.questionText,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: prediction.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CategoryBadge(category: q.category, cs: cs),
                  const SizedBox(width: 8),
                  ...prediction.tagList.take(3).map(
                        (tag) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Chip(
                            label: Text(tag,
                                style: Theme.of(context).textTheme.bodySmall),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                ],
              ),
              if (prediction.estimate == null &&
                  prediction.resolution != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.lock_outline,
                        size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Lösung vorhanden',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                    ),
                  ],
                ),
              ],
              if (prediction.estimate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.percent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Schätzung: ${_estimateLabel(prediction)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (prediction.resolution != null) ...[
                      const SizedBox(width: 16),
                      Builder(builder: (context) {
                        final res = prediction.resolution!;
                        final type = prediction.question.predictionType;
                        final isBinaryCorrect =
                            (type == 'binary' || type == 'factual') &&
                                prediction.estimate?.binaryChoice == res.outcome;
                        final isPositive = (type == 'binary' || type == 'factual')
                            ? isBinaryCorrect
                            : res.outcome;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 16,
                              color:
                                  isPositive ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              () {
                                if (type == 'interval' &&
                                    res.numericOutcome != null) {
                                  final unit =
                                      prediction.estimate?.unit ?? '';
                                  final u =
                                      unit.isNotEmpty ? ' $unit' : '';
                                  return '${formatNum(res.numericOutcome)}$u';
                                }
                                if (type == 'factual') {
                                  return res.outcome ? 'Wahr' : 'Falsch';
                                }
                                return res.outcome ? 'Ja' : 'Nein';
                              }(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: isPositive
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
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

class _StatusBadge extends StatelessWidget {
  final PredictionStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PredictionStatus.pending => ('Offen', Colors.orange),
      PredictionStatus.needsResolution => ('Ausstehend', Colors.blue),
      PredictionStatus.resolved => ('Aufgelöst', Colors.green),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  final ColorScheme cs;

  const _CategoryBadge({required this.category, required this.cs});

  @override
  Widget build(BuildContext context) {
    final label = category == 'epistemic' ? 'Epistemisch' : 'Aleatorisch';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onPrimaryContainer,
            ),
      ),
    );
  }
}
