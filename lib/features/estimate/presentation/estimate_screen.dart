import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/probability_slider.dart';

// StateNotifier for the slider value
class _SliderNotifier extends StateNotifier<double> {
  _SliderNotifier() : super(0.5);

  void update(double value) => state = value;
}

final _sliderProvider =
    StateNotifierProvider.autoDispose<_SliderNotifier, double>(
        (_) => _SliderNotifier());

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

class _EstimateBody extends ConsumerWidget {
  final Question question;

  const _EstimateBody({required this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final probability = ref.watch(_sliderProvider);
    final db = ref.watch(appDatabaseProvider);

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
            question.text,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 32),
          const Text(
            'Wie wahrscheinlich ist "Ja"?',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          ProbabilitySlider(
            value: probability,
            onChanged: (v) =>
                ref.read(_sliderProvider.notifier).update(v),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Schätzung speichern'),
              onPressed: () async {
                await db.upsertEstimate(
                  EstimatesCompanion.insert(
                    questionId: question.id,
                    probability: probability,
                  ),
                );
                ref.invalidate(predictionsStreamProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Schätzung gespeichert.')),
                  );
                  context.pop();
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(category: question.category),
        ],
      ),
    );
  }
}

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
