import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import 'prediction_card.dart';

enum _FilterTab { all, pending, needsResolution, resolved }

class PredictionsScreen extends ConsumerStatefulWidget {
  const PredictionsScreen({super.key});

  @override
  ConsumerState<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends ConsumerState<PredictionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: const Text('Vorhersagen'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Alle'),
            Tab(text: 'Offen'),
            Tab(text: 'Ausstehend'),
            Tab(text: 'Aufgelöst'),
          ],
        ),
      ),
      body: predictionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (predictions) => TabBarView(
          controller: _tabController,
          children: [
            _PredictionList(
              predictions: predictions,
              filter: _FilterTab.all,
            ),
            _PredictionList(
              predictions: predictions,
              filter: _FilterTab.pending,
            ),
            _PredictionList(
              predictions: predictions,
              filter: _FilterTab.needsResolution,
            ),
            _PredictionList(
              predictions: predictions,
              filter: _FilterTab.resolved,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/new'),
        tooltip: 'Neue Vorhersage',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PredictionList extends StatelessWidget {
  final List<PredictionView> predictions;
  final _FilterTab filter;

  const _PredictionList({
    required this.predictions,
    required this.filter,
  });

  List<PredictionView> get _filtered {
    return switch (filter) {
      _FilterTab.all => predictions,
      _FilterTab.pending =>
        predictions.where((p) => p.status == PredictionStatus.pending).toList(),
      _FilterTab.needsResolution => predictions
          .where((p) => p.status == PredictionStatus.needsResolution)
          .toList(),
      _FilterTab.resolved => predictions
          .where((p) => p.status == PredictionStatus.resolved)
          .toList(),
    };
  }

  void _handleTap(BuildContext context, PredictionView prediction) {
    switch (prediction.status) {
      case PredictionStatus.pending:
        context.push('/estimate/${prediction.question.id}');
      case PredictionStatus.needsResolution:
        context.push('/resolve/${prediction.question.id}');
      case PredictionStatus.resolved:
        // Show detail or do nothing for resolved
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Keine Vorhersagen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final prediction = items[index];
        return PredictionCard(
          prediction: prediction,
          onTap: () => _handleTap(context, prediction),
        );
      },
    );
  }
}
