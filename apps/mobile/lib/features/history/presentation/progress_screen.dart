import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/content/content_repository.dart';
import '../../../l10n/app_localizations.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.progressTitle)),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: FormaColors.warning)),
        ),
        data: (all) => all.isEmpty
            ? EmptyState(
                key: const Key('progress_empty'),
                message: l10n.progressEmpty,
              )
            : _Body(sessions: all),
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: l10n.sessionsThisWeek,
                value: '$thisWeek',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: l10n.sessionHistory,
                value: '${sessions.length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionTitle(l10n.scoreTrend),
        if (trend.length < 2)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                l10n.firstSession,
                style: const TextStyle(color: FormaColors.textMuted),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: CustomPaint(
                  key: const Key('progress_trend'),
                  painter: _TrendPainter(scores: trend),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          '$date · ${l10n.setsAndReps(session.sets.length, session.totalReps)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: ScoreText(
          score: score,
          style: Theme.of(context).textTheme.titleLarge,
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
