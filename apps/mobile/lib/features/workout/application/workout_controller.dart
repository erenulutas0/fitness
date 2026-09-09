import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/content/content_repository.dart';
import '../../../core/locale/locale_controller.dart';
import '../infrastructure/cue_player.dart';
import '../infrastructure/pose_engine_provider.dart';

part 'workout_controller.g.dart';

/// The set walks through framing → countdown → running, all on one open
/// camera: closing and reopening it between screens costs about a second and
/// makes the coach feel slow.
enum HudStatus { idle, starting, framing, countdown, running, finished, error }

/// Everything the HUD needs, updated once per pose frame.
@immutable
class HudState {
  const HudState({
    required this.exerciseId,
    required this.view,
    this.status = HudStatus.idle,
    this.engine,
    this.isFakeEngine = false,
    this.errorMessage,
    this.frame,
    this.snapshot,
    this.lastCue,
    this.lastCueAtMs = 0,
    this.highlightRule,
    this.highlightUntilMs = 0,
    this.framing,
    this.countdownSeconds = 0,
  });

  final String exerciseId;
  final CameraView view;
  final HudStatus status;
  final String? engine;
  final bool isFakeEngine;
  final String? errorMessage;
  final PoseFrame? frame;
  final SessionSnapshot? snapshot;
  final CueCommand? lastCue;
  final int lastCueAtMs;

  /// Rule whose joints glow orange on the overlay for a moment.
  final String? highlightRule;
  final int highlightUntilMs;

  /// Live framing verdict, used by the setup step and the out-of-frame hint.
  final FramingResult? framing;
  final int countdownSeconds;

  bool get isSetup =>
      status == HudStatus.framing || status == HudStatus.countdown;

  int get nowMs => frame?.timestampMs ?? 0;
  bool get showCue => lastCue != null && nowMs - lastCueAtMs < 3000;
  bool get showHighlight => highlightRule != null && nowMs < highlightUntilMs;
  bool get tracking => snapshot?.tracking ?? false;

  HudState copyWith({
    HudStatus? status,
    String? engine,
    bool? isFakeEngine,
    String? errorMessage,
    PoseFrame? frame,
    SessionSnapshot? snapshot,
    CueCommand? lastCue,
    int? lastCueAtMs,
    String? highlightRule,
    int? highlightUntilMs,
    FramingResult? framing,
    int? countdownSeconds,
  }) => HudState(
    exerciseId: exerciseId,
    view: view,
    status: status ?? this.status,
    engine: engine ?? this.engine,
    isFakeEngine: isFakeEngine ?? this.isFakeEngine,
    errorMessage: errorMessage ?? this.errorMessage,
    frame: frame ?? this.frame,
    snapshot: snapshot ?? this.snapshot,
    lastCue: lastCue ?? this.lastCue,
    lastCueAtMs: lastCueAtMs ?? this.lastCueAtMs,
    highlightRule: highlightRule ?? this.highlightRule,
    highlightUntilMs: highlightUntilMs ?? this.highlightUntilMs,
    framing: framing ?? this.framing,
    countdownSeconds: countdownSeconds ?? this.countdownSeconds,
  );
}

/// Owns the pose engine subscription and the pure-Dart pipeline for one set.
@riverpod
class WorkoutController extends _$WorkoutController {
  static const countdownSeconds = 5;

  /// The shot has to stay good this long before the countdown starts.
  static const readyHoldMs = 700;
  static const framingCueCooldownMs = 4000;

  /// Minimum gap between any two framing instructions, roughly one utterance.
  static const minFramingCueGapMs = 1500;

  ExerciseSession? _session;
  FeedbackScheduler? _scheduler;
  CueCatalog? _catalog;
  Timer? _countdownTimer;
  final FramingChecker _framingChecker = const FramingChecker();
  final FeatureExtractor _extractor = FeatureExtractor();
  int? _readySinceMs;
  String? _lastFramingCue;
  int _lastFramingCueMs = -1 << 30;
  FormaPosePlatform? _engine;
  StreamSubscription<PoseFrame>? _sub;
  bool _ownsEngine = false;

  /// start() is a chain of awaits and the provider is autoDispose: leaving the
  /// screen while it runs used to tear down nothing (both fields were still
  /// null) and then hand a live camera to a notifier nobody owns. The native
  /// engine stayed running, so every later set failed with ALREADY_RUNNING
  /// until the app was restarted.
  bool _disposed = false;

  @override
  HudState build(String exerciseId, CameraView view) {
    ref.onDispose(_teardown);
    return HudState(exerciseId: exerciseId, view: view);
  }

  ExerciseDefinition? get definition => _session?.definition;

  Future<void> start() async {
    if (state.status != HudStatus.idle) return;
    state = state.copyWith(status: HudStatus.starting);
    final content = await ref.read(contentRepositoryProvider.future);
    if (_disposed) return;
    final def = content.exercise(exerciseId);
    if (def == null) {
      state = state.copyWith(
        status: HudStatus.error,
        errorMessage: 'unknown exercise $exerciseId',
      );
      return;
    }
    _session = ExerciseSession(
      definition: def,
      view: view,
      config: const SessionConfig(detectGestures: true),
    );
    _catalog = content.cues;
    _scheduler = FeedbackScheduler(
      catalog: content.cues,
      locale: ref.read(localeControllerProvider).languageCode,
    );

    var engine = ref.read(poseEngineProvider);
    PoseEngineInfo info;
    try {
      if (!await engine.hasCameraPermission()) {
        await engine.requestCameraPermission();
      }
      info = await engine.start(
        const PoseStartOptions(lens: CameraLens.back, model: PoseModel.lite),
      );
    } on PoseEngineException catch (e) {
      if (e.code == PoseErrorCode.notSupported ||
          e.code == PoseErrorCode.cameraUnavailable) {
        engine = buildFallbackEngine(view);
        _ownsEngine = true;
        info = await engine.start();
      } else {
        state = state.copyWith(
          status: HudStatus.error,
          errorMessage: e.message,
        );
        return;
      }
    }
    if (_disposed) {
      // The screen went away while the camera was opening.
      await engine.stop();
      if (_ownsEngine && engine is FakeFormaPose) await engine.dispose();
      return;
    }
    _engine = engine;
    _sub = engine.frames.listen(
      _onFrame,
      onError: (Object e) {
        state = state.copyWith(
          status: HudStatus.error,
          errorMessage: e.toString(),
        );
      },
    );
    state = state.copyWith(
      status: HudStatus.framing,
      engine: info.engine,
      isFakeEngine: info.engine == 'fake',
    );
  }

  /// Skip the framing step (the user pressed "start now").
  void startNow() {
    if (!state.isSetup) return;
    _countdownTimer?.cancel();
    _beginSet();
  }

  void _beginSet() {
    _countdownTimer?.cancel();
    final def = _session?.definition;
    if (def != null) {
      // Drop whatever happened while the phone was being placed.
      _session = ExerciseSession(
        definition: def,
        view: view,
        config: const SessionConfig(detectGestures: true),
      );
    }
    state = state.copyWith(status: HudStatus.running, countdownSeconds: 0);
  }

  void _startCountdown() {
    if (state.status == HudStatus.countdown) return;
    state = state.copyWith(
      status: HudStatus.countdown,
      countdownSeconds: countdownSeconds,
    );
    _speakCountdown(countdownSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.countdownSeconds - 1;
      if (left <= 0) {
        t.cancel();
        _speak('go', priority: 5, haptic: HapticKind.success);
        _beginSet();
      } else {
        state = state.copyWith(countdownSeconds: left);
        _speakCountdown(left);
      }
    });
  }

  void _cancelCountdown() {
    if (state.status != HudStatus.countdown) return;
    _countdownTimer?.cancel();
    state = state.copyWith(status: HudStatus.framing, countdownSeconds: 0);
  }

  void _speakCountdown(int seconds) {
    if (seconds < 1 || seconds > 3) return;
    _speak('ready_$seconds', priority: 5, haptic: HapticKind.tick);
  }

  /// Speak a catalog cue outside the scheduler (setup guidance, countdown).
  void _speak(
    String clipId, {
    int priority = 4,
    HapticKind haptic = HapticKind.none,
  }) {
    final catalog = _catalog;
    if (catalog == null || !catalog.has(clipId)) return;
    final locale = ref.read(localeControllerProvider).languageCode;
    unawaited(
      ref
          .read(cuePlayerProvider)
          .play(
            CueCommand(
              clipId: clipId,
              variant: 0,
              priority: priority,
              haptic: haptic,
              tMs: state.nowMs,
              text: catalog.text(clipId, locale: locale),
              interrupts: priority >= 4,
            ),
          ),
    );
  }

  static const framingCueIds = <FramingStatus, String>{
    FramingStatus.noPose: 'cant_see_you',
    FramingStatus.lowConfidence: 'cant_see_you',
    FramingStatus.tooClose: 'step_back',
    FramingStatus.tooFar: 'step_closer',
    FramingStatus.moveTowardImageRight: 'move_right',
    FramingStatus.moveTowardImageLeft: 'move_left',
    FramingStatus.ok: 'in_frame',
  };

  /// One frame of the framing step: guide the user, then count down once the
  /// shot has been good for a moment (a single lucky frame is not enough).
  void _onSetupFrame(PoseFrame frame) {
    final features = _extractor.extract(frame);
    final framing = _framingChecker.check(features);
    state = state.copyWith(frame: frame, framing: framing);

    final ready = framing.isReady;
    if (!ready) {
      _readySinceMs = null;
      _cancelCountdown();
      if (!framing.brightnessOk) {
        _speakFramingCue('more_light', frame.timestampMs);
      } else {
        final cue = framingCueIds[framing.status];
        if (cue != null) _speakFramingCue(cue, frame.timestampMs);
      }
      return;
    }
    _readySinceMs ??= frame.timestampMs;
    if (frame.timestampMs - _readySinceMs! >= readyHoldMs &&
        state.status == HudStatus.framing) {
      _speakFramingCue('in_frame', frame.timestampMs);
      _startCountdown();
    }
  }

  void _speakFramingCue(String clipId, int nowMs) {
    // Two guards, because they stop different things. The same instruction
    // repeats at most every few seconds; ANY instruction waits for the last
    // one to be spoken. Without the second, a measurement sitting on a
    // threshold flips the verdict frame to frame and the coach stutters
    // between "step back" and "step closer" at 30 fps.
    if (nowMs - _lastFramingCueMs < minFramingCueGapMs) return;
    if (clipId == _lastFramingCue &&
        nowMs - _lastFramingCueMs < framingCueCooldownMs) {
      return;
    }
    _lastFramingCue = clipId;
    _lastFramingCueMs = nowMs;
    _speak(clipId);
  }

  void _onFrame(PoseFrame frame) {
    if (state.isSetup) {
      _onSetupFrame(frame);
      return;
    }
    final session = _session;
    final scheduler = _scheduler;
    if (session == null ||
        scheduler == null ||
        state.status != HudStatus.running) {
      return;
    }
    final events = session.process(frame);
    final cues = scheduler.handle(events, nowMs: frame.timestampMs);
    if (cues.isNotEmpty) unawaited(ref.read(cuePlayerProvider).playAll(cues));

    var cue = state.lastCue;
    var cueAt = state.lastCueAtMs;
    var highlight = state.highlightRule;
    var highlightUntil = state.highlightUntilMs;
    for (final c in cues) {
      if (c.ruleId != null || c.clipId == 'cant_see_you') {
        cue = c;
        cueAt = frame.timestampMs;
      }
      if (c.ruleId != null) {
        highlight = c.ruleId;
        highlightUntil = frame.timestampMs + 1000;
      }
    }
    state = state.copyWith(
      frame: frame,
      snapshot: session.snapshot,
      lastCue: cue,
      lastCueAtMs: cueAt,
      highlightRule: highlight,
      highlightUntilMs: highlightUntil,
    );
  }

  /// Stop the engine and return the set result.
  Future<SetResult?> finish() async {
    final session = _session;
    if (session == null) return null;
    await _stopEngine();
    final result = session.finish();
    state = state.copyWith(status: HudStatus.finished);
    return result;
  }

  Future<void> _stopEngine() async {
    // Broadcast-stream cancellation is synchronous; awaiting its (root-zone)
    // future would stall under FakeAsync in widget tests.
    unawaited(_sub?.cancel());
    _sub = null;
    final engine = _engine;
    if (engine != null && engine.isRunning) {
      await engine.stop();
    }
    if (_ownsEngine && engine is FakeFormaPose) {
      await engine.dispose();
    }
    _engine = null;
  }

  void _teardown() {
    _disposed = true;
    _countdownTimer?.cancel();
    unawaited(_stopEngine());
  }
}
