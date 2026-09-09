import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/content/content_repository.dart';
import '../../../l10n/app_localizations.dart';
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
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  l10n.formScore,
                  style: const TextStyle(color: FormaColors.textMuted),
                ),
                Text(
                  score == null ? '–' : score.round().toString(),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: score == null
                        ? FormaColors.textMuted
                        : (score >= 85
                              ? FormaColors.success
                              : (score >= 60
                                    ? FormaColors.primary
                                    : FormaColors.warning)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: isHold ? l10n.holdTime : l10n.repCount,
                  value: isHold
                      ? '${(result.totalHoldMs / 1000).round()} ${l10n.seconds}'
                      : '${result.repCount}',
                ),
              ),
              if (!isHold) const SizedBox(width: 12),
              if (!isHold)
                Expanded(
                  child: _Stat(
                    label: l10n.avgTempo,
                    value: tempo == null ? '–' : '${tempo.toStringAsFixed(1)}s',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.topErrors, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (top.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.check_circle,
                  color: FormaColors.success,
                ),
                title: Text(l10n.noErrors),
              ),
            ),
          for (final e in top)
            _ErrorCard(ruleId: e.key, count: e.value, definition: def),
          const SizedBox(height: 32),
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
          const SizedBox(height: 12),
          Text(
            l10n.healthDisclaimer,
            style: const TextStyle(color: FormaColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          Text(label, style: const TextStyle(color: FormaColors.textMuted)),
        ],
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.ruleId,
    required this.count,
    required this.definition,
  });

  final String ruleId;
  final int count;
  final ExerciseDefinition? definition;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rule = definition?.rules.where((r) => r.id == ruleId).firstOrNull;
    final explain = rule?.explain;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: FormaColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ruleId.replaceAll('_', ' '),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  l10n.errorTimes(count),
                  style: const TextStyle(color: FormaColors.textMuted),
                ),
              ],
            ),
            if (explain != null) ...[
              const SizedBox(height: 10),
              Text(
                l10n.whyTitle,
                style: const TextStyle(
                  color: FormaColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(explain.text.text(l10n.localeName)),
              if (explain.sourceId != null) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.sourceLabel(explain.sourceId!),
                  style: const TextStyle(
                    color: FormaColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
