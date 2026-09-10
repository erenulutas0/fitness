import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/content/content_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../application/rule_label.dart';
import 'camera_view_sheet.dart';
import 'exercise_chips.dart';

/// Exercise detail (docs/06 §9): what it is, how to film it, what the coach
/// watches for, and one button to start.
///
/// Muscles are not shown: `primaryMuscles` are FMA ids and there is no
/// readable-name mapping until the anatomy layer (v0.2). Raw ids would be
/// noise, so the section stays hidden rather than half-done.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final content = ref.watch(contentRepositoryProvider);
    return content.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            '$e',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: FormaColors.warning),
          ),
        ),
      ),
      data: (bundle) {
        final def = bundle.exercise(exerciseId);
        if (def == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: LucideIcons.circleHelp,
              message: l10n.exerciseNotFound,
            ),
          );
        }
        return _Detail(bundle: bundle, definition: def);
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.bundle, required this.definition});

  final ContentBundle bundle;
  final ExerciseDefinition definition;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final def = definition;
    final description = def.description?.text(l10n.localeName);
    final multiView = def.cameraViews.length > 1;
    return Scaffold(
      appBar: AppBar(title: Text(def.name.text(l10n.localeName))),
      body: ListView(
        padding: const EdgeInsets.all(FormaSpacing.page),
        children: [
          if (def.status == 'draft') ...[
            const Align(alignment: Alignment.centerLeft, child: DraftChip()),
            const SizedBox(height: FormaSpacing.md),
          ],
          if (description != null && description.isNotEmpty) ...[
            Text(
              description,
              key: const Key('detail_description'),
              style: text.bodyLarge,
            ),
            const SizedBox(height: FormaSpacing.xl),
          ],
          SectionTitle(l10n.chooseView),
          Wrap(
            spacing: FormaSpacing.sm,
            runSpacing: FormaSpacing.xs,
            children: [
              for (final v in def.cameraViews) CameraViewChip(view: v),
            ],
          ),
          const SizedBox(height: FormaSpacing.xl),
          SectionTitle(l10n.detectedErrors),
          for (final v in def.cameraViews) ...[
            if (multiView)
              Padding(
                padding: const EdgeInsets.only(
                  top: FormaSpacing.sm,
                  bottom: FormaSpacing.sm,
                ),
                child: Text(
                  cameraViewLabel(l10n, v),
                  style: text.labelMedium,
                ),
              ),
            ..._rulesFor(context, v),
          ],
          // Room for the button below without covering the last card.
          const SizedBox(height: FormaSpacing.xxl),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          FormaSpacing.page,
          FormaSpacing.sm,
          FormaSpacing.page,
          FormaSpacing.page,
        ),
        child: FilledButton.icon(
          key: const Key('detail_start'),
          onPressed: () => unawaited(startExercise(context, def)),
          icon: const Icon(LucideIcons.video),
          label: Text(l10n.start),
        ),
      ),
    );
  }

  List<Widget> _rulesFor(BuildContext context, CameraView view) {
    final l10n = AppLocalizations.of(context);
    final rules = definition.rulesFor(view).toList();
    if (rules.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: FormaSpacing.md),
          child: Text(
            l10n.noRulesForView,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ];
    }
    return [
      for (final r in rules)
        Padding(
          padding: const EdgeInsets.only(bottom: FormaSpacing.md),
          child: _RuleCard(
            key: Key('rule_${view.name}_${r.id}'),
            title:
                ruleText(bundle, r, locale: l10n.localeName) ??
                r.id.replaceAll('_', ' '),
            explain: r.explain?.text.text(l10n.localeName),
          ),
        ),
    ];
  }
}

/// One thing the coach watches for: the cue it will say, and why.
class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.title, this.explain, super.key});

  final String title;
  final String? explain;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return FormaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.triangleAlert, color: FormaColors.warning),
              const SizedBox(width: FormaSpacing.sm),
              Expanded(child: Text(title, style: text.titleSmall)),
            ],
          ),
          if (explain != null && explain!.isNotEmpty) ...[
            const SizedBox(height: FormaSpacing.sm),
            Text(explain!, style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}
