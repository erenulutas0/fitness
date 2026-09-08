import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/today/presentation/today_screen.dart';
import '../features/workout/presentation/hud_screen.dart';
import '../features/workout/presentation/set_summary_screen.dart';

part 'router.g.dart';

abstract final class Routes {
  static const today = '/';
  static String hud(String exerciseId, CameraView view) =>
      '/workout/$exerciseId/${view.name}';
  static const summary = '/summary';
}

@riverpod
GoRouter router(Ref ref) => GoRouter(
  initialLocation: Routes.today,
  routes: [
    GoRoute(path: Routes.today, builder: (_, _) => const TodayScreen()),
    GoRoute(
      path: '/workout/:exerciseId/:view',
      builder: (_, state) => HudScreen(
        exerciseId: state.pathParameters['exerciseId']!,
        view:
            CameraView.parse(state.pathParameters['view'] ?? 'side') ??
            CameraView.side,
      ),
    ),
    GoRoute(
      path: Routes.summary,
      builder: (_, state) =>
          SetSummaryScreen(result: state.extra! as SetResult),
    ),
  ],
);
