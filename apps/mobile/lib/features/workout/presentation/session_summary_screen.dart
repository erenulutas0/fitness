import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/content/content_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../application/session_controller.dart';

/// Session summary (docs/06 §4.5): what the whole workout looked like.
///
/// "Today vs last session" is not here yet — it needs the sets to survive the
/// app being closed, and that storage decision is still open (see TODO).
class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(workoutSessionControllerProvider);
    final content = ref.watch(contentRepositoryProvider).value;
    final def = session.exerciseId == null
        ? null
        : content?.exercise(session.exerciseId!);
    final isHold = def?.countMode == CountMode.hold;
    final score = session.meanScore;
    final errors = session.errorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return PopScope(
      // Going back into the finished session would land on a stale set
      // summary; the session is over, so the only way out is Today.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(context, ref);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.sessionSummaryTitle),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    l10n.sessionMeanScore,
                    style: const TextStyle(color: FormaColors.textMuted),
                  ),
                  Text(
                    score == null ? '–' : score.round().toString(),
                    key: const Key('session_mean_score'),
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
                  if (def != null)
                    Text(
                      def.name.text(l10n.localeName),
                      style: const TextStyle(color: FormaColors.textMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: l10n.sessionSets,
                    value: '${session.sets.length}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Stat(
                    label: isHold ? l10n.holdTime : l10n.sessionTotalReps,
                    value: isHold
                        ? '${(session.totalHoldMs / 1000).round()} ${l10n.seconds}'
                        : '${session.totalReps}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              l10n.sessionSets,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < session.sets.length; i++)
              _SetRow(index: i + 1, result: session.sets[i], isHold: isHold),
            const SizedBox(height: 24),
            Text(l10n.topErrors, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (errors.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.check_circle,
                    color: FormaColors.success,
                  ),
                  title: Text(l10n.noErrors),
                ),
              ),
            for (final e in errors.take(3))
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.warning_amber_rounded,
                    color: FormaColors.warning,
                  ),
                  title: Text(e.key.replaceAll('_', ' ')),
                  trailing: Text(l10n.errorTimes(e.value)),
                ),
              ),
            const SizedBox(height: 32),
            FilledButton(
              key: const Key('session_done'),
              onPressed: () => _leave(context, ref),
              child: Text(l10n.doneForToday),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.healthDisclaimer,
              style: const TextStyle(
                color: FormaColors.textMuted,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _leave(BuildContext context, WidgetRef ref) {
    ref.read(workoutSessionControllerProvider.notifier).reset();
    context.go(Routes.today);
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.index,
    required this.result,
    required this.isHold,
  });

  final int index;
  final SetResult result;
  final bool isHold;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final score = result.formScore;
    final errors = result.errorCounts.keys.toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: FormaColors.surfaceRaised,
          child: Text(
            '$index',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          isHold
              ? '${(result.totalHoldMs / 1000).round()} ${l10n.seconds}'
              : '${result.repCount} ${l10n.reps}',
        ),
        subtitle: errors.isEmpty
            ? Text(l10n.noErrors)
            : Text(errors.map((e) => e.replaceAll('_', ' ')).join(', ')),
        trailing: Text(
          score == null ? '–' : score.round().toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
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
