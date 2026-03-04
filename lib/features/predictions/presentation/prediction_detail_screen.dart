import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/services/notification_service.dart';

class PredictionDetailScreen extends ConsumerStatefulWidget {
  final int questionId;

  const PredictionDetailScreen({super.key, required this.questionId});

  @override
  ConsumerState<PredictionDetailScreen> createState() =>
      _PredictionDetailScreenState();
}

class _PredictionDetailScreenState
    extends ConsumerState<PredictionDetailScreen> {
  PredictionView? _prediction;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final db = ref.read(appDatabaseProvider);
    final views = await db.getAllPredictionViews();
    final p = views
        .where((v) => v.question.id == widget.questionId)
        .firstOrNull;
    if (mounted) setState(() { _prediction = p; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final prediction = _prediction;

    Widget? fab;
    if (!_loading && prediction != null) {
      fab = switch (prediction.status) {
        PredictionStatus.pending => FloatingActionButton.extended(
            onPressed: () async {
              await context.push('/estimate/${widget.questionId}');
              _load();
            },
            icon: const Icon(Icons.edit),
            label: const Text('Schätzen'),
          ),
        PredictionStatus.needsResolution => FloatingActionButton.extended(
            onPressed: () async {
              await context.push('/resolve/${widget.questionId}');
              _load();
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Auflösen'),
          ),
        PredictionStatus.resolved => null,
      };
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      floatingActionButton: fab,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : prediction == null
              ? const Center(child: Text('Vorhersage nicht gefunden'))
              : _DetailBody(
                  prediction: prediction,
                  db: db,
                  onReload: _load,
                ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final PredictionView prediction;
  final AppDatabase db;
  final VoidCallback onReload;

  const _DetailBody({
    required this.prediction,
    required this.db,
    required this.onReload,
  });

  bool get _canEditDeadline =>
      prediction.status != PredictionStatus.resolved;

  Future<void> _editDeadline(BuildContext context) async {
    final q = prediction.question;
    final now = DateTime.now();
    final firstDate = DateTime(2020);
    final lastDate = DateTime(2040);
    final initial = (q.deadline != null &&
            !q.deadline!.isBefore(firstDate) &&
            !q.deadline!.isAfter(lastDate))
        ? q.deadline!
        : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null || !context.mounted) return;
    await db.updateDeadline(q.id, picked);
    if (picked.isAfter(now)) {
      await NotificationService.instance.scheduleDeadlineNotifications(
        q.id,
        q.questionText,
        picked,
      );
    } else {
      await NotificationService.instance.cancelNotificationsForQuestion(q.id);
    }
    onReload();
  }

  Future<void> _clearDeadline() async {
    final q = prediction.question;
    await db.updateDeadline(q.id, null);
    await NotificationService.instance.cancelNotificationsForQuestion(q.id);
    onReload();
  }

  @override
  Widget build(BuildContext context) {
    final q = prediction.question;
    final estimate = prediction.estimate;
    final resolution = prediction.resolution;
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final deadlineFmt = DateFormat('dd.MM.yyyy');

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
                const SizedBox(height: 4),
                _DeadlineRow(
                  deadline: q.deadline,
                  canEdit: _canEditDeadline,
                  dateFormat: deadlineFmt,
                  onEdit: () => _editDeadline(context),
                  onClear: _clearDeadline,
                ),
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

        // Auflösung – nur nach eigener Schätzung zeigen
        if (resolution != null && estimate == null)
          Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline,
                  color: Colors.grey.shade500),
              title: Text(
                'Lösung vorhanden',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
              ),
              subtitle: Text(
                'Erst schätzen, dann wird die Auflösung sichtbar.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),

        if (resolution != null && estimate != null)
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
                            estimate.binaryChoice == resolution.outcome;
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
                      'Messwert: ${formatNum(resolution.numericOutcome)}${(estimate.unit?.isNotEmpty ?? false) ? ' ${estimate.unit}' : ''}',
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

class _DeadlineRow extends StatelessWidget {
  final DateTime? deadline;
  final bool canEdit;
  final DateFormat dateFormat;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  const _DeadlineRow({
    required this.deadline,
    required this.canEdit,
    required this.dateFormat,
    required this.onEdit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (!canEdit && deadline == null) return const SizedBox.shrink();

    final textStyle = Theme.of(context).textTheme.bodySmall;
    final iconColor = textStyle?.color;

    return Row(
      children: [
        Icon(Icons.event, size: 16, color: iconColor),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            deadline != null
                ? 'Deadline: ${dateFormat.format(deadline!)}'
                : 'Keine Deadline',
            style: textStyle,
          ),
        ),
        if (canEdit) ...[
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.edit_calendar, size: 16, color: iconColor),
            ),
          ),
          if (deadline != null)
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.clear, size: 16, color: iconColor),
              ),
            ),
        ],
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
