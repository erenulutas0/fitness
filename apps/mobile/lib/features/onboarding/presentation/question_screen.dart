import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../core/profile/user_profile.dart';
import '../../../l10n/app_localizations.dart';
import '../application/onboarding_controller.dart';
import '../onboarding_routes.dart';
import 'onboarding_widgets.dart';

/// The three questions, in order (docs/06 §4.1).
enum OnboardingStep { goal, level, equipment }

/// One answer card's content and what tapping it does.
class _Option {
  const _Option({
    required this.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.choose,
  });

  final String key;
  final String label;
  final IconData icon;
  final bool selected;
  final void Function(OnboardingController controller) choose;
}

/// Onboarding step 2: one question per screen, big option cards, progress
/// dots. Tapping an answer records it and moves on — there is no "next".
class QuestionScreen extends ConsumerWidget {
  const QuestionScreen({required this.step, super.key});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final answers = ref.watch(onboardingControllerProvider);
    final options = _options(l10n, answers);
    return OnboardingScaffold(
      appBar: AppBar(
        leading: const OnboardingBackButton(),
        centerTitle: true,
        title: OnboardingProgressDots(
          current: step.index,
          total: OnboardingStep.values.length,
          semanticsLabel: l10n.onboardingStepOf(
            step.index + 1,
            OnboardingStep.values.length,
          ),
        ),
      ),
      child: ListView(
        children: [
          const SizedBox(height: FormaSpacing.xl),
          Text(
            _question(l10n),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: FormaSpacing.xl),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: FormaSpacing.md),
              child: OnboardingOptionCard(
                key: Key('onboarding_option_${option.key}'),
                label: option.label,
                icon: option.icon,
                selected: option.selected,
                onTap: () {
                  option.choose(
                    ref.read(onboardingControllerProvider.notifier),
                  );
                  unawaited(context.push(_next));
                },
              ),
            ),
        ],
      ),
    );
  }

  String get _next => switch (step) {
    OnboardingStep.goal => OnboardingRoutes.level,
    OnboardingStep.level => OnboardingRoutes.equipment,
    OnboardingStep.equipment => OnboardingRoutes.camera,
  };

  String _question(AppLocalizations l10n) => switch (step) {
    OnboardingStep.goal => l10n.onboardingGoalQuestion,
    OnboardingStep.level => l10n.onboardingLevelQuestion,
    OnboardingStep.equipment => l10n.onboardingEquipmentQuestion,
  };

  List<_Option> _options(AppLocalizations l10n, OnboardingAnswers answers) =>
      switch (step) {
        OnboardingStep.goal => [
          _Option(
            key: TrainingGoal.muscle.name,
            label: l10n.onboardingGoalMuscle,
            icon: LucideIcons.bicepsFlexed,
            selected: answers.goal == TrainingGoal.muscle,
            choose: (c) => c.chooseGoal(TrainingGoal.muscle),
          ),
          _Option(
            key: TrainingGoal.form.name,
            label: l10n.onboardingGoalForm,
            icon: LucideIcons.target,
            selected: answers.goal == TrainingGoal.form,
            choose: (c) => c.chooseGoal(TrainingGoal.form),
          ),
          _Option(
            key: TrainingGoal.health.name,
            label: l10n.onboardingGoalHealth,
            icon: LucideIcons.heartPulse,
            selected: answers.goal == TrainingGoal.health,
            choose: (c) => c.chooseGoal(TrainingGoal.health),
          ),
        ],
        OnboardingStep.level => [
          _Option(
            key: TrainingLevel.newcomer.wire,
            label: l10n.onboardingLevelNew,
            icon: LucideIcons.sprout,
            selected: answers.level == TrainingLevel.newcomer,
            choose: (c) => c.chooseLevel(TrainingLevel.newcomer),
          ),
          _Option(
            key: TrainingLevel.occasional.wire,
            label: l10n.onboardingLevelOccasional,
            icon: LucideIcons.calendarDays,
            selected: answers.level == TrainingLevel.occasional,
            choose: (c) => c.chooseLevel(TrainingLevel.occasional),
          ),
          _Option(
            key: TrainingLevel.regular.wire,
            label: l10n.onboardingLevelRegular,
            icon: LucideIcons.calendarCheck,
            selected: answers.level == TrainingLevel.regular,
            choose: (c) => c.chooseLevel(TrainingLevel.regular),
          ),
        ],
        OnboardingStep.equipment => [
          _Option(
            key: Equipment.none.name,
            label: l10n.onboardingEquipmentNone,
            icon: LucideIcons.circleOff,
            selected: answers.equipment == Equipment.none,
            choose: (c) => c.chooseEquipment(Equipment.none),
          ),
          _Option(
            key: Equipment.dumbbell.name,
            label: l10n.onboardingEquipmentDumbbell,
            icon: LucideIcons.dumbbell,
            selected: answers.equipment == Equipment.dumbbell,
            choose: (c) => c.chooseEquipment(Equipment.dumbbell),
          ),
        ],
      };
}
