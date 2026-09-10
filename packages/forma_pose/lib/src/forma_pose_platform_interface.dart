import 'package:forma_rules/forma_rules.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_forma_pose.dart';

enum CameraLens { front, back }

/// MediaPipe Pose Landmarker model variants (docs/04 §1).
enum PoseModel {
  lite,
  full,
  heavy
  ;

  String get assetFileName => 'pose_landmarker_$name.task';
}

enum PoseErrorCode {
  permissionDenied,
  cameraUnavailable,
  modelLoadFailed,
  notSupported,
  alreadyRunning,
  unknown
  ;

  static PoseErrorCode parse(String? code) => switch (code) {
    'PERMISSION_DENIED' => PoseErrorCode.permissionDenied,
    'CAMERA_UNAVAILABLE' => PoseErrorCode.cameraUnavailable,
    'MODEL_LOAD_FAILED' => PoseErrorCode.modelLoadFailed,
    'NOT_SUPPORTED' => PoseErrorCode.notSupported,
    'ALREADY_RUNNING' => PoseErrorCode.alreadyRunning,
    _ => PoseErrorCode.unknown,
  };
}

/// Typed error from the pose engine.
class PoseEngineException implements Exception {
  const PoseEngineException(this.code, this.message);

  final PoseErrorCode code;
  final String message;

  @override
  String toString() => 'PoseEngineException(${code.name}): $message';
}

/// What the engine actually started with (GPU may fall back to CPU).
class PoseEngineInfo {
  const PoseEngineInfo({
    required this.engine,
    required this.model,
    required this.gpu,
    required this.width,
    required this.height,
    this.lens = CameraLens.back,
    this.device,
  });

  /// `mediapipe` | `vision` (Apple fallback) | `fake`.
  final String engine;
  final PoseModel model;
  final bool gpu;
  final int width;
  final int height;
  final CameraLens lens;

  /// Human-readable device model; eval reports slice accuracy by hardware.
  final String? device;

  @override
  String toString() =>
      'PoseEngineInfo($engine ${model.name} gpu=$gpu ${width}x$height ${lens.name}${device == null ? '' : ' on $device'})';
}

/// Options for [FormaPosePlatform.start].
class PoseStartOptions {
  const PoseStartOptions({
    this.lens = CameraLens.back,
    this.model = PoseModel.lite,
    this.gpu = true,
    this.targetWidth = 640,
    this.targetHeight = 480,
    this.minDetectionConfidence = 0.5,
    this.minTrackingConfidence = 0.5,
    this.minPresenceConfidence = 0.5,
  });

  final CameraLens lens;
  final PoseModel model;
  final bool gpu;

  /// Requested analysis resolution (the native layer picks the closest).
  final int targetWidth;
  final int targetHeight;
  final double minDetectionConfidence;
  final double minTrackingConfidence;
  final double minPresenceConfidence;

  Map<String, Object?> toMap() => {
    'lens': lens.name,
    'model': model.name,
    'gpu': gpu,
    'targetWidth': targetWidth,
    'targetHeight': targetHeight,
    'minDetectionConfidence': minDetectionConfidence,
    'minTrackingConfidence': minTrackingConfidence,
    'minPresenceConfidence': minPresenceConfidence,
  };
}

/// The interface every platform implementation (Android, iOS, Fake) fulfils.
abstract class FormaPosePlatform extends PlatformInterface {
  FormaPosePlatform() : super(token: _token);

  static final Object _token = Object();
  static FormaPosePlatform _instance = MethodChannelFormaPose();

  static FormaPosePlatform get instance => _instance;

  static set instance(FormaPosePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Start the camera and the landmarker; throws [PoseEngineException].
  Future<PoseEngineInfo> start([
    PoseStartOptions options = const PoseStartOptions(),
  ]);

  Future<void> stop();

  /// Continuous stream of frames while running (15–30 Hz).
  Stream<PoseFrame> get frames;

  /// Swap the model without restarting the camera.
  Future<void> setModel(PoseModel model);

  Future<bool> hasCameraPermission();

  Future<bool> requestCameraPermission();

  /// Opens this app's page in the OS settings, so a user who denied the
  /// camera twice (Android then stops showing the dialog at all) has a way
  /// back. Returns false when the platform cannot do it, so the caller can
  /// leave the button out rather than offer a dead one.
  Future<bool> openAppSettings() async => false;

  bool get isRunning;

  /// Whether [previewViewType] can be embedded as a platform view.
  bool get supportsPreview;

  String get previewViewType => 'forma_pose/preview';
}
