import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/probability_slider.dart';

// --- State ---

class _EstimateState {
  // probability-Typ
  final double probability;
  // binary-Typ
  final bool? binaryChoice;
  final double confidenceLevel;
  // interval-Typ
  final String lowerBoundText;
  final String upperBoundText;

  const _EstimateState({
    this.probability = 0.5,
    this.binaryChoice,
    this.confidenceLevel = 0.9,
    this.lowerBoundText = '',
    this.upperBoundText = '',
  });

  _EstimateState copyWith({
    double? probability,
    Object? binaryChoice = _sentinel,
    double? confidenceLevel,
    String? lowerBoundText,
    String? upperBoundText,
  }) {
    return _EstimateState(
      probability: probability ?? this.probability,
      binaryChoice:
          binaryChoice == _sentinel ? this.binaryChoice : binaryChoice as bool?,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      lowerBoundText: lowerBoundText ?? this.lowerBoundText,
      upperBoundText: upperBoundText ?? this.upperBoundText,
    );
  }
}

const _sentinel = Object();

class _EstimateNotifier extends StateNotifier<_EstimateState> {
  _EstimateNotifier() : super(const _EstimateState());

  void setProbability(double v) => state = state.copyWith(probability: v);
  void setBinaryChoice(bool? v) =>
      state = state.copyWith(binaryChoice: v ?? _sentinel);
  void setConfidence(double v) => state = state.copyWith(confidenceLevel: v);
  void setLowerBound(String v) => state = state.copyWith(lowerBoundText: v);
  void setUpperBound(String v) => state = state.copyWith(upperBoundText: v);
}

final _estimateProvider =
    StateNotifierProvider.autoDispose<_EstimateNotifier, _EstimateState>(
        (_) => _EstimateNotifier());

// --- Screen ---

class EstimateScreen extends ConsumerWidget {
  final int questionId;

  const EstimateScreen({super.key, required this.questionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Schätzung abgeben')),
      body: FutureBuilder<Question>(
        future: db.getQuestion(questionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final question = snapshot.data!;
          return _EstimateBody(question: question);
        },
      ),
    );
  }
}

// --- Body ---

class _EstimateBody extends ConsumerWidget {
  final Question question;

  const _EstimateBody({required this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_estimateProvider);
    final notifier = ref.read(_estimateProvider.notifier);
    final db = ref.watch(appDatabaseProvider);
    final type = question.predictionType;

    final categoryLabel =
        question.category == 'epistemic' ? 'Epistemisch' : 'Aleatorisch';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              categoryLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 32),
          if (type == 'probability') ...[
            const Text(
              'Wie wahrscheinlich ist "Ja"?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            ProbabilitySlider(
              value: state.probability,
              onChanged: notifier.setProbability,
            ),
          ] else if (type == 'binary') ...[
            _BinaryInput(state: state, notifier: notifier),
          ] else if (type == 'interval') ...[
            _IntervalInput(
              state: state,
              notifier: notifier,
              unit: question.predictionType == 'interval'
                  ? null // unit stored in estimate, not question
                  : null,
            ),
          ],
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Schätzung speichern'),
              onPressed: () => _save(context, ref, db, type, state),
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(category: question.category),
        ],
      ),
    );
  }

  String? _validate(_EstimateState state, String type) {
    if (type == 'binary' && state.binaryChoice == null) {
      return 'Bitte wähle Ja oder Nein.';
    }
    if (type == 'interval') {
      final lower = double.tryParse(state.lowerBoundText.replaceAll(',', '.'));
      final upper = double.tryParse(state.upperBoundText.replaceAll(',', '.'));
      if (lower == null || upper == null) {
        return 'Bitte gib gültige Zahlen für beide Grenzen ein.';
      }
      if (lower >= upper) {
        return 'Die untere Grenze muss kleiner als die obere sein.';
      }
    }
    return null;
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    AppDatabase db,
    String type,
    _EstimateState state,
  ) async {
    final error = _validate(state, type);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    // Kanonischen probability-Wert berechnen
    double probability;
    drift.Value<double?> lowerBound = const drift.Value(null);
    drift.Value<double?> upperBound = const drift.Value(null);
    drift.Value<bool?> binaryChoice = const drift.Value(null);

    if (type == 'binary') {
      final isYes = state.binaryChoice!;
      probability =
          isYes ? state.confidenceLevel : 1.0 - state.confidenceLevel;
      binaryChoice = drift.Value(isYes);
    } else if (type == 'interval') {
      probability = state.confidenceLevel;
      final lower =
          double.parse(state.lowerBoundText.replaceAll(',', '.'));
      final upper =
          double.parse(state.upperBoundText.replaceAll(',', '.'));
      lowerBound = drift.Value(lower);
      upperBound = drift.Value(upper);
    } else {
      probability = state.probability;
    }

    await db.upsertEstimate(
      EstimatesCompanion.insert(
        questionId: question.id,
        probability: probability,
        confidenceLevel: drift.Value(state.confidenceLevel),
        lowerBound: lowerBound,
        upperBound: upperBound,
        binaryChoice: binaryChoice,
      ),
    );
    ref.invalidate(predictionsStreamProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schätzung gespeichert.')),
      );
      context.pop();
    }
  }
}

// --- Binary Input ---

class _BinaryInput extends StatelessWidget {
  final _EstimateState state;
  final _EstimateNotifier notifier;

  const _BinaryInput({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Was glaubst du – tritt das Ereignis ein?',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ChoiceButton(
                label: 'Ja',
                icon: Icons.check_circle_outline,
                selected: state.binaryChoice == true,
                color: Colors.green,
                onTap: () => notifier.setBinaryChoice(true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ChoiceButton(
                label: 'Nein',
                icon: Icons.cancel_outlined,
                selected: state.binaryChoice == false,
                color: Colors.red,
                onTap: () => notifier.setBinaryChoice(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _ConfidenceSlider(
          value: state.confidenceLevel,
          onChanged: notifier.setConfidence,
          label: 'Konfidenz',
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, color: selected ? Colors.white : color),
      label: Text(label, style: TextStyle(color: selected ? Colors.white : null)),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? color : null,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 20),
      ),
      onPressed: onTap,
    );
  }
}

// --- Interval Input ---

class _IntervalInput extends StatelessWidget {
  final _EstimateState state;
  final _EstimateNotifier notifier;
  final String? unit;

  const _IntervalInput({
    required this.state,
    required this.notifier,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final unitSuffix = unit != null && unit!.isNotEmpty ? ' ($unit)' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gib dein Schätzintervall an$unitSuffix',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: state.lowerBoundText,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Untergrenze$unitSuffix',
                  border: const OutlineInputBorder(),
                ),
                onChanged: notifier.setLowerBound,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: state.upperBoundText,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Obergrenze$unitSuffix',
                  border: const OutlineInputBorder(),
                ),
                onChanged: notifier.setUpperBound,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _ConfidenceSlider(
          value: state.confidenceLevel,
          onChanged: notifier.setConfidence,
          label: 'Konfidenz (Intervall enthält den wahren Wert)',
        ),
      ],
    );
  }
}

// --- Confidence Slider ---

class _ConfidenceSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final String label;

  const _ConfidenceSlider({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Text(
              '${(value * 100).round()} %',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0.1,
          max: 0.99,
          divisions: 89,
          label: '${(value * 100).round()} %',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// --- Info Card ---

class _InfoCard extends StatelessWidget {
  final String category;

  const _InfoCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final isEpistemic = category == 'epistemic';
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isEpistemic ? Icons.book_outlined : Icons.casino_outlined,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isEpistemic
                    ? 'Epistemische Fragen haben eine feststehende Antwort – deine Unsicherheit betrifft dein Wissen.'
                    : 'Aleatorische Ereignisse sind zufällig – kein Wissen kann die Unsicherheit vollständig auflösen.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
