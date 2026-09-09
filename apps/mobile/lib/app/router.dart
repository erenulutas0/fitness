import 'package:flutter/foundation.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/recorder/application/recorder_controller.dart';
import '../features/recorder/presentation/recorder_capture_screen.dart';
import '../features/recorder/presentation/recorder_label_screen.dart';
import '../features/recorder/presentation/recorder_setup_screen.dart';
import '../features/today/presentation/today_screen.dart';
import '../features/workout/presentation/hud_screen.dart';
import '../features/workout/presentation/session_summary_screen.dart';
import '../features/workout/presentation/set_summary_screen.dart';

part 'router.g.dart';

abstract final class Routes {
  static const today = '/';
  static String hud(String exerciseId, CameraView view) =>
      '/workout/$exerciseId/${view.name}';
  static const summary = '/summary';
  static const sessionSummary = '/session-summary';

  /// Fixture recorder (debug builds only).
  static const recorder = '/recorder';
  static const recorderCapture = '/recorder/capture';
  static const recorderLabel = '/recorder/label';
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
    GoRoute(
      path: Routes.sessionSummary,
      builder: (_, _) => const SessionSummaryScreen(),
    ),
    // The recorder ships only in debug builds: it writes joint coordinates to
    // disk and is a founder tool, not a user feature (docs/10 Prompt 3).
    if (kDebugMode) ...[
      GoRoute(
        path: Routes.recorder,
        builder: (_, _) => const RecorderSetupScreen(),
      ),
      GoRoute(
        path: Routes.recorderCapture,
        builder: (_, state) =>
            RecorderCaptureScreen(config: state.extra! as RecordingConfig),
      ),
      GoRoute(
        path: Routes.recorderLabel,
        builder: (_, state) =>
            RecorderLabelScreen(draft: state.extra! as RecordingDraft),
      ),
    ],
  ],
);
