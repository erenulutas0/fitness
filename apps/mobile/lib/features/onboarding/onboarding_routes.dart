import 'package:go_router/go_router.dart';

import 'presentation/camera_permission_screen.dart';
import 'presentation/question_screen.dart';
import 'presentation/welcome_screen.dart';

/// Onboarding locations (docs/06 §4.1). The router's redirect treats every
/// path under [welcome] as "already onboarding".
abstract final class OnboardingRoutes {
  static const welcome = '/onboarding';
  static const goal = '/onboarding/goal';
  static const level = '/onboarding/level';
  static const equipment = '/onboarding/equipment';
  static const camera = '/onboarding/camera';
}

/// Onboarding routes (docs/06 §4.1). The router spreads this list.
///
/// Flat, not nested: the screens `push` each other, so the system back button
/// returns to the previous question with its answer still selected.
final List<RouteBase> onboardingRoutes = <RouteBase>[
  GoRoute(
    path: OnboardingRoutes.welcome,
    builder: (_, _) => const WelcomeScreen(),
  ),
  GoRoute(
    path: OnboardingRoutes.goal,
    builder: (_, _) => const QuestionScreen(step: OnboardingStep.goal),
  ),
  GoRoute(
    path: OnboardingRoutes.level,
    builder: (_, _) => const QuestionScreen(step: OnboardingStep.level),
  ),
  GoRoute(
    path: OnboardingRoutes.equipment,
    builder: (_, _) => const QuestionScreen(step: OnboardingStep.equipment),
  ),
  GoRoute(
    path: OnboardingRoutes.camera,
    builder: (_, _) => const CameraPermissionScreen(),
  ),
];
