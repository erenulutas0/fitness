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

enum HudStatus { idle, starting, running, finished, error }

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
    this.setIndex = 1,
    this.setTotal = 3,
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
  final int setIndex;
  final int setTotal;

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
    int? setIndex,
    int? setTotal,
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
    setIndex: setIndex ?? this.setIndex,
    setTotal: setTotal ?? this.setTotal,
  );
}

/// Owns the pose engine subscription and the pure-Dart pipeline for one set.
@riverpod
class WorkoutController extends _$WorkoutController {
  ExerciseSession? _session;
  FeedbackScheduler? _scheduler;
  FormaPosePlatform? _engine;
  StreamSubscription<PoseFrame>? _sub;
  bool _ownsEngine = false;

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
      status: HudStatus.running,
      engine: info.engine,
      isFakeEngine: info.engine == 'fake',
    );
  }

  void _onFrame(PoseFrame frame) {
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
    unawaited(_stopEngine());
  }
}
