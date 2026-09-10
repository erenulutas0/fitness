import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/content/content_repository.dart';
import '../../../core/locale/locale_controller.dart';
import '../../../core/pose/pose_error.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_controller.dart';
import '../infrastructure/cue_player.dart';
import '../infrastructure/pose_engine_provider.dart';

part 'workout_controller.g.dart';

/// The set walks through framing → countdown → running, all on one open
/// camera: closing and reopening it between screens costs about a second and
/// makes the coach feel slow.
enum HudStatus { idle, starting, framing, countdown, running, finished, error }

/// Why the controller ended the set on its own. The HUD listens for this and
/// leaves the screen the same way the Finish button would.
enum HudExit {
  none,

  /// `targetReps` was reached (the onboarding demo: five squats and out).
  targetReached,

  /// The app went to the background (docs/06 §7): the camera is closed and
  /// whatever was counted is kept.
  backgrounded,
}

/// Everything the HUD needs, updated once per pose frame.
@immutable
class HudState {
  const HudState({
    required this.exerciseId,
    required this.view,
    this.status = HudStatus.idle,
    this.engine,
    this.isFakeEngine = false,
    this.error,
    this.errorMessage,
    this.frame,
    this.snapshot,
    this.lastCue,
    this.lastCueAtMs = 0,
    this.highlightRule,
    this.highlightUntilMs = 0,
    this.framing,
    this.countdownSeconds = 0,
    this.targetReps,
    this.exit = HudExit.none,
    this.pendingResult,
    this.inBackground = false,
  });

  final String exerciseId;
  final CameraView view;
  final HudStatus status;
  final String? engine;
  final bool isFakeEngine;

  /// Set with [HudStatus.error]; what the user is told.
  final PoseError? error;

  /// The engine's own words, for the debug strip and the logs only — it is
  /// an English developer string and never reaches the screen.
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

  /// Finish the set by itself once this many reps are counted; null means
  /// the user decides.
  final int? targetReps;

  /// Set when the controller, not the user, ended the set.
  final HudExit exit;

  /// The result of a set that was finished in the background, waiting for
  /// the HUD to come back and show it.
  final SetResult? pendingResult;

  /// True between `paused` and `resumed`, so the HUD navigates only once the
  /// user is looking again.
  final bool inBackground;

  bool get isSetup =>
      status == HudStatus.framing || status == HudStatus.countdown;

  int get nowMs => frame?.timestampMs ?? 0;
  bool get showCue =>
      lastCue != null && nowMs - lastCueAtMs < WorkoutController.cueVisibleMs;
  bool get showHighlight => highlightRule != null && nowMs < highlightUntilMs;
  bool get tracking => snapshot?.tracking ?? false;

  HudState copyWith({
    HudStatus? status,
    String? engine,
    bool? isFakeEngine,
    PoseError? error,
    String? errorMessage,
    PoseFrame? frame,
    SessionSnapshot? snapshot,
    CueCommand? lastCue,
    int? lastCueAtMs,
    String? highlightRule,
    int? highlightUntilMs,
    FramingResult? framing,
    int? countdownSeconds,
    int? targetReps,
    HudExit? exit,
    SetResult? pendingResult,
    bool? inBackground,
  }) => HudState(
    exerciseId: exerciseId,
    view: view,
    status: status ?? this.status,
    engine: engine ?? this.engine,
    isFakeEngine: isFakeEngine ?? this.isFakeEngine,
    error: error ?? this.error,
    errorMessage: errorMessage ?? this.errorMessage,
    frame: frame ?? this.frame,
    snapshot: snapshot ?? this.snapshot,
    lastCue: lastCue ?? this.lastCue,
    lastCueAtMs: lastCueAtMs ?? this.lastCueAtMs,
    highlightRule: highlightRule ?? this.highlightRule,
    highlightUntilMs: highlightUntilMs ?? this.highlightUntilMs,
    framing: framing ?? this.framing,
    countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    targetReps: targetReps ?? this.targetReps,
    exit: exit ?? this.exit,
    pendingResult: pendingResult ?? this.pendingResult,
    inBackground: inBackground ?? this.inBackground,
  );
}

/// Owns the pose engine subscription and the pure-Dart pipeline for one set.
///
/// Also the app-lifecycle observer for the set (docs/06 §7 "arka plana
/// geçiş"): the camera must never stay open while the app is in the
/// background, and a set that was under way is finished, not lost.
@riverpod
class WorkoutController extends _$WorkoutController
    with WidgetsBindingObserver {
  static const countdownSeconds = 5;

  /// The shot has to stay good this long before the countdown starts.
  static const readyHoldMs = 700;
  static const framingCueCooldownMs = 4000;

  /// Minimum gap between any two framing instructions, roughly one utterance.
  static const minFramingCueGapMs = 1500;

  /// docs/06 §5: the cue text stays 3 s, the error joint glows 1 s.
  static const cueVisibleMs = 3000;
  static const highlightMs = 1000;

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

  /// The frame at the deepest point of the set, kept for the shareable card
  /// (docs/06 §4.5). One frame, not a buffer: the card wants the user's real
  /// pose at their best rep, and landmarks are all it ever gets — no video
  /// leaves the phone, by design.
  PoseFrame? _deepestFrame;
  double? _deepestValue;

  /// start() is a chain of awaits and the provider is autoDispose: leaving the
  /// screen while it runs used to tear down nothing (both fields were still
  /// null) and then hand a live camera to a notifier nobody owns. The native
  /// engine stayed running, so every later set failed with ALREADY_RUNNING
  /// until the app was restarted.
  bool _disposed = false;

  /// Same shape of problem as [_disposed], for the background case: the app
  /// can be paused while the camera is still opening.
  bool _backgrounded = false;

  @override
  HudState build(String exerciseId, CameraView view) {
    WidgetsBinding.instance.addObserver(this);
    ref
      ..onDispose(_teardown)
      ..listen(settingsProvider, _onSettings);
    return HudState(exerciseId: exerciseId, view: view);
  }

  ExerciseDefinition? get definition => _session?.definition;

  /// Finish the set by itself after [reps] reps (`?reps=N` on the route).
  /// Only rep-counted exercises have a target; a hold runs until the user
  /// stops it.
  void setTargetReps(int reps) {
    if (reps < 1) return;
    state = state.copyWith(targetReps: reps);
  }

  /// Try the camera again after an error, from a clean state: the usual
  /// path is the user allowing the camera in the OS settings and coming
  /// back, and [start] does nothing unless the status is idle.
  Future<void> retry() async {
    if (state.status != HudStatus.error) return;
    state = HudState(
      exerciseId: state.exerciseId,
      view: state.view,
      targetReps: state.targetReps,
    );
    await start();
  }

  /// Opens this app's OS settings page. Android stops showing the camera
  /// dialog after two denials, so without this the permission error is a
  /// dead end. False when the platform could not open it.
  Future<bool> openAppSettings() =>
      ref.read(poseEngineProvider).openAppSettings();

  Future<void> start() async {
    if (state.status != HudStatus.idle) return;
    state = state.copyWith(status: HudStatus.starting);
    final content = await ref.read(contentRepositoryProvider.future);
    if (_disposed || _backgrounded) return;
    final def = content.exercise(exerciseId);
    if (def == null) {
      state = state.copyWith(
        status: HudStatus.error,
        error: PoseError.unknownExercise,
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
    _scheduler = _buildScheduler(
      quietMode: ref.read(settingsProvider).orDefault.quietMode,
    );

    var engine = ref.read(poseEngineProvider);
    PoseEngineInfo info;
    if (kDebugMode && ref.read(demoModeProvider)) {
      engine = buildFallbackEngine(view);
      _ownsEngine = true;
    }
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
        debugPrint('[hud] engine start failed: ${e.code.name}: ${e.message}');
        state = state.copyWith(
          status: HudStatus.error,
          error: PoseError.fromCode(e.code),
          errorMessage: e.message,
        );
        return;
      }
    }
    if (_disposed || _backgrounded) {
      // The screen went away, or the app did, while the camera was opening.
      await engine.stop();
      if (_ownsEngine && engine is FakeFormaPose) await engine.dispose();
      return;
    }
    _engine = engine;
    _sub = engine.frames.listen(
      _onFrame,
      onError: (Object e) {
        debugPrint('[hud] engine stream failed: $e');
        state = state.copyWith(
          status: HudStatus.error,
          error: e is PoseEngineException
              ? PoseError.fromCode(e.code)
              : PoseError.unknown,
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

  /// Settings "az konuş" (docs/06 §5): only the count and the critical
  /// corrections. Read synchronously — the HUD cannot wait on a preferences
  /// file — and rebuilt by [_onSettings] if the file lands after the start.
  FeedbackScheduler _buildScheduler({required bool quietMode}) =>
      FeedbackScheduler(
        catalog: _catalog!,
        locale: ref.read(localeControllerProvider).languageCode,
        policy: FeedbackPolicy(quietMode: quietMode),
      );

  void _onSettings(AsyncValue<AppSettings>? _, AsyncValue<AppSettings> next) {
    final scheduler = _scheduler;
    if (scheduler == null || _catalog == null) return;
    final quietMode = next.orDefault.quietMode;
    if (scheduler.policy.quietMode == quietMode) return;
    _scheduler = _buildScheduler(quietMode: quietMode);
  }

  /// Skip the framing step (the user pressed "start now").
  void startNow() {
    if (!state.isSetup) return;
    _countdownTimer?.cancel();
    _beginSet();
  }

  void _beginSet() {
    _countdownTimer?.cancel();
    _deepestFrame = null;
    _deepestValue = null;
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
    _trackDeepest(frame, session);
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
        highlightUntil = frame.timestampMs + highlightMs;
      }
    }
    final snapshot = session.snapshot;
    final target = state.targetReps;
    final reached =
        target != null &&
        session.definition.countMode != CountMode.hold &&
        snapshot.repCount >= target &&
        state.exit == HudExit.none;
    state = state.copyWith(
      frame: frame,
      snapshot: snapshot,
      lastCue: cue,
      lastCueAtMs: cueAt,
      highlightRule: highlight,
      highlightUntilMs: highlightUntil,
      exit: reached ? HudExit.targetReached : null,
    );
  }

  /// The pose at the deepest point of the set, or null if nothing was tracked.
  PoseFrame? get deepestFrame => _deepestFrame;

  void _trackDeepest(PoseFrame frame, ExerciseSession session) {
    final snap = session.snapshot;
    final value = snap.signalValue;
    if (value == null || !snap.tracking) return;
    final spec = session.definition.repFor(view);
    // "Deepest" follows the exercise: a squat's knee angle falls toward the
    // bottom, a glute bridge's hip angle rises toward the top.
    final decreasing = spec == null || spec.peakThreshold < spec.restThreshold;
    final best = _deepestValue;
    final better = best == null || (decreasing ? value < best : value > best);
    if (better) {
      _deepestValue = value;
      _deepestFrame = frame;
    }
  }

  /// Stop the engine and return the set result. Null when there is nothing
  /// to finish, including a set the background handler already closed.
  Future<SetResult?> finish() async {
    final session = _session;
    if (session == null || state.status == HudStatus.finished) return null;
    await _stopEngine();
    final result = session.finish();
    state = state.copyWith(status: HudStatus.finished);
    return result;
  }

  @override
  // The framework calls it `state`, which is the notifier's own state here.
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.paused:
        unawaited(_onPaused());
      case AppLifecycleState.resumed:
        if (_backgrounded && state.inBackground) {
          state = state.copyWith(inBackground: false);
        }
        // Coming back from the OS settings page is the whole point of the
        // permission error's button; the user allowed the camera there and
        // should not have to tap anything else.
        if (state.status == HudStatus.error &&
            (state.error?.needsSettings ?? false)) {
          unawaited(retry());
        }
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// docs/06 §7 "Arka plana geçiş: kamera kapanır, set kaydedilir". The
  /// engine stops now; the set, if one was running, is finished with what it
  /// has and parked in [HudState.pendingResult] until the app is back.
  Future<void> _onPaused() async {
    if (_disposed || _backgrounded) return;
    if (state.status == HudStatus.idle ||
        state.status == HudStatus.finished ||
        state.status == HudStatus.error) {
      return;
    }
    _backgrounded = true;
    _countdownTimer?.cancel();
    final session = state.status == HudStatus.running ? _session : null;
    await _stopEngine();
    if (_disposed) return;
    state = state.copyWith(
      status: HudStatus.finished,
      countdownSeconds: 0,
      exit: HudExit.backgrounded,
      pendingResult: session?.finish(),
      inBackground: true,
    );
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
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    unawaited(_stopEngine());
  }
}
