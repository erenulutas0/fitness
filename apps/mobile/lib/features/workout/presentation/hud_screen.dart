import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../application/session_controller.dart';
import '../application/workout_controller.dart';
import 'skeleton_painter.dart';

/// The workout HUD (docs/06 §4.3): readable from 2–3 m, one thing at a time.
class HudScreen extends ConsumerStatefulWidget {
  const HudScreen({required this.exerciseId, required this.view, super.key});

  final String exerciseId;
  final CameraView view;

  @override
  ConsumerState<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends ConsumerState<HudScreen> {
  WorkoutControllerProvider get _provider =>
      workoutControllerProvider(widget.exerciseId, widget.view);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Entering the HUD for set 2 or 3 keeps the same session; a different
      // exercise starts a new one rather than averaging squats with push-ups.
      ref
          .read(workoutSessionControllerProvider.notifier)
          .begin(widget.exerciseId, widget.view);
      unawaited(ref.read(_provider.notifier).start());
    });
  }

  Future<void> _finish() async {
    final result = await ref.read(_provider.notifier).finish();
    if (!mounted || result == null) return;
    ref
        .read(workoutSessionControllerProvider.notifier)
        .recordSet(result, pose: ref.read(_provider.notifier).deepestFrame);
    context.pushReplacement(Routes.summary, extra: result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(_provider);
    final session = ref.watch(workoutSessionControllerProvider);
    final def = ref.read(_provider.notifier).definition;
    final snap = state.snapshot;
    final isHold = def?.countMode == CountMode.hold;
    final counterText = isHold
        ? ((snap?.holdMs ?? 0) ~/ 1000).toString()
        : (snap?.repCount ?? 0).toString();
    final tracking = state.tracking;
    final lastScore = snap?.lastRepScore;
    final frame = state.frame;

    return Scaffold(
      backgroundColor: FormaColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera (native) or dark stage for the synthetic engine.
          if (!state.isFakeEngine)
            const PosePreview()
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [FormaColors.surfaceRaised, FormaColors.background],
                ),
              ),
            ),
          if (frame != null)
            CustomPaint(
              painter: SkeletonPainter(
                frame: frame,
                tracking: tracking,
                highlight: state.showHighlight
                    ? (ruleJoints[state.highlightRule] ?? const [])
                    : const [],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  if (kDebugMode && frame != null)
                    _DebugMetrics(
                      frame: frame,
                      snapshot: snap,
                      engine: state.engine,
                    ),
                  _TopStrip(
                    exerciseName: def?.name.text(l10n.localeName) ?? '',
                    setLabel: l10n.setOf(
                      session.currentSetIndex,
                      session.setTotal,
                    ),
                    badge: state.isFakeEngine
                        ? l10n.engineFakeBadge
                        : l10n.privacyBadge,
                    badgeColor: state.isFakeEngine
                        ? FormaColors.secondary
                        : FormaColors.success,
                  ),
                  const Spacer(),
                  if (state.status == HudStatus.starting)
                    Text(
                      l10n.starting,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  if (state.status == HudStatus.error)
                    Text(
                      l10n.engineError(state.errorMessage ?? '?'),
                      style: const TextStyle(color: FormaColors.warning),
                      textAlign: TextAlign.center,
                    ),
                  if (state.isSetup)
                    _SetupPanel(state: state, view: widget.view)
                  else ...[
                    _RepCounter(
                      text: counterText,
                      unit: isHold ? l10n.seconds : l10n.reps,
                      tracking: tracking,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ScoreRing(score: lastScore, label: l10n.form),
                        const SizedBox(width: 28),
                        if (!isHold) _TempoLabel(rep: snap, label: l10n.tempo),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: AnimatedOpacity(
                        opacity: state.showCue ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          state.lastCue?.text ?? '',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: FormaColors.warning,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    if (!tracking && state.status == HudStatus.running)
                      Text(
                        (snap?.bodyInFrame ?? true)
                            ? l10n.cantSeeYou
                            : l10n.outOfFrame,
                        style: const TextStyle(color: FormaColors.textMuted),
                      ),
                  ],
                  const Spacer(),
                  const SizedBox(height: 12),
                  if (state.isSetup)
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            key: const Key('hud_start_now'),
                            onPressed: ref.read(_provider.notifier).startNow,
                            child: Text(l10n.setupStartNow),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('hud_setup_cancel'),
                            onPressed: () => context.go(Routes.today),
                            child: Text(l10n.setupCancel),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            key: const Key('hud_finish'),
                            onPressed: state.status == HudStatus.running
                                ? _finish
                                : null,
                            child: Text(l10n.finish),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('hud_skip'),
                            onPressed: () async {
                              await ref.read(_provider.notifier).finish();
                              if (context.mounted) context.go(Routes.today);
                            },
                            child: Text(l10n.skip),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopStrip extends StatelessWidget {
  const _TopStrip({
    required this.exerciseName,
    required this.setLabel,
    required this.badge,
    required this.badgeColor,
  });

  final String exerciseName;
  final String setLabel;
  final String badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: FormaColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 10, color: badgeColor),
              const SizedBox(width: 6),
              Text(
                badge,
                style: const TextStyle(
                  fontSize: 12,
                  color: FormaColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            exerciseName,
            style: const TextStyle(fontWeight: FontWeight.w700),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Text(setLabel, style: const TextStyle(color: FormaColors.textMuted)),
      ],
    );
  }
}

class _RepCounter extends StatelessWidget {
  const _RepCounter({
    required this.text,
    required this.unit,
    required this.tracking,
  });

  final String text;
  final String unit;
  final bool tracking;

  @override
  Widget build(BuildContext context) {
    final color = tracking ? FormaColors.primary : FormaColors.textMuted;
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: Tween<double>(begin: 1.12, end: 1).animate(anim),
            child: child,
          ),
          child: Text(
            text,
            key: ValueKey(text),
            style: Theme.of(
              context,
            ).textTheme.displayLarge?.copyWith(color: color),
          ),
        ),
        Text(
          unit,
          style: const TextStyle(color: FormaColors.textMuted, fontSize: 18),
        ),
      ],
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.label});

  final double? score;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = score;
    final color = s == null
        ? FormaColors.outline
        : (s >= 85
              ? FormaColors.success
              : (s >= 60 ? FormaColors.primary : FormaColors.warning));
    return Column(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: (s ?? 0) / 100),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (_, v, _) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 7,
                  color: color,
                  backgroundColor: FormaColors.outline,
                ),
              ),
              Center(
                child: Text(
                  s == null ? '–' : s.round().toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: FormaColors.textMuted)),
      ],
    );
  }
}

class _TempoLabel extends StatelessWidget {
  const _TempoLabel({required this.rep, required this.label});

  final SessionSnapshot? rep;
  final String label;

  @override
  Widget build(BuildContext context) {
    final elapsed = rep?.currentRepElapsedMs;
    final text = elapsed == null
        ? '–'
        : '${(elapsed / 1000).toStringAsFixed(1)}s';
    return Column(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: FormaColors.secondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: FormaColors.textMuted)),
      ],
    );
  }
}

/// Debug-only engine readout (fps, latency, tracking confidence). Never shown
/// in release builds; docs/05 §10 budgets are checked against this.
class _DebugMetrics extends StatelessWidget {
  const _DebugMetrics({
    required this.frame,
    required this.snapshot,
    required this.engine,
  });

  final PoseFrame frame;
  final SessionSnapshot? snapshot;
  final String? engine;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    return Align(
      alignment: Alignment.topLeft,
      child: ColoredBox(
        color: Colors.black54,
        child: Text(
          '$engine ${frame.width}x${frame.height} | '
          'fps ${frame.fps?.toStringAsFixed(1) ?? '-'} | '
          'lat ${frame.inferenceMs?.toStringAsFixed(0) ?? '-'}ms | '
          'vis ${s?.confidence.toStringAsFixed(2) ?? '-'} | '
          'sig ${s?.signalValue?.toStringAsFixed(0) ?? '-'} | '
          '${s?.phase.name ?? '-'}',
          style: const TextStyle(
            fontSize: 10,
            fontFamily: 'monospace',
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// The framing step: one clear instruction at a time, big enough to read from
/// two metres away, plus the countdown once the shot is good (docs/06 §4.2).
class _SetupPanel extends StatelessWidget {
  const _SetupPanel({required this.state, required this.view});

  final HudState state;
  final CameraView view;

  String _message(AppLocalizations l10n) {
    final f = state.framing;
    if (f == null) return l10n.framingNoPose;
    if (!f.brightnessOk) return l10n.framingLowLight;
    return switch (f.status) {
      FramingStatus.ok => l10n.framingOk,
      FramingStatus.noPose => l10n.framingNoPose,
      FramingStatus.lowConfidence => l10n.framingLowConfidence,
      FramingStatus.tooClose => l10n.framingTooClose,
      FramingStatus.tooFar => l10n.framingTooFar,
      FramingStatus.moveTowardImageRight => l10n.framingMoveRight,
      FramingStatus.moveTowardImageLeft => l10n.framingMoveLeft,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ready = state.framing?.isReady ?? false;
    final counting = state.status == HudStatus.countdown;
    return Column(
      children: [
        Text(
          l10n.setupTitle,
          style: const TextStyle(color: FormaColors.textMuted, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          view == CameraView.front ? l10n.setupHintFront : l10n.setupHintSide,
          style: const TextStyle(color: FormaColors.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (counting)
          Text(
            '${state.countdownSeconds}',
            key: const Key('hud_countdown'),
            style: Theme.of(
              context,
            ).textTheme.displayLarge?.copyWith(color: FormaColors.secondary),
          )
        else
          Icon(
            ready ? Icons.check_circle : Icons.center_focus_weak,
            size: 72,
            color: ready ? FormaColors.success : FormaColors.warning,
          ),
        const SizedBox(height: 12),
        Text(
          counting ? l10n.setupReady : _message(l10n),
          key: const Key('hud_framing_message'),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: ready ? FormaColors.success : FormaColors.warning,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
