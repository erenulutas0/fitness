import 'package:flutter/foundation.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/profile/profile_controller.dart';
import '../features/history/presentation/progress_screen.dart';
import '../features/legal/presentation/legal_screen.dart';
import '../features/onboarding/onboarding_routes.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/recorder/application/recorder_controller.dart';
import '../features/recorder/presentation/recorder_capture_screen.dart';
import '../features/recorder/presentation/recorder_label_screen.dart';
import '../features/recorder/presentation/recorder_setup_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/today/presentation/today_screen.dart';
import '../features/training/presentation/exercise_detail_screen.dart';
import '../features/training/presentation/training_screen.dart';
import '../features/workout/presentation/hud_screen.dart';
import '../features/workout/presentation/session_summary_screen.dart';
import '../features/workout/presentation/set_summary_screen.dart';
import 'shell.dart';

part 'router.g.dart';

abstract final class Routes {
  // Tabs (inside the shell).
  static const today = '/';
  static const training = '/training';
  static const progress = '/progress';
  static const profile = '/profile';

  // Full-screen routes (outside the shell).
  static const onboarding = '/onboarding';
  static const settings = '/settings';
  static const legal = '/legal';
  static String exercise(String id) => '/exercise/$id';

  /// The workout HUD. [targetReps] asks the HUD to finish the set by itself
  /// after that many reps (the onboarding demo: five squats); it travels as
  /// the `reps` query parameter, which `HudScreen` reads from `GoRouterState`.
  static String hud(String exerciseId, CameraView view, {int? targetReps}) =>
      '/workout/$exerciseId/${view.name}'
      '${targetReps == null ? '' : '?reps=$targetReps'}';
  static const summary = '/summary';
  static const sessionSummary = '/session-summary';

  /// Fixture recorder (debug builds only).
  static const recorder = '/recorder';
  static const recorderCapture = '/recorder/capture';
  static const recorderLabel = '/recorder/label';
}

/// Where the router sends a request for [location]: onboarding until there is
/// a profile, nowhere otherwise. Pure so the rule can be tested without a
/// widget tree.
String? profileRedirect({required bool hasProfile, required String location}) {
  if (hasProfile || location.startsWith(Routes.onboarding)) return null;
  return Routes.onboarding;
}

/// Re-evaluates the redirect when the profile appears or disappears, so
/// "Verilerimi sil" lands on onboarding without every caller having to know.
class _ProfileRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

@riverpod
GoRouter router(Ref ref) {
  final refresh = _ProfileRefresh();
  ref
    ..listen(hasProfileProvider, (_, _) => refresh.refresh())
    ..onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: Routes.today,
    refreshListenable: refresh,
    redirect: (_, state) async {
      final hasProfile = await ref.read(hasProfileProvider.future);
      return profileRedirect(
        hasProfile: hasProfile,
        location: state.uri.path,
      );
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => FormaShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.today,
                builder: (_, _) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.training,
                builder: (_, _) => const TrainingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.progress,
                builder: (_, _) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      ...onboardingRoutes,
      GoRoute(
        path: '/exercise/:id',
        builder: (_, state) =>
            ExerciseDetailScreen(exerciseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(path: Routes.legal, builder: (_, _) => const LegalScreen()),
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
      // The recorder ships only in debug builds: it writes joint coordinates
      // to disk and is a founder tool, not a user feature (docs/10 Prompt 3).
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
}
