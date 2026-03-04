import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Sentinel für nullable copyWith – Datei-intern
const _sentinel = Object();

// --- State ---

class EstimateFormState {
  // probability-Typ
  final double probability;
  // binary-Typ
  final bool? binaryChoice;
  final double confidenceLevel;
  // interval-Typ
  final String lowerBoundText;
  final String upperBoundText;

  const EstimateFormState({
    this.probability = 0.5,
    this.binaryChoice,
    this.confidenceLevel = 0.9,
    this.lowerBoundText = '',
    this.upperBoundText = '',
  });

  EstimateFormState copyWith({
    double? probability,
    Object? binaryChoice = _sentinel,
    double? confidenceLevel,
    String? lowerBoundText,
    String? upperBoundText,
  }) {
    return EstimateFormState(
      probability: probability ?? this.probability,
      binaryChoice:
          binaryChoice == _sentinel ? this.binaryChoice : binaryChoice as bool?,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      lowerBoundText: lowerBoundText ?? this.lowerBoundText,
      upperBoundText: upperBoundText ?? this.upperBoundText,
    );
  }
}

// --- Notifier ---

class EstimateFormNotifier extends StateNotifier<EstimateFormState> {
  EstimateFormNotifier() : super(const EstimateFormState());

  void setProbability(double v) => state = state.copyWith(probability: v);
  void setBinaryChoice(bool? v) =>
      state = state.copyWith(binaryChoice: v ?? _sentinel);
  void setConfidence(double v) => state = state.copyWith(confidenceLevel: v);
  void setLowerBound(String v) => state = state.copyWith(lowerBoundText: v);
  void setUpperBound(String v) => state = state.copyWith(upperBoundText: v);
}

// --- Kanonischer Kalibrierwert ---

/// Berechnet den kanonischen Kalibrierwert aus dem Formzustand.
/// Voraussetzung: [state] ist für [predictionType] gültig.
double computeEstimateProbability(
    EstimateFormState state, String predictionType) {
  if (predictionType == 'binary' || predictionType == 'factual') {
    return state.binaryChoice!
        ? state.confidenceLevel
        : 1.0 - state.confidenceLevel;
  }
  if (predictionType == 'interval') {
    return state.confidenceLevel;
  }
  return state.probability;
}

// --- Binary Input ---

class BinaryEstimateInput extends StatelessWidget {
  final EstimateFormState state;
  final EstimateFormNotifier notifier;

  const BinaryEstimateInput({
    super.key,
    required this.state,
    required this.notifier,
  });

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
              child: ChoiceButton(
                label: 'Ja',
                icon: Icons.check_circle_outline,
                selected: state.binaryChoice == true,
                color: Colors.green,
                onTap: () => notifier.setBinaryChoice(true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ChoiceButton(
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
        ConfidenceSlider(
          value: state.confidenceLevel,
          onChanged: notifier.setConfidence,
          label: 'Wie sicher bist du? (50 % = Raten)',
          min: 0.5,
        ),
      ],
    );
  }
}

// --- Factual Input (Wahr/Falsch – epistemic) ---

class FactualEstimateInput extends StatelessWidget {
  final EstimateFormState state;
  final EstimateFormNotifier notifier;

  const FactualEstimateInput({
    super.key,
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ist die Aussage wahr oder falsch?',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ChoiceButton(
                label: 'Wahr',
                icon: Icons.check_circle_outline,
                selected: state.binaryChoice == true,
                color: Colors.green,
                onTap: () => notifier.setBinaryChoice(true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ChoiceButton(
                label: 'Falsch',
                icon: Icons.cancel_outlined,
                selected: state.binaryChoice == false,
                color: Colors.red,
                onTap: () => notifier.setBinaryChoice(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ConfidenceSlider(
          value: state.confidenceLevel,
          onChanged: notifier.setConfidence,
          label: 'Wie sicher bist du? (50 % = Raten)',
          min: 0.5,
        ),
      ],
    );
  }
}

// --- Choice Button ---

class ChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const ChoiceButton({
    super.key,
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

class IntervalEstimateInput extends StatelessWidget {
  final EstimateFormState state;
  final EstimateFormNotifier notifier;
  final String? unit;

  const IntervalEstimateInput({
    super.key,
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
        ConfidenceSlider(
          value: state.confidenceLevel,
          onChanged: notifier.setConfidence,
          label: 'Konfidenz (Intervall enthält den wahren Wert)',
        ),
      ],
    );
  }
}

// --- Confidence Slider ---

class ConfidenceSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final String label;
  final double min;

  const ConfidenceSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.min = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    final divisions = ((0.99 - min) * 100).round();
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
          value: value.clamp(min, 0.99),
          min: min,
          max: 0.99,
          divisions: divisions,
          label: '${(value * 100).round()} %',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
