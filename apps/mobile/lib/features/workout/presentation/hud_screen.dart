import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../application/session_controller.dart';
import '../application/workout_controller.dart';
import 'skeleton_painter.dart';

/// The rep counter grows to this and back when the count goes up (brief §1
/// "120 ms scale pulse"). Small on purpose: a coach, not a game.
const _pulseScale = 1.08;

/// The framing icon; the same size as the shared score ring so the setup
/// step and the live readout sit on the same grid.
const _setupIconSize = 72.0;

/// The workout HUD (docs/06 §4.3): readable from 2–3 m, one thing at a time.
///
/// `targetReps` (or `?reps=N` on the route) makes the set finish by itself
/// after N reps — the onboarding demo is five squats and out.
class HudScreen extends ConsumerStatefulWidget {
  const HudScreen({
    required this.exerciseId,
    required this.view,
    this.targetReps,
    super.key,
  });

  final String exerciseId;
  final CameraView view;
  final int? targetReps;

  /// Query key on the HUD route: `/workout/:exerciseId/:view?reps=5`.
  static const repsQueryKey = 'reps';

  @override
  ConsumerState<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends ConsumerState<HudScreen> {
  WorkoutControllerProvider get _provider =>
      workoutControllerProvider(widget.exerciseId, widget.view);

  int? _targetReps;
  bool _resolvedTarget = false;

  /// Set once the screen has navigated away, so a late state change cannot
  /// navigate twice.
  bool _left = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Entering the HUD for set 2 or 3 keeps the same session; a different
      // exercise starts a new one rather than averaging squats with push-ups.
      ref
          .read(workoutSessionControllerProvider.notifier)
          .begin(widget.exerciseId, widget.view);
      final target = _targetReps;
      if (target != null) ref.read(_provider.notifier).setTargetReps(target);
      unawaited(ref.read(_provider.notifier).start());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedTarget) return;
    _resolvedTarget = true;
    _targetReps = widget.targetReps ?? _repsFromRoute(context);
  }

  /// The route builder is shared; the query string is read here instead.
  static int? _repsFromRoute(BuildContext context) {
    if (GoRouter.maybeOf(context) == null) return null;
    final raw = GoRouterState.of(
      context,
    ).uri.queryParameters[HudScreen.repsQueryKey];
    return int.tryParse(raw ?? '');
  }

  Future<void> _finish() async {
    final result = await ref.read(_provider.notifier).finish();
    if (!mounted || result == null || _left) return;
    _left = true;
    ref
        .read(workoutSessionControllerProvider.notifier)
        .recordSet(result, pose: ref.read(_provider.notifier).deepestFrame);
    context.pushReplacement(Routes.summary, extra: result);
  }

  Future<void> _skip() async {
    await ref.read(_provider.notifier).finish();
    if (!mounted || _left) return;
    _left = true;
    context.go(Routes.today);
  }

  /// docs/06 §7: the set finished in the background is shown when the app is
  /// back; a set with nothing counted goes back to Today.
  void _leaveAfterBackground(SetResult? result) {
    if (_left) return;
    _left = true;
    final counted =
        result != null && (result.repCount > 0 || result.totalHoldMs > 0);
    if (counted) {
      context.pushReplacement(Routes.summary, extra: result);
    } else {
      context.go(Routes.today);
    }
  }

  void _onStateChange(HudState? prev, HudState next) {
    if (next.exit == HudExit.targetReached &&
        prev?.exit != HudExit.targetReached) {
      unawaited(_finish());
      return;
    }
    if (next.exit != HudExit.backgrounded) return;
    if (prev?.exit != HudExit.backgrounded) {
      // Record right away: the app may never be resumed.
      final result = next.pendingResult;
      if (result != null) {
        ref
            .read(workoutSessionControllerProvider.notifier)
            .recordSet(
              result,
              pose: ref.read(_provider.notifier).deepestFrame,
            );
      }
    }
    if (!next.inBackground) _leaveAfterBackground(next.pendingResult);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(_provider, _onStateChange);
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final state = ref.watch(_provider);
    final session = ref.watch(workoutSessionControllerProvider);
    final settings = ref.watch(settingsProvider).orDefault;
    final def = ref.read(_provider.notifier).definition;
    final frame = state.frame;

    final stage = _Stage(
      state: state,
      overlayOn: settings.overlayOn,
      view: widget.view,
    );
    Widget topStrip({required bool stacked}) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kDebugMode && frame != null)
          _DebugMetrics(
            frame: frame,
            snapshot: state.snapshot,
            engine: state.engine,
          ),
        _TopStrip(
          exerciseName: def?.name.text(l10n.localeName) ?? '',
          setLabel: l10n.setOf(session.currentSetIndex, session.setTotal),
          badge: state.isFakeEngine ? l10n.engineFakeBadge : l10n.privacyBadge,
          badgeColor: state.isFakeEngine
              ? FormaColors.secondary
              : FormaColors.success,
          stacked: stacked,
        ),
      ],
    );
    final statusLines = <Widget>[
      if (state.status == HudStatus.starting)
        Text(l10n.starting, style: text.titleLarge),
      if (state.status == HudStatus.error)
        Text(
          l10n.engineError(state.errorMessage ?? '?'),
          style: text.bodyMedium?.copyWith(color: FormaColors.warning),
          textAlign: TextAlign.center,
        ),
    ];
    final buttons = state.isSetup
        ? Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('hud_start_now'),
                  onPressed: ref.read(_provider.notifier).startNow,
                  child: Text(l10n.setupStartNow),
                ),
              ),
              const SizedBox(width: FormaSpacing.md),
              Expanded(
                child: OutlinedButton(
                  key: const Key('hud_setup_cancel'),
                  onPressed: () => context.go(Routes.today),
                  child: Text(l10n.setupCancel),
                ),
              ),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('hud_finish'),
                  onPressed: state.status == HudStatus.running ? _finish : null,
                  child: Text(l10n.finish),
                ),
              ),
              const SizedBox(width: FormaSpacing.md),
              Expanded(
                child: OutlinedButton(
                  key: const Key('hud_skip'),
                  onPressed: _skip,
                  child: Text(l10n.skip),
                ),
              ),
            ],
          );

    return Scaffold(
      backgroundColor: FormaColors.background,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final landscape = orientation == Orientation.landscape;
          final readout = state.isSetup
              ? _SetupPanel(state: state, view: widget.view)
              : _LiveReadout(
                  state: state,
                  definition: def,
                  landscape: landscape,
                );
          if (!landscape) {
            return Stack(
              fit: StackFit.expand,
              children: [
                stage,
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FormaSpacing.lg,
                      vertical: FormaSpacing.sm,
                    ),
                    child: Column(
                      children: [
                        topStrip(stacked: false),
                        const Spacer(),
                        ...statusLines,
                        readout,
                        const Spacer(),
                        const SizedBox(height: FormaSpacing.md),
                        buttons,
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          // Landscape (docs/06 §4.3 "yatayda sayaç sağda"): the camera fills
          // the left, everything the user reads sits on the right.
          return Row(
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    stage,
                    SafeArea(
                      right: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FormaSpacing.lg,
                          vertical: FormaSpacing.sm,
                        ),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: topStrip(stacked: true),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: ColoredBox(
                  color: FormaColors.background,
                  child: SafeArea(
                    left: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: FormaSpacing.lg,
                        vertical: FormaSpacing.sm,
                      ),
                      child: Column(
                        children: [
                          const Spacer(),
                          ...statusLines,
                          readout,
                          const Spacer(),
                          const SizedBox(height: FormaSpacing.md),
                          buttons,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The camera preview (or the dark stage of the synthetic engine) with the
/// skeleton over it. Settings "overlay" off means nothing is drawn — not
/// even the error joint; some users find the skeleton unsettling.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.state,
    required this.overlayOn,
    required this.view,
  });

  final HudState state;
  final bool overlayOn;
  final CameraView view;

  @override
  Widget build(BuildContext context) {
    final frame = state.frame;
    return Stack(
      fit: StackFit.expand,
      children: [
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
        if (overlayOn && frame != null)
          CustomPaint(
            painter: SkeletonPainter(
              frame: frame,
              tracking: state.tracking,
              highlight: state.showHighlight
                  ? (ruleJoints[state.highlightRule] ?? const [])
                  : const [],
            ),
          ),
      ],
    );
  }
}

/// Counter, score ring, tempo, the last cue and the "cannot see you" hint:
/// what the user reads during the set, in either orientation.
class _LiveReadout extends StatelessWidget {
  const _LiveReadout({
    required this.state,
    required this.definition,
    required this.landscape,
  });

  final HudState state;
  final ExerciseDefinition? definition;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final snap = state.snapshot;
    final isHold = definition?.countMode == CountMode.hold;
    final count = isHold ? (snap?.holdMs ?? 0) ~/ 1000 : (snap?.repCount ?? 0);
    final target = isHold ? null : state.targetReps;
    final tracking = state.tracking;
    final lastScore = snap?.lastRepScore;
    final counterSemantics = target != null
        ? l10n.repTargetSemantics(count, target)
        : isHold
        ? l10n.holdSecondsSemantics(count)
        : l10n.repCountSemantics(count);
    final scoreSemantics = lastScore == null
        ? l10n.formScoreNoneSemantics
        : l10n.formScoreSemantics(ScoreText.format(lastScore));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          key: const Key('hud_counter'),
          container: true,
          liveRegion: true,
          label: counterSemantics,
          excludeSemantics: true,
          child: _RepCounter(
            count: count,
            target: target,
            unit: isHold ? l10n.seconds : l10n.reps,
            tracking: tracking,
            landscape: landscape,
          ),
        ),
        const SizedBox(height: FormaSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScoreRing(
              score: lastScore,
              label: l10n.form,
              semanticsLabel: scoreSemantics,
            ),
            const SizedBox(width: FormaSpacing.xl),
            if (!isHold) _TempoLabel(rep: snap, label: l10n.tempo),
          ],
        ),
        const SizedBox(height: FormaSpacing.md),
        // A single space keeps the line's height while there is no cue, so
        // the layout does not jump when the first one arrives.
        Semantics(
          liveRegion: true,
          child: AnimatedOpacity(
            opacity: state.showCue ? 1 : 0,
            duration: FormaMotion.of(context, FormaMotion.cueFade),
            curve: FormaMotion.curve,
            child: Text(
              state.lastCue?.text ?? ' ',
              style: text.headlineSmall?.copyWith(color: FormaColors.warning),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (!tracking && state.status == HudStatus.running)
          Text(
            (snap?.bodyInFrame ?? true) ? l10n.cantSeeYou : l10n.outOfFrame,
            style: text.bodyMedium?.copyWith(color: FormaColors.textMuted),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class _TopStrip extends StatelessWidget {
  const _TopStrip({
    required this.exerciseName,
    required this.setLabel,
    required this.badge,
    required this.badgeColor,
    this.stacked = false,
  });

  final String exerciseName;
  final String setLabel;
  final String badge;
  final Color badgeColor;

  /// Landscape: the strip sits over the narrow camera pane, so the badge
  /// takes a line of its own instead of squeezing the name.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = Expanded(
      child: Text(
        exerciseName,
        style: text.labelLarge,
        textAlign: stacked ? TextAlign.left : TextAlign.right,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final set = Text(setLabel, style: text.bodySmall);
    final pill = PrivacyBadge(label: badge, color: badgeColor);
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pill,
          const SizedBox(height: FormaSpacing.xs),
          Row(
            children: [
              name,
              const SizedBox(width: FormaSpacing.sm),
              set,
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        pill,
        const SizedBox(width: FormaSpacing.sm),
        name,
        const SizedBox(width: FormaSpacing.sm),
        set,
      ],
    );
  }
}

/// The number the user reads from across the room. Lime while tracking,
/// muted while the coach cannot see them (docs/06 §7); a short scale pulse
/// each time it goes up.
class _RepCounter extends StatelessWidget {
  const _RepCounter({
    required this.count,
    required this.target,
    required this.unit,
    required this.tracking,
    required this.landscape,
  });

  final int count;
  final int? target;
  final String unit;
  final bool tracking;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final color = tracking ? FormaColors.primary : FormaColors.textMuted;
    // Landscape has less height to give; docs/06 §4.3 wants a quarter of it.
    final style = (landscape ? text.displayMedium : text.displayLarge)
        ?.copyWith(color: color);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            TweenAnimationBuilder<double>(
              // A new key restarts the tween, so the pulse plays once per
              // change and never on a rebuild that left the count alone.
              key: ValueKey(count),
              tween: Tween(begin: 0, end: 1),
              duration: FormaMotion.of(context, FormaMotion.counterPulse),
              curve: FormaMotion.curve,
              builder: (_, t, child) => Transform.scale(
                scale: 1 + (_pulseScale - 1) * math.sin(math.pi * t),
                child: child,
              ),
              child: Text('$count', style: style),
            ),
            if (target != null) ...[
              const SizedBox(width: FormaSpacing.sm),
              Text(
                l10n.repTargetLabel(target!),
                style: text.headlineMedium?.copyWith(
                  color: FormaColors.textMuted,
                ),
              ),
            ],
          ],
        ),
        Text(
          unit,
          style: text.bodyLarge?.copyWith(color: FormaColors.textMuted),
        ),
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
    final text = Theme.of(context).textTheme;
    final elapsed = rep?.currentRepElapsedMs;
    final value = elapsed == null
        ? '–'
        : '${(elapsed / 1000).toStringAsFixed(1)}s';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: text.headlineSmall?.copyWith(color: FormaColors.secondary),
        ),
        const SizedBox(height: FormaSpacing.xs),
        Text(label, style: text.labelMedium),
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
        color: FormaColors.background,
        child: Text(
          '$engine ${frame.width}x${frame.height} | '
          'fps ${frame.fps?.toStringAsFixed(1) ?? '-'} | '
          'lat ${frame.inferenceMs?.toStringAsFixed(0) ?? '-'}ms | '
          'vis ${s?.confidence.toStringAsFixed(2) ?? '-'} | '
          'sig ${s?.signalValue?.toStringAsFixed(0) ?? '-'} | '
          '${s?.phase.name ?? '-'}',
          style: Theme.of(context).textTheme.labelSmall,
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
    final text = Theme.of(context).textTheme;
    final ready = state.framing?.isReady ?? false;
    final counting = state.status == HudStatus.countdown;
    final accent = ready ? FormaColors.success : FormaColors.warning;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.setupTitle,
          style: text.bodyMedium?.copyWith(color: FormaColors.textMuted),
        ),
        const SizedBox(height: FormaSpacing.xs),
        Text(
          view == CameraView.front ? l10n.setupHintFront : l10n.setupHintSide,
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: FormaSpacing.xl),
        if (counting)
          Text(
            '${state.countdownSeconds}',
            key: const Key('hud_countdown'),
            style: text.displayLarge?.copyWith(color: FormaColors.secondary),
          )
        else
          Icon(
            ready ? LucideIcons.circleCheck : LucideIcons.focus,
            size: _setupIconSize,
            color: accent,
            semanticLabel: counting ? l10n.setupReady : _message(l10n),
          ),
        const SizedBox(height: FormaSpacing.md),
        Semantics(
          liveRegion: true,
          child: Text(
            counting ? l10n.setupReady : _message(l10n),
            key: const Key('hud_framing_message'),
            style: text.headlineSmall?.copyWith(color: accent),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
