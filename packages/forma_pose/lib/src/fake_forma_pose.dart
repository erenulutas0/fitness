import 'dart:async';

import 'package:forma_rules/forma_rules.dart';

import 'forma_pose_platform_interface.dart';

/// A camera-less engine that replays synthetic motion or a recorded fixture
/// in real time. Lets the whole app run on desktop, in tests and on devices
/// without a working native plugin.
class FakeFormaPose extends FormaPosePlatform {
  FakeFormaPose({
    required this.source,
    this.fps = 30,
    this.loop = true,
    this.engineName = 'fake',
  });

  /// Endless synthetic squats (optionally with an injected error).
  factory FakeFormaPose.syntheticSquat({
    CameraView view = CameraView.front,
    double valgus = 0,
    double extraTorsoLeanDeg = 0,
    double heelRise = 0,
    double peakAngle = 90,
    double noiseStd = 0.003,
    int reps = 6,
    int width = 720,
    int height = 1280,
  }) => FakeFormaPose(
    source: const SyntheticPose().squat(
      view: view,
      reps: reps,
      valgus: valgus,
      extraTorsoLeanDeg: extraTorsoLeanDeg,
      heelRise: heelRise,
      peakAngle: peakAngle,
      noiseStd: noiseStd,
      width: width,
      height: height,
    ),
  );

  factory FakeFormaPose.fixture(LandmarkFixture fixture, {bool loop = true}) =>
      FakeFormaPose(source: fixture.frames, loop: loop);

  final List<PoseFrame> source;
  final int fps;
  final bool loop;
  final String engineName;

  final StreamController<PoseFrame> _controller =
      StreamController<PoseFrame>.broadcast();
  Timer? _timer;
  int _index = 0;
  int _offsetMs = 0;
  PoseModel _model = PoseModel.lite;

  @override
  bool get isRunning => _timer != null;

  @override
  bool get supportsPreview => false;

  @override
  Stream<PoseFrame> get frames => _controller.stream;

  /// Current model (for tests).
  PoseModel get model => _model;

  @override
  Future<PoseEngineInfo> start([
    PoseStartOptions options = const PoseStartOptions(),
  ]) async {
    if (_timer != null) {
      throw const PoseEngineException(
        PoseErrorCode.alreadyRunning,
        'fake engine already running',
      );
    }
    if (source.isEmpty) {
      throw const PoseEngineException(
        PoseErrorCode.modelLoadFailed,
        'fake engine has no frames',
      );
    }
    _model = options.model;
    _index = 0;
    _offsetMs = 0;
    _timer = Timer.periodic(
      Duration(milliseconds: (1000 / fps).round()),
      (_) => _tick(),
    );
    return PoseEngineInfo(
      engine: engineName,
      model: options.model,
      gpu: false,
      width: source.first.width,
      height: source.first.height,
      lens: options.lens,
    );
  }

  void _tick() {
    if (_index >= source.length) {
      if (!loop) {
        unawaited(stop());
        return;
      }
      _offsetMs += source.last.timestampMs - source.first.timestampMs + 700;
      _index = 0;
    }
    final f = source[_index++];
    // Deterministic clock: independent of wall time so tests with fake async
    // and real devices behave the same.
    final shifted = PoseFrame(
      timestampMs: f.timestampMs + _offsetMs,
      landmarks: f.landmarks,
      worldLandmarks: f.worldLandmarks,
      width: f.width,
      height: f.height,
      fps: fps.toDouble(),
      inferenceMs: 0,
      brightness: 0.5,
    );
    if (!_controller.isClosed) _controller.add(shifted);
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> setModel(PoseModel model) async {
    _model = model;
  }

  @override
  Future<bool> hasCameraPermission() async => true;

  @override
  Future<bool> requestCameraPermission() async => true;

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
