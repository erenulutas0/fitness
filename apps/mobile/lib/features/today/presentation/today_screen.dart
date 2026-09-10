import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/content/content_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../history/domain/stored_session.dart';
import '../../history/infrastructure/session_store.dart';
import '../../training/application/rule_label.dart';
import '../../training/presentation/camera_view_sheet.dart';
import '../../workout/infrastructure/pose_engine_provider.dart';

/// The exercise behind "Hızlı form check" (docs/06 §3: one exercise, the one
/// the whole MVP is built around).
const quickCheckExerciseId = 'bw_squat';

/// Bugün (docs/06 §3, brief 2-C): the quick form check, and one sentence
/// about the last session. Today's programme session arrives with programs
/// (v0.3); until then the screen does not promise one.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final content = ref.watch(contentRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          // Run the workout on the synthetic engine, so the screens after
          // "a rep was counted" can be reached without doing squats at the
          // phone. Debug only, like the recorder next to it.
          if (kDebugMode)
            IconButton(
              key: const Key('today_demo_mode'),
              tooltip: 'Demo motoru (sentetik tekrarlar)',
              icon: Icon(
                LucideIcons.bot,
                color: ref.watch(demoModeProvider)
                    ? FormaColors.secondary
                    : null,
              ),
              onPressed: () => ref
                  .read(demoModeProvider.notifier)
                  .set(on: !ref.read(demoModeProvider)),
            ),
          // Founder-only fixture recorder; compiled out of release builds.
          if (kDebugMode)
            IconButton(
              key: const Key('today_recorder'),
              tooltip: 'Kayıt (fixture)',
              icon: const Icon(LucideIcons.circleDot),
              onPressed: () => unawaited(context.push(Routes.recorder)),
            ),
        ],
      ),
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
        data: (bundle) => ListView(
          padding: const EdgeInsets.all(FormaSpacing.page),
          children: [
            _Hero(
              onQuickCheck: () => unawaited(
                startExercise(context, bundle.exercise(quickCheckExerciseId)!),
              ),
            ),
            const SizedBox(height: FormaSpacing.xxl),
            SectionTitle(l10n.lastSession),
            _LastSession(bundle: bundle),
          ],
        ),
      ),
    );
  }
}

/// The hero card: the one lime button on the screen (brief §1). Radius 24
/// like a sheet, because it is the screen's headline, not a list row.
class _Hero extends StatelessWidget {
  const _Hero({required this.onQuickCheck});

  final VoidCallback onQuickCheck;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return FormaCard(
      raised: true,
      cornerRadius: FormaRadius.sheet,
      padding: const EdgeInsets.all(FormaSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.todayTitle, style: text.headlineMedium),
          const SizedBox(height: FormaSpacing.xs),
          Text(l10n.todaySubtitle, style: text.bodyMedium),
          const SizedBox(height: FormaSpacing.xl),
          FilledButton.icon(
            key: const Key('today_quick_check'),
            onPressed: onQuickCheck,
            icon: const Icon(LucideIcons.video),
            label: Text(l10n.quickFormCheck),
          ),
        ],
      ),
    );
  }
}

/// "Geçen seansta en sık: Dizlerini dışa aç" — the one finding from the last
/// session (docs/06 §3 "haftanın bulgusu", brief §2: concrete, not a count).
/// Empty state (docs/06 §7) points at the hero button above rather than
/// adding a second lime button.
class _LastSession extends ConsumerWidget {
  const _LastSession({required this.bundle});

  final ContentBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(sessionHistoryProvider);
    final sessions = history.value;
    if (sessions == null) return const SizedBox.shrink();
    if (sessions.isEmpty) {
      return EmptyState(
        key: const Key('today_empty'),
        icon: LucideIcons.activity,
        message: l10n.todayEmpty,
      );
    }
    final last = sessions.first;
    return _LastSessionCard(bundle: bundle, session: last);
  }
}

class _LastSessionCard extends StatelessWidget {
  const _LastSessionCard({required this.bundle, required this.session});

  final ContentBundle bundle;
  final StoredSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final errors = session.errorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = errors.firstOrNull;
    final exerciseId = session.exercises.firstOrNull ?? quickCheckExerciseId;
    final sentence = top == null
        ? l10n.lastSessionClean
        : l10n.lastSessionTopError(
            ruleLabel(
              bundle,
              exerciseId: exerciseId,
              ruleId: top.key,
              locale: l10n.localeName,
            ),
          );
    final date = DateFormat.MMMEd(
      l10n.localeName,
    ).format(session.startedAt.toLocal());
    final score = session.meanScore;
    return FormaCard(
      key: const Key('today_last_session'),
      onTap: () => context.go(Routes.progress),
      child: Row(
        children: [
          ScoreRing(
            score: score,
            semanticsLabel: '${l10n.formScore} ${ScoreText.format(score)}',
          ),
          const SizedBox(width: FormaSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sentence, style: text.bodyLarge),
                const SizedBox(height: FormaSpacing.xs),
                Text(
                  '$date · '
                  '${l10n.setsAndReps(session.sets.length, session.totalReps)}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
