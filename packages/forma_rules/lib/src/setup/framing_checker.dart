import '../features/feature_extractor.dart';

/// What the camera-setup assistant should tell the user.
enum FramingStatus {
  /// Nobody detected.
  noPose,

  /// Detected but core landmarks are not trustworthy.
  lowConfidence,

  /// Body fills the frame or touches the top/bottom edge: step back.
  tooClose,

  /// Body too small in the frame: come closer.
  tooFar,

  /// Body touches the left image edge: move toward image right.
  moveTowardImageRight,

  /// Body touches the right image edge: move toward image left.
  moveTowardImageLeft,

  /// Framed well.
  ok,
}

/// Camera view detected from body proportions.
enum DetectedView { front, side, unknown }

class FramingResult {
  const FramingResult({
    required this.status,
    required this.detectedView,
    required this.bodyHeightFraction,
    required this.confidence,
    required this.brightnessOk,
  });

  final FramingStatus status;
  final DetectedView detectedView;

  /// Bounding-box height as a fraction of the image height.
  final double bodyHeightFraction;
  final double confidence;
  final bool brightnessOk;

  bool get isReady => status == FramingStatus.ok && brightnessOk;
}

/// Decides whether the user is framed well enough to start (docs/06 §4.2).
class FramingChecker {
  const FramingChecker({
    this.minHeightFraction = 0.55,
    this.maxHeightFraction = 0.95,
    this.edgeMargin = 0.03,
    this.minConfidence = 0.5,
    this.minBrightness = 0.18,
    this.frontRatio = 0.45,
    this.sideRatio = 0.25,
  });

  final double minHeightFraction;
  final double maxHeightFraction;
  final double edgeMargin;
  final double minConfidence;

  /// Mean luma below this is "too dark" (only if the engine reports it).
  final double minBrightness;

  /// `shoulder_width_ratio` above this = front view, below [sideRatio] = side.
  final double frontRatio;
  final double sideRatio;

  FramingResult check(FeatureSet fs) {
    final frame = fs.frame;
    final b = frame.brightness;
    final brightnessOk = b == null || b >= minBrightness;
    if (!frame.hasPose) {
      return FramingResult(
        status: FramingStatus.noPose,
        detectedView: DetectedView.unknown,
        bodyHeightFraction: 0,
        confidence: 0,
        brightnessOk: brightnessOk,
      );
    }
    final conf = fs.value('vis_core') ?? 0;
    final height = fs.value('bbox_height') ?? 0;
    final yMin = fs.value('bbox_y_min') ?? 0;
    final yMax = fs.value('bbox_y_max') ?? 1;
    final xMin = fs.value('bbox_x_min') ?? 0;
    final xMax = fs.value('bbox_x_max') ?? 1;
    final ratio = fs.value('shoulder_width_ratio') ?? 0;
    final view = ratio >= frontRatio
        ? DetectedView.front
        : (ratio <= sideRatio ? DetectedView.side : DetectedView.unknown);

    FramingStatus status;
    if (conf < minConfidence) {
      // Often the body is partly cut off; edges tell which way to go.
      if (yMin <= edgeMargin || yMax >= 1 - edgeMargin) {
        status = FramingStatus.tooClose;
      } else {
        status = FramingStatus.lowConfidence;
      }
    } else if (yMin <= edgeMargin ||
        yMax >= 1 - edgeMargin ||
        height > maxHeightFraction) {
      status = FramingStatus.tooClose;
    } else if (height < minHeightFraction) {
      status = FramingStatus.tooFar;
    } else if (xMin <= edgeMargin) {
      status = FramingStatus.moveTowardImageRight;
    } else if (xMax >= 1 - edgeMargin) {
      status = FramingStatus.moveTowardImageLeft;
    } else {
      status = FramingStatus.ok;
    }
    return FramingResult(
      status: status,
      detectedView: view,
      bodyHeightFraction: height,
      confidence: conf,
      brightnessOk: brightnessOk,
    );
  }
}
