import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/calibration_math.dart';
import '../../../shared/widgets/calibration_chart.dart';

enum _CategoryFilter { all, epistemic, aleatory }

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final predictionsAsync = ref.watch(predictionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiken'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Gesamt'),
            Tab(text: 'Epistemisch'),
            Tab(text: 'Aleatorisch'),
          ],
        ),
      ),
      body: predictionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (predictions) => TabBarView(
          controller: _tabController,
          children: [
            _StatsView(predictions: predictions, filter: _CategoryFilter.all),
            _StatsView(
                predictions: predictions, filter: _CategoryFilter.epistemic),
            _StatsView(
                predictions: predictions, filter: _CategoryFilter.aleatory),
          ],
        ),
      ),
    );
  }
}

class _StatsView extends StatelessWidget {
  final List<PredictionView> predictions;
  final _CategoryFilter filter;

  const _StatsView({required this.predictions, required this.filter});

  List<PredictionView> get _resolved {
    return predictions.where((p) {
      if (p.status != PredictionStatus.resolved) return false;
      return switch (filter) {
        _CategoryFilter.all => true,
        _CategoryFilter.epistemic => p.question.category == 'epistemic',
        _CategoryFilter.aleatory => p.question.category == 'aleatory',
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;

    if (resolved.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart,
                size: 64,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Noch keine aufgelösten Vorhersagen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Löse einige Vorhersagen auf, um Statistiken zu sehen.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final pairs = resolved
        .map((p) => (
              probability: p.estimate!.probability,
              outcome: p.resolution!.outcome ? 1.0 : 0.0,
            ))
        .toList();

    final stats = CalibrationStats.compute(pairs);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ScoreCard(
          title: 'Brier Score',
          value: stats.brierScore.toStringAsFixed(4),
          subtitle: 'Niedriger = besser (0 = perfekt, 0.25 = Münzwurf)',
          icon: Icons.speed,
        ),
        const SizedBox(height: 8),
        _ScoreCard(
          title: 'Log Loss',
          value: stats.logLoss.toStringAsFixed(4),
          subtitle: 'Bestraft falsche Gewissheit stärker',
          icon: Icons.functions,
        ),
        const SizedBox(height: 8),
        _ScoreCard(
          title: 'Aufgelöste Vorhersagen',
          value: '${stats.totalCount}',
          subtitle: 'Datenpunkte für diese Analyse',
          icon: Icons.data_usage,
        ),
        const SizedBox(height: 24),
        Text(
          'Kalibrierungskurve',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Punkte auf der gestrichelten Linie = perfekt kalibriert',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Card(
          child: CalibrationChart(bins: stats.bins),
        ),
        const SizedBox(height: 16),
        if (stats.bins.isNotEmpty) _BinTable(bins: stats.bins),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _ScoreCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _BinTable extends StatelessWidget {
  final List<CalibrationBin> bins;

  const _BinTable({required this.bins});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bin-Details',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                  children: [
                    _tableHeader(context, 'Geschätzt'),
                    _tableHeader(context, 'Anzahl'),
                    _tableHeader(context, 'Trefferquote'),
                  ],
                ),
                ...bins.map(
                  (bin) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                            '${((bin.binCenter - 0.05) * 100).round()}–${((bin.binCenter + 0.05) * 100).round()} %'),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('${bin.count}'),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                            '${(bin.hitRate * 100).round()} %'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}
