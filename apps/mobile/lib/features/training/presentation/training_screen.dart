import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/content/content_repository.dart';
import '../../../core/profile/profile_controller.dart';
import '../../../core/profile/user_profile.dart';
import '../../../l10n/app_localizations.dart';
import 'exercise_chips.dart';

/// Content tag that marks an exercise as needing a dumbbell. Every exercise
/// shipped today is bodyweight, so the equipment filter (docs/06 §7) is a
/// convention on `tags` until content carries an explicit equipment field.
const dumbbellTag = 'dumbbell';

/// Antrenman (docs/06 §3): the exercise list, filtered by what the user has.
class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final content = ref.watch(contentRepositoryProvider);
    final equipment = ref.watch(profileProvider).value?.equipment;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trainingTitle)),
      body: content.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '$e',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: FormaColors.warning),
          ),
        ),
        data: (bundle) {
          final exercises = [
            for (final e in bundle.visible(includeDrafts: true))
              if (equipment != Equipment.none || !e.tags.contains(dumbbellTag))
                e,
          ];
          if (exercises.isEmpty) {
            return EmptyState(
              key: const Key('training_empty'),
              icon: LucideIcons.dumbbell,
              message: l10n.trainingEmpty,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(FormaSpacing.page),
            children: [
              for (final e in exercises)
                Padding(
                  padding: const EdgeInsets.only(bottom: FormaSpacing.md),
                  child: _ExerciseCard(definition: e),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.definition});

  final ExerciseDefinition definition;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return FormaCard(
      key: Key('exercise_${definition.id}'),
      onTap: () => unawaited(context.push(Routes.exercise(definition.id))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.name.text(l10n.localeName),
                  style: text.titleMedium,
                ),
                const SizedBox(height: FormaSpacing.sm),
                Wrap(
                  spacing: FormaSpacing.sm,
                  runSpacing: FormaSpacing.xs,
                  children: [
                    for (final v in definition.cameraViews)
                      CameraViewChip(view: v),
                    if (definition.status == 'draft') const DraftChip(),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: FormaSpacing.sm),
          const Icon(LucideIcons.chevronRight, color: FormaColors.textMuted),
        ],
      ),
    );
  }
}
