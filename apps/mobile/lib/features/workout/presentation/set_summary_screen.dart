import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/content/content_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../training/application/rule_label.dart';
import '../application/session_controller.dart';
import 'rest_timer.dart';

/// Set summary (docs/06 §4.4): score, reps, top errors + "why" card, then the
/// rest timer that leads into the next set.
class SetSummaryScreen extends ConsumerWidget {
  const SetSummaryScreen({required this.result, super.key});

  static const restSeconds = 60;

  final SetResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final session = ref.watch(workoutSessionControllerProvider);
    final content = ref.watch(contentRepositoryProvider).value;
    final def = content?.exercise(result.exerciseId);
    final score = result.formScore;
    final errors = result.errorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = errors.take(2).toList();
    final isHold = def?.countMode == CountMode.hold;
    final tempo = result.reps.isEmpty
        ? null
        : result.reps
                  .map((r) => r.tempoDownMs + r.tempoUpMs)
                  .reduce((a, b) => a + b) /
              result.reps.length /
              1000;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.setSummaryTitle)),
      body: ListView(
        padding: const EdgeInsets.all(FormaSpacing.page),
        children: [
          Center(
            child: Column(
              children: [
                Text(l10n.formScore, style: text.labelMedium),
                ScoreText(
                  score: score,
                  semanticsLabel: score == null
                      ? l10n.formScoreNoneSemantics
                      : l10n.formScoreSemantics(ScoreText.format(score)),
                ),
              ],
            ),
          ),
          const SizedBox(height: FormaSpacing.lg),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: isHold ? l10n.holdTime : l10n.repCount,
                  value: isHold
                      ? '${(result.totalHoldMs / 1000).round()} ${l10n.seconds}'
                      : '${result.repCount}',
                ),
              ),
              if (!isHold) const SizedBox(width: FormaSpacing.md),
              if (!isHold)
                Expanded(
                  child: StatTile(
                    label: l10n.avgTempo,
                    value: tempo == null ? '–' : '${tempo.toStringAsFixed(1)}s',
                  ),
                ),
            ],
          ),
          const SizedBox(height: FormaSpacing.xl),
          SectionTitle(l10n.topErrors),
          if (top.isEmpty)
            FormaCard(
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.circleCheck,
                    color: FormaColors.success,
                  ),
                  const SizedBox(width: FormaSpacing.md),
                  Expanded(child: Text(l10n.noErrors, style: text.bodyLarge)),
                ],
              ),
            ),
          for (final e in top)
            Padding(
              padding: const EdgeInsets.only(bottom: FormaSpacing.md),
              child: _ErrorCard(
                ruleId: e.key,
                count: e.value,
                definition: def,
                bundle: content,
              ),
            ),
          const SizedBox(height: FormaSpacing.md),
          if (session.isActive && !session.isComplete)
            RestTimer(
              seconds: restSeconds,
              onDone: () => context.pushReplacement(
                Routes.hud(session.exerciseId!, session.view),
              ),
              onSkip: () => context.pushReplacement(Routes.sessionSummary),
            )
          else
            FilledButton(
              key: const Key('summary_end_session'),
              onPressed: () => session.isActive
                  ? context.pushReplacement(Routes.sessionSummary)
                  : context.go(Routes.today),
              child: Text(
                session.isActive ? l10n.sessionSummaryTitle : l10n.backToToday,
              ),
            ),
          const SizedBox(height: FormaSpacing.md),
          Text(
            l10n.healthDisclaimer,
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// One thing that went wrong in the set: what the coach said, how often, and
/// why it says it.
///
/// The heading is the cue itself ("Dizlerini dışa aç"), not the rule id: the
/// exercise detail and Today already read that way, and `knee_valgus` is a
/// debug identifier, not Turkish.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.ruleId,
    required this.count,
    required this.definition,
    required this.bundle,
  });

  final String ruleId;
  final int count;
  final ExerciseDefinition? definition;
  final ContentBundle? bundle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final rule = definition?.rules.where((r) => r.id == ruleId).firstOrNull;
    final explain = rule?.explain;
    // No source catalogue yet (content/sources/ holds only a README), so
    // there is nothing to resolve an id against.
    const String? sourceName = null;
    final title = bundle == null
        ? ruleId.replaceAll('_', ' ')
        : ruleLabel(
            bundle!,
            exerciseId: definition?.id ?? '',
            ruleId: ruleId,
            locale: l10n.localeName,
          );
    return FormaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.triangleAlert, color: FormaColors.warning),
              const SizedBox(width: FormaSpacing.sm),
              Expanded(child: Text(title, style: text.titleSmall)),
              const SizedBox(width: FormaSpacing.sm),
              Text(l10n.errorTimes(count), style: text.labelMedium),
            ],
          ),
          if (explain != null) ...[
            const SizedBox(height: FormaSpacing.md),
            Text(
              l10n.whyTitle,
              style: text.labelMedium?.copyWith(color: FormaColors.secondary),
            ),
            const SizedBox(height: FormaSpacing.xs),
            Text(explain.text.text(l10n.localeName), style: text.bodyMedium),
            // The source line stays hidden until content/sources/ exists:
            // explain.sourceId is a placeholder like "src_valgus_01", and
            // printing it would put a debug identifier in the one place the
            // product is meant to be showing its evidence (docs/06 §4.6).
            if (explain.sourceId != null && sourceName != null) ...[
              const SizedBox(height: FormaSpacing.sm),
              Text(l10n.sourceLabel(sourceName), style: text.labelSmall),
            ],
          ],
        ],
      ),
    );
  }
}
