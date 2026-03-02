import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/calibration_math.dart';
import '../../../shared/widgets/calibration_chart.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String? _category;
  final Set<String> _types = {};
  final Set<String> _tags = {};
  int _autocompleteKey = 0;

  List<PredictionView> _filter(List<PredictionView> all) {
    return all.where((p) {
      if (p.status != PredictionStatus.resolved) return false;
      if (_category != null && p.question.category != _category) return false;
      if (_types.isNotEmpty &&
          !_types.contains(p.question.predictionType)) {
        return false;
      }
      if (_tags.isNotEmpty && !p.tagList.any(_tags.contains)) return false;
      return true;
    }).toList();
  }

  Set<String> _availableTags(List<PredictionView> predictions) => {
        for (final p in predictions)
          if (p.status == PredictionStatus.resolved) ...p.tagList,
      };

  @override
  Widget build(BuildContext context) {
    final predictionsAsync = ref.watch(predictionsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiken')),
      body: predictionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (predictions) {
          final allTags = _availableTags(predictions);
          final filtered = _filter(predictions);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterPanel(
                category: _category,
                selectedTypes: _types,
                selectedTags: _tags,
                availableTags: allTags,
                autocompleteKey: _autocompleteKey,
                onCategoryChanged: (c) => setState(() => _category = c),
                onTypeToggled: (t) => setState(() =>
                    _types.contains(t) ? _types.remove(t) : _types.add(t)),
                onTagAdded: (tag) => setState(() {
                  _tags.add(tag);
                  _autocompleteKey++;
                }),
                onTagRemoved: (tag) => setState(() => _tags.remove(tag)),
              ),
              const Divider(height: 1),
              Expanded(child: _StatsView(predictions: filtered)),
            ],
          );
        },
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  final String? category;
  final Set<String> selectedTypes;
  final Set<String> selectedTags;
  final Set<String> availableTags;
  final int autocompleteKey;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String> onTypeToggled;
  final ValueChanged<String> onTagAdded;
  final ValueChanged<String> onTagRemoved;

  const _FilterPanel({
    required this.category,
    required this.selectedTypes,
    required this.selectedTags,
    required this.availableTags,
    required this.autocompleteKey,
    required this.onCategoryChanged,
    required this.onTypeToggled,
    required this.onTagAdded,
    required this.onTagRemoved,
  });

  static const _typeLabels = {
    'probability': 'Wahrscheinlichkeit',
    'binary': 'Ja/Nein',
    'interval': 'Intervall',
  };

  @override
  Widget build(BuildContext context) {
    final unselectedTags = availableTags.difference(selectedTags);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kategorie-Filter (single-select)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _categoryChip(context, null, 'Alle'),
                const SizedBox(width: 6),
                _categoryChip(context, 'epistemic', 'Epistemisch'),
                const SizedBox(width: 6),
                _categoryChip(context, 'aleatory', 'Aleatorisch'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Typ-Filter (multi-select)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _typeLabels.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(e.value),
                    selected: selectedTypes.contains(e.key),
                    onSelected: (_) => onTypeToggled(e.key),
                  ),
                );
              }).toList(),
            ),
          ),
          // Tag-Filter mit Autocomplete
          if (availableTags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Autocomplete<String>(
              key: ValueKey(autocompleteKey),
              optionsBuilder: (value) {
                if (value.text.isEmpty) return const [];
                return unselectedTags.where((tag) =>
                    tag.toLowerCase().contains(value.text.toLowerCase()));
              },
              fieldViewBuilder: (context, controller, focusNode, _) =>
                  TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  hintText: 'Tag filtern…',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline, size: 18),
                ),
              ),
              onSelected: onTagAdded,
            ),
            if (selectedTags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: selectedTags
                    .map((tag) => InputChip(
                          label: Text(tag),
                          onDeleted: () => onTagRemoved(tag),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _categoryChip(BuildContext context, String? value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: category == value,
      onSelected: (selected) => onCategoryChanged(selected ? value : null),
    );
  }
}

class _StatsView extends StatelessWidget {
  final List<PredictionView> predictions;

  const _StatsView({required this.predictions});

  @override
  Widget build(BuildContext context) {
    if (predictions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Keine aufgelösten Vorhersagen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Passe die Filter an oder löse Vorhersagen auf.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final pairs = predictions
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
        Card(child: CalibrationChart(bins: stats.bins)),
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
                        child:
                            Text('${(bin.hitRate * 100).round()} %'),
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
