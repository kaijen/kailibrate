import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers.dart';
import 'core/services/notification_service.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/predictions/presentation/predictions_screen.dart';
import 'features/estimate/presentation/estimate_screen.dart';
import 'features/resolve/presentation/resolve_screen.dart';
import 'features/stats/presentation/stats_screen.dart';
import 'features/import_data/presentation/import_screen.dart';
import 'features/new_prediction/presentation/new_prediction_screen.dart';
import 'features/predictions/presentation/prediction_detail_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/ai_generator/presentation/ai_generator_screen.dart';
import 'shared/theme/app_theme.dart';

/// Leitet auf die Startseite um, wenn der :id-Pfadparameter kein gültiger
/// Integer ist (z. B. defekter Deep-Link) – statt mit int.parse zu crashen.
String? _redirectInvalidId(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '') == null ? '/' : null;

final _router = GoRouter(
  errorBuilder: (_, state) => Scaffold(
    appBar: AppBar(title: const Text('Seite nicht gefunden')),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Unbekannte Adresse: ${state.uri}'),
          const SizedBox(height: 16),
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Zur Startseite'),
            ),
          ),
        ],
      ),
    ),
  ),
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(
      path: '/predictions',
      builder: (_, state) {
        final filter = switch (state.uri.queryParameters['filter']) {
          'pending' => FilterTab.pending,
          'needsResolution' => FilterTab.needsResolution,
          'resolved' => FilterTab.resolved,
          _ => FilterTab.all,
        };
        return PredictionsScreen(initialFilter: filter);
      },
    ),
    GoRoute(
      path: '/estimate/:id',
      redirect: (_, state) => _redirectInvalidId(state),
      builder: (_, state) =>
          EstimateScreen(questionId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/resolve/:id',
      redirect: (_, state) => _redirectInvalidId(state),
      builder: (_, state) =>
          ResolveScreen(questionId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/prediction/:id',
      redirect: (_, state) => _redirectInvalidId(state),
      builder: (_, state) => PredictionDetailScreen(
          questionId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(path: '/stats', builder: (_, __) => const StatsScreen()),
    GoRoute(path: '/import', builder: (_, __) => const ImportScreen()),
    GoRoute(path: '/new', builder: (_, __) => const NewPredictionScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/ai-generator', builder: (_, __) => const AiGeneratorScreen()),
  ],
);

class KailibrateApp extends ConsumerStatefulWidget {
  const KailibrateApp({super.key});

  @override
  ConsumerState<KailibrateApp> createState() => _KailibrateAppState();
}

class _KailibrateAppState extends ConsumerState<KailibrateApp> {
  @override
  void initState() {
    super.initState();
    _rescheduleNotifications();
    _runConfidenceRoundingMigration();
  }

  Future<void> _runConfidenceRoundingMigration() async {
    // Fire-and-forget aus initState: Fehler loggen statt verschlucken.
    // Das Flag wird erst nach Erfolg gesetzt, beim nächsten Start wird
    // die Migration also erneut versucht.
    try {
      const key = 'confidence_rounding_migration_v1';
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(key) == true) return;
      final db = ref.read(appDatabaseProvider);
      await db.roundAllConfidenceLevels();
      await prefs.setBool(key, true);
    } catch (e, stack) {
      debugPrint('Konfidenz-Rundungsmigration fehlgeschlagen: $e\n$stack');
    }
  }

  Future<void> _rescheduleNotifications() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final predictions = await db.getAllPredictionViews();
      await NotificationService.instance.rescheduleAll(predictions);
    } catch (e, stack) {
      debugPrint('Neuplanung der Erinnerungen fehlgeschlagen: $e\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'kailibrate',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
