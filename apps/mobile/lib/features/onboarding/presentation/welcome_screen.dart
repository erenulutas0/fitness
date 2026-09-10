import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../application/onboarding_controller.dart';
import '../onboarding_routes.dart';
import 'onboarding_widgets.dart';

/// Onboarding step 1 (docs/06 §4.1): one sentence, "Kamerayı dene".
///
/// "Skip" writes a default profile and goes to Today, so someone who has
/// deleted their data — or just knows the app — is never trapped here.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return OnboardingScaffold(
      actions: [
        FilledButton.icon(
          key: const Key('onboarding_try_camera'),
          onPressed: () => unawaited(context.push(OnboardingRoutes.goal)),
          icon: const Icon(LucideIcons.camera),
          label: Text(l10n.onboardingTryCamera),
        ),
        TextButton(
          key: const Key('onboarding_skip'),
          onPressed: () => unawaited(_skip(context, ref)),
          child: Text(l10n.onboardingSkip),
        ),
      ],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appTitle,
            style: text.titleSmall?.copyWith(color: FormaColors.textMuted),
          ),
          const SizedBox(height: FormaSpacing.lg),
          Text(l10n.onboardingWelcome, style: text.headlineLarge),
        ],
      ),
    );
  }

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    await ref.read(onboardingControllerProvider.notifier).complete();
    if (context.mounted) context.go(Routes.today);
  }
}
