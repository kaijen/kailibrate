import 'package:flutter/material.dart';

class ProbabilitySlider extends StatelessWidget {
  final double value; // 0.0 – 1.0
  final ValueChanged<double> onChanged;

  const ProbabilitySlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Color _colorForProbability(double p, ColorScheme cs) {
    if (p < 0.3) return Colors.red.shade400;
    if (p < 0.5) return Colors.orange.shade400;
    if (p < 0.7) return Colors.yellow.shade700;
    return Colors.green.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final percent = (value * 100).round();

    return Column(
      children: [
        Text(
          '$percent %',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: _colorForProbability(value, cs),
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _colorForProbability(value, cs),
            thumbColor: _colorForProbability(value, cs),
          ),
          child: Slider(
            value: value,
            min: 0.01,
            max: 0.99,
            divisions: 98,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1 %', style: Theme.of(context).textTheme.bodySmall),
            Text('50 %', style: Theme.of(context).textTheme.bodySmall),
            Text('99 %', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}
