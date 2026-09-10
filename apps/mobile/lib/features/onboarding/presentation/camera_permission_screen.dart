import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../workout/application/session_controller.dart';
import '../../workout/infrastructure/pose_engine_provider.dart';
import '../application/onboarding_controller.dart';
import 'onboarding_widgets.dart';

/// Where the demo session lives: the HUD, told to stop itself after
/// [demoTargetReps] reps (`?reps=N` is the phase-2 contract with the HUD).
String demoSessionLocation() => Uri(
  path: Routes.hud(demoExerciseId, CameraView.side),
  queryParameters: {'reps': '$demoTargetReps'},
).toString();

/// Onboarding step 3 (docs/06 §4.1): why the camera, then the permission
/// request, then straight into the five-squat demo.
///
/// Denied: the reason, "try again", and "continue without camera", which
/// still saves the profile. No deep link to system settings — that would
/// need a native dependency (brief §0).
class CameraPermissionScreen extends ConsumerStatefulWidget {
  const CameraPermissionScreen({super.key});

  @override
  ConsumerState<CameraPermissionScreen> createState() =>
      _CameraPermissionScreenState();
}

class _CameraPermissionScreenState
    extends ConsumerState<CameraPermissionScreen> {
  var _denied = false;
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return OnboardingScaffold(
      appBar: AppBar(leading: const OnboardingBackButton()),
      actions: [
        FilledButton.icon(
          key: Key(_denied ? 'onboarding_retry' : 'onboarding_open_camera'),
          onPressed: _busy ? null : () => unawaited(_request()),
          icon: const Icon(LucideIcons.camera),
          label: Text(
            _denied ? l10n.onboardingRetry : l10n.onboardingOpenCamera,
          ),
        ),
        if (_denied)
          OutlinedButton(
            key: const Key('onboarding_without_camera'),
            onPressed: _busy ? null : () => unawaited(_finish(demo: false)),
            child: Text(l10n.onboardingContinueWithoutCamera),
          ),
      ],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.camera, color: FormaColors.textMuted),
          const SizedBox(height: FormaSpacing.lg),
          Text(l10n.onboardingCameraTitle, style: text.headlineMedium),
          const SizedBox(height: FormaSpacing.md),
          Text(l10n.onboardingCameraWhy, style: text.bodyLarge),
          const SizedBox(height: FormaSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: PrivacyBadge(label: l10n.privacyBadge),
          ),
          const SizedBox(height: FormaSpacing.xl),
          if (_denied)
            FormaCard(
              key: const Key('onboarding_camera_denied'),
              child: Row(
                children: [
                  const Icon(LucideIcons.cameraOff, color: FormaColors.warning),
                  const SizedBox(width: FormaSpacing.md),
                  Expanded(child: Text(l10n.onboardingCameraDenied)),
                ],
              ),
            )
          else
            Text(l10n.onboardingDemoHint, style: text.bodyMedium),
        ],
      ),
    );
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    bool granted;
    try {
      granted = await ref.read(poseEngineProvider).requestCameraPermission();
    } on Object {
      // No plugin on this platform reads the same as "no camera": the user
      // can still continue without one.
      granted = false;
    }
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _denied = true;
        _busy = false;
      });
      return;
    }
    await _finish(demo: true);
  }

  /// Profile first, so the router lets the user back to Today after the demo
  /// (docs/06 §4.1); then a fresh one-set session and the HUD.
  Future<void> _finish({required bool demo}) async {
    setState(() => _busy = true);
    await ref.read(onboardingControllerProvider.notifier).complete();
    if (demo) {
      ref.read(workoutSessionControllerProvider.notifier)
        ..reset()
        ..begin(demoExerciseId, CameraView.side)
        ..setTotal(1);
    }
    if (!mounted) return;
    context.go(demo ? demoSessionLocation() : Routes.today);
  }
}
