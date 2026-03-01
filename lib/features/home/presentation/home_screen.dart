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
        title: const Text('Callibrate'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/new'),
        icon: const Icon(Icons.add),
        label: const Text('Neue Vorhersage'),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, List<PredictionView> predictions) {
    final pending =
        predictions.where((p) => p.status == PredictionStatus.pending).length;
    final needsResolution = predictions
        .where((p) => p.status == PredictionStatus.needsResolution)
        .length;
    final resolved =
        predictions.where((p) => p.status == PredictionStatus.resolved).length;

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
          _buildStatCards(context, pending, needsResolution, resolved, stats),
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
              'Willkommen bei Callibrate',
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

  Widget _buildStatCards(BuildContext context, int pending,
      int needsResolution, int resolved, CalibrationStats? stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _StatCard(
                    label: 'Offen',
                    value: '$pending',
                    color: Colors.orange,
                    icon: Icons.pending)),
            const SizedBox(width: 8),
            Expanded(
                child: _StatCard(
                    label: 'Ausstehend',
                    value: '$needsResolution',
                    color: Colors.blue,
                    icon: Icons.hourglass_empty)),
            const SizedBox(width: 8),
            Expanded(
                child: _StatCard(
                    label: 'Aufgelöst',
                    value: '$resolved',
                    color: Colors.green,
                    icon: Icons.check_circle)),
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
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
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
