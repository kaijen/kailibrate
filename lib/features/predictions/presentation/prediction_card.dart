import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';

class PredictionCard extends StatelessWidget {
  final PredictionView prediction;
  final VoidCallback? onTap;

  const PredictionCard({
    super.key,
    required this.prediction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = prediction.question;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      q.text,
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
              if (prediction.estimate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.percent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Schätzung: ${(prediction.estimate!.probability * 100).round()} %',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (prediction.resolution != null) ...[
                      const SizedBox(width: 16),
                      Icon(
                        prediction.resolution!.outcome
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 16,
                        color: prediction.resolution!.outcome
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        prediction.resolution!.outcome ? 'Ja' : 'Nein',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: prediction.resolution!.outcome
                                  ? Colors.green
                                  : Colors.red,
                            ),
                      ),
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
