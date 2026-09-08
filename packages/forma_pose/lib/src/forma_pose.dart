import 'package:forma_rules/forma_rules.dart';

import 'forma_pose_platform_interface.dart';

/// Facade over [FormaPosePlatform.instance] (docs/05 §8).
///
/// ```dart
/// final info = await FormaPose.start(const PoseStartOptions(lens: CameraLens.front));
/// FormaPose.frames.listen(session.process);
/// ```
abstract final class FormaPose {
  static FormaPosePlatform get platform => FormaPosePlatform.instance;

  /// The active engine (same as [platform]).
  static FormaPosePlatform get engine => FormaPosePlatform.instance;

  /// Replace the engine (e.g. with `FakeFormaPose` in tests / desktop).
  static set engine(FormaPosePlatform engine) =>
      FormaPosePlatform.instance = engine;

  static Future<PoseEngineInfo> start([
    PoseStartOptions options = const PoseStartOptions(),
  ]) => platform.start(options);

  static Future<void> stop() => platform.stop();

  static Stream<PoseFrame> get frames => platform.frames;

  static Future<void> setModel(PoseModel model) => platform.setModel(model);

  static Future<bool> hasCameraPermission() => platform.hasCameraPermission();

  static Future<bool> requestCameraPermission() =>
      platform.requestCameraPermission();

  static bool get isRunning => platform.isRunning;

  static bool get supportsPreview => platform.supportsPreview;
}
