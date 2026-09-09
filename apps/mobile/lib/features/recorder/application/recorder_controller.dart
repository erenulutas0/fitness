import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../workout/infrastructure/pose_engine_provider.dart';

part 'recorder_controller.g.dart';

/// What the founder sets before pressing record (docs/fixtures-schema.md).
@immutable
class RecordingConfig {
  const RecordingConfig({
    required this.exerciseId,
    required this.view,
    this.person = 'p01',
    this.environment = 'living_room',
    this.model = PoseModel.lite,
    this.lens = CameraLens.back,
    this.notes,
  });

  final String exerciseId;
  final CameraView view;

  /// Anonymous participant code; no names are stored.
  final String person;
  final String environment;
  final PoseModel model;
  final CameraLens lens;
  final String? notes;

  RecordingConfig copyWith({
    String? exerciseId,
    CameraView? view,
    String? person,
    String? environment,
    PoseModel? model,
    CameraLens? lens,
    String? notes,
  }) => RecordingConfig(
    exerciseId: exerciseId ?? this.exerciseId,
    view: view ?? this.view,
    person: person ?? this.person,
    environment: environment ?? this.environment,
    model: model ?? this.model,
    lens: lens ?? this.lens,
    notes: notes ?? this.notes,
  );
}

enum RecorderStatus { idle, starting, countdown, recording, stopped, error }

/// A finished recording plus what the engine made of it. The engine's reading
/// is a hint for labelling, never the label itself.
class RecordingDraft {
  const RecordingDraft({
    required this.config,
    required this.frames,
    required this.engineResult,
    required this.device,
  });

  final RecordingConfig config;
  final List<PoseFrame> frames;
  final SetResult engineResult;
  final String? device;

  int get durationMs =>
      frames.isEmpty ? 0 : frames.last.timestampMs - frames.first.timestampMs;

  int get engineReps => engineResult.repCount;
  int get engineHoldMs => engineResult.totalHoldMs;

  /// Rules the engine thinks fired on a given 1-based rep / hold.
  Set<String> engineRulesFor(int index) {
    for (final r in engineResult.reps) {
      if (r.index == index) return r.failedRules.toSet();
    }
    for (final h in engineResult.holds) {
      if (h.index == index) return h.failedRules.toSet();
    }
    return const {};
  }

  double get meanVisibility {
    if (frames.isEmpty) return 0;
    var sum = 0.0;
    for (final f in frames) {
      sum += f.meanVisibility(coreLandmarks);
    }
    return sum / frames.length;
  }

  /// Share of frames in which nobody was tracked well enough.
  double get lostRatio {
    if (frames.isEmpty) return 0;
    var lost = 0;
    for (final f in frames) {
      if (!f.hasPose || f.meanVisibility(coreLandmarks) < 0.5) lost++;
    }
    return lost / frames.length;
  }

  /// Turn the recording into a labelled fixture ready to be written out.
  LandmarkFixture toFixture({
    required List<FixtureLabel> labels,
    int? expectedReps,
    int? expectedHoldMs,
    String? notes,
  }) {
    final now = DateTime.now();
    return LandmarkFixture(
      id:
          '${config.exerciseId}_${config.view.name}_${config.person}_'
          '${now.millisecondsSinceEpoch}',
      exerciseId: config.exerciseId,
      view: config.view,
      person: config.person,
      environment: config.environment,
      device: device,
      modelVariant: config.model.name,
      recordedAt: now.toIso8601String(),
      expectedReps: expectedReps,
      expectedHoldMs: expectedHoldMs,
      errorLabels: labels,
      notes: notes ?? config.notes,
      frames: frames,
    ).rebased();
  }
}

@immutable
class RecorderState {
  const RecorderState({
    this.status = RecorderStatus.idle,
    this.frameCount = 0,
    this.durationMs = 0,
    this.countdownSeconds = 0,
    this.frame,
    this.framing,
    this.engineReps = 0,
    this.engineHoldMs = 0,
    this.errorMessage,
    this.engine,
    this.reachedLimit = false,
  });

  final RecorderStatus status;
  final int frameCount;
  final int durationMs;
  final int countdownSeconds;
  final PoseFrame? frame;
  final FramingResult? framing;
  final int engineReps;
  final int engineHoldMs;
  final String? errorMessage;
  final String? engine;

  /// The 3-minute cap was hit. The screen finishes the take the same way a
  /// manual stop does; the controller cannot navigate, and calling stop()
  /// here would drop the draft on the floor and leave a three-minute
  /// recording behind a button that now reads "Vazgeç".
  final bool reachedLimit;

  bool get isRecording => status == RecorderStatus.recording;
  bool get isLive =>
      status == RecorderStatus.countdown || status == RecorderStatus.recording;

  RecorderState copyWith({
    RecorderStatus? status,
    int? frameCount,
    int? durationMs,
    int? countdownSeconds,
    PoseFrame? frame,
    FramingResult? framing,
    int? engineReps,
    int? engineHoldMs,
    String? errorMessage,
    String? engine,
    bool? reachedLimit,
  }) => RecorderState(
    status: status ?? this.status,
    frameCount: frameCount ?? this.frameCount,
    durationMs: durationMs ?? this.durationMs,
    countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    frame: frame ?? this.frame,
    framing: framing ?? this.framing,
    engineReps: engineReps ?? this.engineReps,
    engineHoldMs: engineHoldMs ?? this.engineHoldMs,
    errorMessage: errorMessage ?? this.errorMessage,
    engine: engine ?? this.engine,
    reachedLimit: reachedLimit ?? this.reachedLimit,
  );
}

/// Records raw [PoseFrame]s for the eval fixture set (docs/10 Prompt 3).
///
/// Raw frames are stored deliberately: smoothing and thresholds must stay
/// tunable after the fact, so the file keeps what the engine actually saw.
@riverpod
class RecorderController extends _$RecorderController {
  /// Cap on one take: ~5400 frames, about 11 MB of landmarks in memory.
  static const int maxDurationMs = 3 * 60 * 1000;
  static const int countdownSeconds = 5;

  final List<PoseFrame> _frames = <PoseFrame>[];
  ExerciseSession? _session;
  FormaPosePlatform? _engine;
  StreamSubscription<PoseFrame>? _sub;
  Timer? _countdownTimer;
  bool _ownsEngine = false;

  /// See WorkoutController._disposed: an autoDispose notifier can go away
  /// mid-start and leave a live camera behind.
  bool _disposed = false;
  int? _recordStartMs;
  RecordingConfig? _config;
  String? _device;
  final FramingChecker _framing = const FramingChecker();
  final FeatureExtractor _extractor = FeatureExtractor();

  @override
  RecorderState build() {
    ref.onDispose(() {
      _disposed = true;
      _countdownTimer?.cancel();
      unawaited(_stopEngine());
    });
    return const RecorderState();
  }

  /// Open the camera and start the countdown. [definition] drives the live
  /// rep readout while recording.
  Future<void> start(
    RecordingConfig config,
    ExerciseDefinition definition, {
    String? device,
  }) async {
    if (state.status != RecorderStatus.idle &&
        state.status != RecorderStatus.stopped &&
        state.status != RecorderStatus.error) {
      return;
    }
    _config = config;
    _device = device;
    _frames.clear();
    _recordStartMs = null;
    _session = ExerciseSession(definition: definition, view: config.view);
    state = const RecorderState(status: RecorderStatus.starting);

    var engine = ref.read(poseEngineProvider);
    PoseEngineInfo info;
    try {
      if (!await engine.hasCameraPermission()) {
        await engine.requestCameraPermission();
      }
      info = await engine.start(
        PoseStartOptions(lens: config.lens, model: config.model),
      );
    } on PoseEngineException catch (e) {
      if (e.code == PoseErrorCode.notSupported ||
          e.code == PoseErrorCode.cameraUnavailable) {
        engine = buildFallbackEngine(config.view);
        _ownsEngine = true;
        info = await engine.start();
      } else {
        state = state.copyWith(
          status: RecorderStatus.error,
          errorMessage: e.message,
        );
        return;
      }
    }
    if (_disposed) {
      // The screen went away while the camera was opening: nothing owns this
      // engine any more, and the countdown timer below would tick forever on
      // a dead notifier.
      await engine.stop();
      if (_ownsEngine && engine is FakeFormaPose) await engine.dispose();
      return;
    }
    _engine = engine;
    _device ??= info.device;
    _sub = engine.frames.listen(
      _onFrame,
      onError: (Object e) => state = state.copyWith(
        status: RecorderStatus.error,
        errorMessage: e.toString(),
      ),
    );
    state = state.copyWith(
      status: RecorderStatus.countdown,
      countdownSeconds: countdownSeconds,
      engine: info.engine,
    );
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.countdownSeconds - 1;
      if (left <= 0) {
        t.cancel();
        state = state.copyWith(
          status: RecorderStatus.recording,
          countdownSeconds: 0,
        );
      } else {
        state = state.copyWith(countdownSeconds: left);
      }
    });
  }

  void _onFrame(PoseFrame frame) {
    final framing = _framing.check(_extractor.extract(frame));
    if (!state.isLive) {
      state = state.copyWith(frame: frame, framing: framing);
      return;
    }
    if (state.status == RecorderStatus.countdown) {
      state = state.copyWith(frame: frame, framing: framing);
      return;
    }
    _recordStartMs ??= frame.timestampMs;
    _frames.add(frame);
    final session = _session;
    if (session != null) session.process(frame);
    final snap = session?.snapshot;
    final duration = frame.timestampMs - _recordStartMs!;
    state = state.copyWith(
      frame: frame,
      framing: framing,
      frameCount: _frames.length,
      durationMs: duration,
      engineReps: snap?.repCount ?? 0,
      engineHoldMs: snap?.holdMs ?? 0,
    );
    if (duration >= maxDurationMs && !state.reachedLimit) {
      state = state.copyWith(reachedLimit: true);
    }
  }

  /// Stop recording and hand back the draft for labelling.
  Future<RecordingDraft?> stop() async {
    _countdownTimer?.cancel();
    final config = _config;
    final session = _session;
    if (config == null || session == null) {
      await _stopEngine();
      state = state.copyWith(status: RecorderStatus.stopped);
      return null;
    }
    await _stopEngine();
    final result = session.finish();
    state = state.copyWith(status: RecorderStatus.stopped);
    if (_frames.isEmpty) return null;
    return RecordingDraft(
      config: config,
      frames: List.unmodifiable(_frames),
      engineResult: result,
      device: _device,
    );
  }

  Future<void> _stopEngine() async {
    unawaited(_sub?.cancel());
    _sub = null;
    final engine = _engine;
    if (engine != null && engine.isRunning) await engine.stop();
    if (_ownsEngine && engine is FakeFormaPose) await engine.dispose();
    _engine = null;
    _ownsEngine = false;
  }
}
