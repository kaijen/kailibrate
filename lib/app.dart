import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/predictions/presentation/predictions_screen.dart';
import 'features/estimate/presentation/estimate_screen.dart';
import 'features/resolve/presentation/resolve_screen.dart';
import 'features/stats/presentation/stats_screen.dart';
import 'features/import_data/presentation/import_screen.dart';
import 'features/new_prediction/presentation/new_prediction_screen.dart';
import 'shared/theme/app_theme.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/predictions', builder: (_, __) => const PredictionsScreen()),
    GoRoute(
      path: '/estimate/:id',
      builder: (_, state) =>
          EstimateScreen(questionId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/resolve/:id',
      builder: (_, state) =>
          ResolveScreen(questionId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(path: '/stats', builder: (_, __) => const StatsScreen()),
    GoRoute(path: '/import', builder: (_, __) => const ImportScreen()),
    GoRoute(path: '/new', builder: (_, __) => const NewPredictionScreen()),
  ],
);

class CallibrateApp extends ConsumerWidget {
  const CallibrateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Callibrate',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
