import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/content/content_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../today/presentation/today_screen.dart';
import '../../training/presentation/camera_view_sheet.dart';
import '../domain/stored_session.dart';
import '../infrastructure/session_store.dart';

/// Progress (docs/06 §9, docs/01 MVP): the form-score trend and the sessions
/// behind it.
///
/// A trend, not a chart library: the shape of the last dozen sessions is the
/// whole question, and it is one CustomPainter.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(sessionHistoryProvider);
    // The empty screen offers the thing that fills it (docs/06 §7: "İlk
    // seansını yap" + the quick form check button), so a first-time user is
    // not told to go and look for it.
    final quickCheck = ref
        .watch(contentRepositoryProvider)
        .value
        ?.exercise(quickCheckExerciseId);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.progressTitle)),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '$e',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: FormaColors.warning),
          ),
        ),
        data: (all) => all.isEmpty
            ? EmptyState(
                key: const Key('progress_empty'),
                icon: LucideIcons.trendingUp,
                message: l10n.progressEmpty,
                actionLabel: quickCheck == null ? null : l10n.quickFormCheck,
                onAction: quickCheck == null
                    ? null
                    : () => unawaited(startExercise(context, quickCheck)),
              )
            : _Body(sessions: all),
      ),
    );
  }
}

/// Height of the trend plot: tall enough that a 10-point move is visible,
/// short enough that the session list starts above the fold.
const _trendHeight = 140.0;

class _Body extends ConsumerWidget {
  const _Body({required this.sessions});

  final List<StoredSession> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final content = ref.watch(contentRepositoryProvider).value;
    final week = DateTime.now().subtract(const Duration(days: 7));
    final thisWeek = sessions.where((s) => s.startedAt.isAfter(week)).length;
    // The trend reads left to right in time, so the newest-first list is
    // reversed here rather than in the store, which everything else wants
    // newest first.
    final trend = [
      for (final s in sessions.reversed)
        if (s.meanScore != null) s.meanScore!,
    ];

    return ListView(
      padding: const EdgeInsets.all(FormaSpacing.page),
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l10n.sessionsThisWeek,
                value: '$thisWeek',
              ),
            ),
            const SizedBox(width: FormaSpacing.md),
            Expanded(
              child: StatTile(
                // A count, so not the section title below it: "6 · Seans
                // geçmişi" read as a heading with a number stuck to it.
                label: l10n.totalSessions,
                value: '${sessions.length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: FormaSpacing.xl),
        SectionTitle(l10n.scoreTrend),
        if (trend.length < 2)
          FormaCard(
            child: Text(
              l10n.firstSession,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          FormaCard(
            // A line is shape and colour only; TalkBack gets the two numbers
            // that carry the meaning instead (docs/06 §8).
            child: Semantics(
              label: l10n.scoreTrendSemantics(
                ScoreText.format(trend.first),
                ScoreText.format(trend.last),
              ),
              excludeSemantics: true,
              child: SizedBox(
                height: _trendHeight,
                width: double.infinity,
                child: CustomPaint(
                  key: const Key('progress_trend'),
                  painter: _TrendPainter(scores: trend),
                ),
              ),
            ),
          ),
        const SizedBox(height: FormaSpacing.xl),
        SectionTitle(l10n.sessionHistory),
        for (final s in sessions)
          _SessionRow(
            session: s,
            title: [
              for (final id in s.exercises)
                content?.exercise(id)?.name.text(l10n.localeName) ?? id,
            ].join(', '),
          ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.title});

  final StoredSession session;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final score = session.meanScore;
    final date = DateFormat.MMMEd(
      l10n.localeName,
    ).add_Hm().format(session.startedAt.toLocal());
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: FormaSpacing.sm),
      child: FormaCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          title: Text(title),
          subtitle: Text(
            '$date · '
            '${l10n.setsAndReps(session.sets.length, session.totalReps)}',
            style: text.bodySmall,
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

/// The score line over the last sessions, on a fixed 0-100 axis.
///
/// Fixed, not auto-scaled: an axis that rescales makes a two-point wobble look
/// like progress, which is the one thing a progress screen must not do.
class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.scores});

  final List<double> scores;

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2) return;
    final grid = Paint()
      ..color = FormaColors.outline
      ..strokeWidth = 1;
    for (final v in [0.0, 50.0, 100.0]) {
      final y = size.height * (1 - v / 100);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    Offset at(int i) => Offset(
      size.width * i / (scores.length - 1),
      size.height * (1 - scores[i].clamp(0, 100) / 100),
    );

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < scores.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = FormaColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = FormaColors.primary;
    for (var i = 0; i < scores.length; i++) {
      canvas.drawCircle(at(i), i == scores.length - 1 ? 7 : 4, dot);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.scores != scores;
}
