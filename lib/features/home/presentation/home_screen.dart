import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/calibration_math.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predictionsAsync = ref.watch(predictionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kailibrate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Statistiken',
            onPressed: () => context.push('/stats'),
          ),
        ],
      ),
      body: predictionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (predictions) => _buildBody(context, predictions),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, List<PredictionView> predictions) {
    final now = DateTime.now();
    bool isOverdue(PredictionView p) =>
        p.question.deadline != null &&
        p.question.deadline!.isBefore(now) &&
        p.status != PredictionStatus.resolved;

    final pending =
        predictions.where((p) => p.status == PredictionStatus.pending).length;
    final needsResolution = predictions
        .where((p) => p.status == PredictionStatus.needsResolution)
        .length;
    final resolved =
        predictions.where((p) => p.status == PredictionStatus.resolved).length;
    final overdueOpen = predictions
        .where((p) => p.status == PredictionStatus.pending && isOverdue(p))
        .length;
    final overdueAwaiting = predictions
        .where((p) =>
            p.status == PredictionStatus.needsResolution && isOverdue(p))
        .length;

    CalibrationStats? stats;
    if (resolved > 0) {
      final pairs = predictions
          .where((p) => p.status == PredictionStatus.resolved)
          .map((p) => (
                probability: p.estimate!.probability,
                outcome: p.resolution!.outcome ? 1.0 : 0.0,
              ))
          .toList();
      stats = CalibrationStats.compute(pairs);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (predictions.isEmpty) _buildEmptyState(context),

        if (predictions.isNotEmpty) ...[
          _buildStatCards(context, pending, needsResolution, resolved,
              overdueOpen, overdueAwaiting, stats),
          const SizedBox(height: 24),
        ],

        _buildNavGrid(context),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.insights,
                size: 64,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Willkommen bei Kailibrate',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Erstelle deine erste Vorhersage oder importiere einen Fragenkatalog.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards(BuildContext context, int pending, int needsResolution,
      int resolved, int overdueOpen, int overdueAwaiting, CalibrationStats? stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _StatCard(
                    label: 'Offen',
                    value: '$pending',
                    color: Colors.orange,
                    icon: Icons.pending,
                    overdue: overdueOpen > 0,
                    onTap: () => context.push('/predictions?filter=pending'))),
            const SizedBox(width: 8),
            Expanded(
                child: _StatCard(
                    label: 'Ausstehend',
                    value: '$needsResolution',
                    color: Colors.blue,
                    icon: Icons.hourglass_empty,
                    overdue: overdueAwaiting > 0,
                    onTap: () => context
                        .push('/predictions?filter=needsResolution'))),
            const SizedBox(width: 8),
            Expanded(
                child: _StatCard(
                    label: 'Aufgelöst',
                    value: '$resolved',
                    color: Colors.green,
                    icon: Icons.check_circle,
                    onTap: () =>
                        context.push('/predictions?filter=resolved'))),
          ],
        ),
        if (stats != null) ...[
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Brier Score'),
              subtitle: const Text('Niedriger = besser kalibriert'),
              trailing: Text(
                stats.brierScore.toStringAsFixed(3),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNavGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _NavCard(
          icon: Icons.list,
          label: 'Alle Vorhersagen',
          onTap: () => context.push('/predictions'),
        ),
        _NavCard(
          icon: Icons.bar_chart,
          label: 'Statistiken',
          onTap: () => context.push('/stats'),
        ),
        _NavCard(
          icon: Icons.upload_file,
          label: 'Importieren',
          onTap: () => context.push('/import'),
        ),
        _NavCard(
          icon: Icons.add_circle_outline,
          label: 'Neue Vorhersage',
          onTap: () => context.push('/new'),
        ),
        _NavCard(
          icon: Icons.settings,
          label: 'Einstellungen',
          onTap: () => context.push('/settings'),
        ),
        _NavCard(
          icon: Icons.auto_awesome,
          label: 'KI-Generator',
          onTap: () => context.push('/ai-generator'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool overdue;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.overdue = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = overdue
        ? Theme.of(context).colorScheme.error
        : null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(overdue ? Icons.warning_amber : icon,
                  color: overdue ? Theme.of(context).colorScheme.error : color),
              const SizedBox(height: 4),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                          fontWeight: FontWeight.bold, color: valueColor)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavCard(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
