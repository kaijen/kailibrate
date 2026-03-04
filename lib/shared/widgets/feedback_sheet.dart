import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/calibration_math.dart';
import '../../core/utils/format_utils.dart';

class CalibrationFeedbackSheet extends StatelessWidget {
  final bool outcome;
  final Estimate? estimate;
  final String predictionType;
  final CalibrationStats overallStats;
  final CalibrationStats typeStats;
  final Resolution? resolution;

  const CalibrationFeedbackSheet({
    super.key,
    required this.outcome,
    required this.estimate,
    required this.predictionType,
    required this.overallStats,
    required this.typeStats,
    this.resolution,
  });

  static const _typeLabels = {
    'binary': 'Ja/Nein',
    'interval': 'Intervall',
    'probability': 'Wahrscheinlichkeit',
  };

  String _estimateLabel() {
    final e = estimate!;
    return switch (predictionType) {
      'binary' => e.binaryChoice == true
          ? 'JA – ${(e.confidenceLevel * 100).round()} %'
          : 'NEIN – ${(e.confidenceLevel * 100).round()} %',
      'interval' => () {
          final unit = e.unit ?? '';
          final u = unit.isNotEmpty ? ' $unit' : '';
          return '[${formatNum(e.lowerBound)} – '
              '${formatNum(e.upperBound)}$u] '
              '@ ${(e.confidenceLevel * 100).round()} %';
        }(),
      _ => '${(e.probability * 100).round()} %',
    };
  }

  // For binary questions, correctness depends on whether the predicted
  // direction matches the outcome, not just on outcome being true.
  bool _isCorrect() {
    if (predictionType == 'binary' && estimate != null) {
      return estimate!.binaryChoice == outcome;
    }
    return outcome;
  }

  double _brierContribution() {
    final p = estimate!.probability;
    final o = outcome ? 1.0 : 0.0;
    return pow(p - o, 2).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final isCorrect = _isCorrect();
    final outcomeColor = isCorrect ? Colors.green : Colors.red;
    final typeLabel = _typeLabels[predictionType] ?? predictionType;
    final showTypeSection = typeStats.totalCount < overallStats.totalCount;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ergebnis-Banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: outcomeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: outcomeColor,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        predictionType == 'binary'
                            ? (isCorrect ? 'Richtig' : 'Falsch')
                            : (outcome ? 'Eingetreten' : 'Nicht eingetreten'),
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: outcomeColor,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      if (predictionType == 'binary')
                        Text(
                          'Antwort: ${outcome ? 'Ja' : 'Nein'}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: outcomeColor,
                                  ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Diese Schätzung
            if (estimate != null) ...[
              FeedbackSectionCard(
                title: 'Diese Schätzung',
                children: [
                  FeedbackStatRow('Geschätzt', _estimateLabel()),
                  FeedbackStatRow(
                    'Brier-Beitrag',
                    _brierContribution().toStringAsFixed(4),
                    hint: '0 = perfekt · 1 = maximal falsch',
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Auflösungsdetails (Notizen, Messwert)
            if (resolution != null &&
                (resolution!.notes != null ||
                    resolution!.numericOutcome != null)) ...[
              const SizedBox(height: 8),
              FeedbackSectionCard(
                title: 'Auflösung',
                children: [
                  if (resolution!.numericOutcome != null)
                    FeedbackStatRow(
                      'Messwert',
                      () {
                        final unit = estimate?.unit ?? '';
                        final u = unit.isNotEmpty ? ' $unit' : '';
                        return '${formatNum(resolution!.numericOutcome)}$u';
                      }(),
                    ),
                  if (resolution!.notes != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        resolution!.notes!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ],

            // Gesamtkalibrierung
            FeedbackSectionCard(
              title: 'Gesamtkalibrierung (${overallStats.totalCount} aufgelöst)',
              children: [
                FeedbackStatRow(
                    'Brier Score', overallStats.brierScore.toStringAsFixed(4)),
                FeedbackStatRow(
                    'Log Loss', overallStats.logLoss.toStringAsFixed(4)),
              ],
            ),

            // Typ-spezifische Kalibrierung
            if (showTypeSection) ...[
              const SizedBox(height: 8),
              FeedbackSectionCard(
                title: 'Typ: $typeLabel (${typeStats.totalCount} aufgelöst)',
                children: [
                  FeedbackStatRow(
                      'Brier Score', typeStats.brierScore.toStringAsFixed(4)),
                  FeedbackStatRow(
                      'Log Loss', typeStats.logLoss.toStringAsFixed(4)),
                ],
              ),
            ],

            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Weiter'),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedbackSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const FeedbackSectionCard(
      {super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class FeedbackStatRow extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;

  const FeedbackStatRow(this.label, this.value, {super.key, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                if (hint != null)
                  Text(hint!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          )),
              ],
            ),
          ),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
