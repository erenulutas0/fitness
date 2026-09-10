import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/content/content_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../history/domain/stored_session.dart';
import '../../history/infrastructure/session_store.dart';
import '../../training/application/rule_label.dart';
import '../application/session_controller.dart';
import 'share_card.dart';

/// Session summary (docs/06 §4.5): what the whole workout looked like.
///
/// "Today vs last session" is not here yet — it needs the sets to survive the
/// app being closed, and that storage decision is still open (see TODO).
class SessionSummaryScreen extends ConsumerStatefulWidget {
  const SessionSummaryScreen({super.key});

  @override
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  @override
  void initState() {
    super.initState();
    // Save as soon as the summary opens, not when the user leaves it: the
    // session is already over, and a workout that vanishes because the app
    // was killed on this screen is the worst possible moment to lose one.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_persist()));
  }

  Future<void> _persist() async {
    final session = ref.read(workoutSessionControllerProvider);
    if (session.sets.isEmpty || session.startedAt == null) return;
    await ref
        .read(sessionStoreProvider)
        .save(
          StoredSession(
            id: session.id,
            startedAt: session.startedAt!,
            endedAt: DateTime.now(),
            sets: [
              for (final s in session.sets) StoredSet.fromResult(s.result),
            ],
          ),
        );
    if (!mounted) return;
    // History is cached, so without this Today and Progress keep showing the
    // empty state until the app is restarted — someone finishing their first
    // workout would go back and be told to do their first workout.
    ref.invalidate(sessionHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final session = ref.watch(workoutSessionControllerProvider);
    final previous = ref.watch(previousSessionProvider(session.id)).value;
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
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.sessionSummaryTitle),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(FormaSpacing.page),
          children: [
            Center(
              child: Column(
                children: [
                  Text(l10n.sessionMeanScore, style: text.labelMedium),
                  ScoreText(
                    key: const Key('session_mean_score'),
                    score: score,
                    semanticsLabel: score == null
                        ? l10n.formScoreNoneSemantics
                        : l10n.formScoreSemantics(ScoreText.format(score)),
                  ),
                  if (def != null)
                    Text(
                      def.name.text(l10n.localeName),
                      style: text.labelMedium,
                    ),
                  const SizedBox(height: FormaSpacing.sm),
                  _Comparison(score: score, previous: previous),
                ],
              ),
            ),
            const SizedBox(height: FormaSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: l10n.sessionSets,
                    value: '${session.sets.length}',
                  ),
                ),
                const SizedBox(width: FormaSpacing.md),
                Expanded(
                  child: StatTile(
                    label: isHold ? l10n.holdTime : l10n.sessionTotalReps,
                    value: isHold
                        ? '${(session.totalHoldMs / 1000).round()} ${l10n.seconds}'
                        : '${session.totalReps}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: FormaSpacing.xl),
            SectionTitle(l10n.sessionSets),
            for (var i = 0; i < session.sets.length; i++)
              _SetRow(
                index: i + 1,
                result: session.sets[i].result,
                isHold: isHold,
                bundle: content,
                exerciseId: session.exerciseId,
              ),
            const SizedBox(height: FormaSpacing.xl),
            SectionTitle(l10n.topErrors),
            if (errors.isEmpty)
              FormaCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(
                    LucideIcons.circleCheck,
                    color: FormaColors.success,
                  ),
                  title: Text(l10n.noErrors),
                ),
              ),
            for (final e in errors.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: FormaSpacing.sm),
                child: FormaCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(
                      LucideIcons.triangleAlert,
                      color: FormaColors.warning,
                    ),
                    title: Text(
                      _errorLabel(l10n, content, session.exerciseId, e.key),
                    ),
                    trailing: Text(l10n.errorTimes(e.value)),
                  ),
                ),
              ),
            const SizedBox(height: FormaSpacing.xl),
            OutlinedButton.icon(
              key: const Key('session_share'),
              onPressed: session.sets.isEmpty
                  ? null
                  : () => unawaited(
                      _share(l10n, session, def, isHold: isHold),
                    ),
              icon: const Icon(LucideIcons.share),
              label: Text(l10n.shareCard),
            ),
            const SizedBox(height: FormaSpacing.sm),
            FilledButton(
              key: const Key('session_done'),
              onPressed: _leave,
              child: Text(l10n.doneForToday),
            ),
            const SizedBox(height: FormaSpacing.md),
            Text(
              l10n.healthDisclaimer,
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(
    AppLocalizations l10n,
    WorkoutSessionState session,
    ExerciseDefinition? def, {
    required bool isHold,
  }) async {
    final score = session.meanScore;
    final card = ShareCard(
      exerciseName: def?.name.text(l10n.localeName) ?? '',
      score: score,
      statsLine: l10n.shareCardStats(
        session.sets.length,
        isHold
            ? '${(session.totalHoldMs / 1000).round()}'
            : '${session.totalReps}',
        isHold ? l10n.seconds : l10n.reps,
      ),
      pose: session.bestPose,
    );
    try {
      final png = await renderShareCard(card);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/forma-session.png');
      await file.writeAsBytes(png);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: l10n.shareCardBody(
            def?.name.text(l10n.localeName) ?? '',
            score == null ? '–' : score.round().toString(),
          ),
        ),
      );
    } on Object catch (e) {
      debugPrint('[share] $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
    }
  }

  void _leave() {
    ref.read(workoutSessionControllerProvider.notifier).reset();
    context.go(Routes.today);
  }
}

/// What the coach calls a rule where the user reads it — the cue itself, not
/// the `knee_valgus` identifier the engine uses.
String _errorLabel(
  AppLocalizations l10n,
  ContentBundle? bundle,
  String? exerciseId,
  String ruleId,
) {
  if (bundle == null || exerciseId == null) {
    return ruleId.replaceAll('_', ' ');
  }
  return ruleLabel(
    bundle,
    exerciseId: exerciseId,
    ruleId: ruleId,
    locale: l10n.localeName,
  );
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.index,
    required this.result,
    required this.isHold,
    required this.bundle,
    required this.exerciseId,
  });

  final int index;
  final SetResult result;
  final bool isHold;
  final ContentBundle? bundle;
  final String? exerciseId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final score = result.formScore;
    final errors = result.errorCounts.keys.toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: FormaSpacing.sm),
      child: FormaCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: FormaColors.surfaceRaised,
            child: Text('$index', style: text.titleSmall),
          ),
          title: Text(
            isHold
                ? '${(result.totalHoldMs / 1000).round()} ${l10n.seconds}'
                : '${result.repCount} ${l10n.reps}',
          ),
          subtitle: errors.isEmpty
              ? Text(l10n.noErrors)
              : Text(
                  errors
                      .map(
                        (e) => _errorLabel(l10n, bundle, exerciseId, e),
                      )
                      .join(' · '),
                ),
          trailing: ScoreText(
            score: score,
            style: text.titleLarge,
            semanticsLabel: score == null
                ? l10n.formScoreNoneSemantics
                : l10n.formScoreSemantics(ScoreText.format(score)),
          ),
        ),
      ),
    );
  }
}

/// "vs last session +5", or a note that this is the first one. Comparing a
/// score to nothing is worse than saying there is nothing to compare to.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.score, required this.previous});

  final double? score;
  final StoredSession? previous;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final before = previous?.meanScore;
    if (score == null) return const SizedBox.shrink();
    if (previous == null || before == null) {
      return Text(
        l10n.firstSession,
        key: const Key('session_first'),
        textAlign: TextAlign.center,
        style: text.bodySmall,
      );
    }
    final delta = score!.round() - before.round();
    // The sign is in the text, so the colour only reinforces it; a reader who
    // cannot tell green from grey still reads "+5".
    return Text(
      l10n.vsLastSession(delta >= 0 ? '+$delta' : '$delta'),
      key: const Key('session_vs_last'),
      style: text.labelLarge?.copyWith(
        color: delta >= 0 ? FormaColors.success : FormaColors.textMuted,
      ),
    );
  }
}
