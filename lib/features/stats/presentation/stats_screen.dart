import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/calibration_math.dart';
import '../../../shared/widgets/calibration_chart.dart';
import '../../../shared/widgets/score_history_chart.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String? _category;
  final Set<String> _types = {};
  final Set<String> _tags = {};
  bool _filterUntagged = false;

  List<PredictionView> _filter(List<PredictionView> all) {
    return all.where((p) {
      if (p.status != PredictionStatus.resolved) return false;
      if (_category != null && p.question.category != _category) return false;
      if (_types.isNotEmpty &&
          !_types.contains(p.question.predictionType)) {
        return false;
      }
      if (_filterUntagged || _tags.isNotEmpty) {
        final matchesUntagged = _filterUntagged && p.tagList.isEmpty;
        final matchesTag = _tags.isNotEmpty && p.tagList.any(_tags.contains);
        if (!matchesUntagged && !matchesTag) return false;
      }
      return true;
    }).toList();
  }

  Set<String> _availableTags(List<PredictionView> predictions) => {
        for (final p in predictions)
          if (p.status == PredictionStatus.resolved) ...p.tagList,
      };

  bool _hasUntagged(List<PredictionView> predictions) => predictions.any(
        (p) => p.status == PredictionStatus.resolved && p.tagList.isEmpty,
      );

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
          final hasUntagged = _hasUntagged(predictions);
          final filtered = _filter(predictions);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterPanel(
                category: _category,
                selectedTypes: _types,
                selectedTags: _tags,
                availableTags: allTags,
                hasUntagged: hasUntagged,
                filterUntagged: _filterUntagged,
                onCategoryChanged: (c) => setState(() => _category = c),
                onTypeToggled: (t) => setState(() =>
                    _types.contains(t) ? _types.remove(t) : _types.add(t)),
                onTagToggled: (tag) => setState(() =>
                    _tags.contains(tag) ? _tags.remove(tag) : _tags.add(tag)),
                onUntaggedToggled: () =>
                    setState(() => _filterUntagged = !_filterUntagged),
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
  final bool hasUntagged;
  final bool filterUntagged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String> onTypeToggled;
  final ValueChanged<String> onTagToggled;
  final VoidCallback onUntaggedToggled;

  const _FilterPanel({
    required this.category,
    required this.selectedTypes,
    required this.selectedTags,
    required this.availableTags,
    required this.hasUntagged,
    required this.filterUntagged,
    required this.onCategoryChanged,
    required this.onTypeToggled,
    required this.onTagToggled,
    required this.onUntaggedToggled,
  });

  static const _typeLabels = {
    'binary': 'Ja/Nein',
    'factual': 'Wahr/Falsch',
    'interval': 'Intervall',
  };

  @override
  Widget build(BuildContext context) {
    final sortedTags = availableTags.toList()..sort();

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
          // Tag-Filter (multi-select, OR-verknüpft)
          if (hasUntagged || sortedTags.isNotEmpty) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (hasUntagged)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: const Text('Ohne Tag'),
                        avatar: const Icon(Icons.label_off_outlined, size: 16),
                        selected: filterUntagged,
                        onSelected: (_) => onUntaggedToggled(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ...sortedTags.map((tag) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(tag),
                        selected: selectedTags.contains(tag),
                        onSelected: (_) => onTagToggled(tag),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }),
                ],
              ),
            ),
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

    final pairs = predictions.map(_calibrationPair).toList();

    final stats = CalibrationStats.compute(pairs);
    final winkler = WinklerStats.compute(_intervalPairs(predictions));

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
        if (winkler != null) ...[
          const SizedBox(height: 8),
          _ScoreCard(
            title: 'Winkler Score',
            value: winkler.score.toStringAsFixed(2),
            subtitle:
                'Intervalle: ${(winkler.hitRate * 100).round()} % Treffer '
                '(${winkler.hitCount}/${winkler.count}) – niedriger = besser',
            icon: Icons.straighten,
          ),
        ],
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
        Stack(
          children: [
            Card(child: CalibrationChart(bins: stats.bins)),
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _openChartFullscreen(
                  context,
                  'Kalibrierungskurve',
                  CalibrationChart(bins: stats.bins, expand: true),
                ),
                behavior: HitTestBehavior.opaque,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (stats.bins.isNotEmpty) _BinTable(bins: stats.bins),
        _HistorySection(predictions: predictions),
        const SizedBox(height: 16),
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
                            '${(bin.binCenter * 100).round()} %'),
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

// ---------------------------------------------------------------------------
// Verlaufsdiagramme
// ---------------------------------------------------------------------------

class _HistorySection extends StatefulWidget {
  final List<PredictionView> predictions;

  const _HistorySection({required this.predictions});

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  int _window = 0; // 0 = alle Werte

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.predictions]
      ..sort((a, b) =>
          a.resolution!.resolvedAt.compareTo(b.resolution!.resolvedAt));

    final pairs = sorted.map(_calibrationPair).toList();

    var history = CalibrationStats.computeHistory(pairs);

    if (_window > 0 && history.length > _window) {
      history = history.sublist(history.length - _window);
    }

    if (history.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Text('Verlauf',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            _WindowSelector(
              value: _window,
              onChanged: (v) => setState(() => _window = v),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Kumulativer Durchschnitt – gestrichelt: Münzwurf-Niveau',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text('Brier Score',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Stack(
          children: [
            Card(child: ScoreHistoryChart(points: history, isBrier: true)),
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _openChartFullscreen(
                  context,
                  'Brier Score – Verlauf',
                  ScoreHistoryChart(points: history, isBrier: true, expand: true),
                ),
                behavior: HitTestBehavior.opaque,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Log Loss',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Stack(
          children: [
            Card(child: ScoreHistoryChart(points: history, isBrier: false)),
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _openChartFullscreen(
                  context,
                  'Log Loss – Verlauf',
                  ScoreHistoryChart(points: history, isBrier: false, expand: true),
                ),
                behavior: HitTestBehavior.opaque,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

void _openChartFullscreen(
    BuildContext context, String title, Widget chart) {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierDismissible: true,
    builder: (_) => _FullscreenChartDialog(title: title, chart: chart),
  ).whenComplete(() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  });
}

class _FullscreenChartDialog extends StatelessWidget {
  final String title;
  final Widget chart;

  const _FullscreenChartDialog({required this.title, required this.chart});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(child: chart),
          ],
        ),
      ),
    );
  }
}

class _WindowSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _WindowSelector({required this.value, required this.onChanged});

  static const _options = [25, 50, 100, 0];
  static const _labels = ['25', '50', '100', 'Alle'];

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: List.generate(
        _options.length,
        (i) => ButtonSegment(
          value: _options[i],
          label: Text(_labels[i]),
        ),
      ),
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
      style: const ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

List<({double lower, double upper, double alpha, double actual})>
    _intervalPairs(List<PredictionView> predictions) {
  final result = <({double lower, double upper, double alpha, double actual})>[];
  for (final p in predictions) {
    if (p.question.predictionType != 'interval') continue;
    final estimate = p.estimate;
    final resolution = p.resolution;
    if (estimate == null || resolution == null) continue;
    if (estimate.lowerBound == null || estimate.upperBound == null) continue;
    if (resolution.numericOutcome == null) continue;
    result.add((
      lower: estimate.lowerBound!,
      upper: estimate.upperBound!,
      alpha: estimate.confidenceLevel,
      actual: resolution.numericOutcome!,
    ));
  }
  return result;
}

/// Builds a calibration pair (probability, outcome) for a resolved prediction.
///
/// For binary/factual types the internal `probability` field always represents
/// P(Wahr/Ja), which maps a "99 % FALSCH" estimate to 0.01. That makes the
/// calibration curve unintuitive: the user appears in the 1 % bin even though
/// they were 99 % confident and correct.
///
/// Instead we use `confidenceLevel` as the probability and express the outcome
/// as whether the user's stated direction was correct. This answers the
/// natural question: "When I am X % confident, how often am I right?"
///
/// For interval predictions the standard formulation is kept: the stored
/// probability (= confidenceLevel) vs. whether the actual value fell within
/// the stated range.
({double probability, double outcome}) _calibrationPair(PredictionView p) {
  final type = p.question.predictionType;
  final estimate = p.estimate!;
  final resolution = p.resolution!;

  if (type == 'binary' || type == 'factual') {
    final wasRight = estimate.binaryChoice == resolution.outcome ? 1.0 : 0.0;
    return (probability: estimate.confidenceLevel, outcome: wasRight);
  }

  // interval and legacy types: keep original semantics
  return (
    probability: estimate.probability,
    outcome: resolution.outcome ? 1.0 : 0.0,
  );
}
