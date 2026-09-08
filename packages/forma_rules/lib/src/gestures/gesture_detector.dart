import '../features/feature_extractor.dart';

/// Hands-free control gestures (docs/03 idea 13, decision D15).
enum Gesture {
  /// Both wrists above the head: start / next set.
  handsUp,

  /// Arms straight out to the sides: finish the set.
  tPose,

  /// One wrist above the head: pause / resume.
  oneHandUp,
}

class GestureConfig {
  const GestureConfig({
    this.holdMs = 1500,
    this.cooldownMs = 3000,
    this.minConfidence = 0.5,
    this.aboveHeadThreshold = 0.15,
    this.tPoseSpread = 2.2,
    this.tPoseLevelTolerance = 0.2,
  });

  /// How long a pose must be held before the gesture fires.
  final int holdMs;

  /// Minimum time between two fired gestures.
  final int cooldownMs;
  final double minConfidence;

  /// `wrist_head_dy` (normalized by torso length) above which a wrist counts
  /// as "above the head".
  final double aboveHeadThreshold;

  /// `arm_spread_ratio` (wrist distance / shoulder width) for a T-pose.
  final double tPoseSpread;

  /// Max |wrist_shoulder_dy| for a T-pose.
  final double tPoseLevelTolerance;
}

/// Detects held body gestures from features. Call [update] every frame.
class GestureDetector {
  GestureDetector([this.config = const GestureConfig()]);

  final GestureConfig config;

  Gesture? _candidate;
  int? _since;
  int _lastFiredMs = -1 << 30;

  /// The gesture currently being held (not yet fired), if any.
  Gesture? get candidate => _candidate;

  /// 0..1 progress toward firing the current candidate.
  double progress(int nowMs) {
    final s = _since;
    if (s == null || _candidate == null) return 0;
    return ((nowMs - s) / config.holdMs).clamp(0.0, 1.0);
  }

  /// Returns a gesture when it has been held for [GestureConfig.holdMs].
  Gesture? update(FeatureSet fs, int tMs) {
    final g = classify(fs);
    if (g == null || g != _candidate) {
      _candidate = g;
      _since = g == null ? null : tMs;
      return null;
    }
    if (tMs - _since! >= config.holdMs &&
        tMs - _lastFiredMs >= config.cooldownMs) {
      _lastFiredMs = tMs;
      _since = tMs; // require a fresh hold for the next fire
      return g;
    }
    return null;
  }

  /// Instantaneous classification (no hold requirement).
  Gesture? classify(FeatureSet fs) {
    final l = fs['wrist_head_dy_l'];
    final r = fs['wrist_head_dy_r'];
    if (l == null || r == null) return null;
    if (l.confidence < config.minConfidence ||
        r.confidence < config.minConfidence) {
      return null;
    }
    final lUp = l.value > config.aboveHeadThreshold;
    final rUp = r.value > config.aboveHeadThreshold;
    if (lUp && rUp) return Gesture.handsUp;

    final spread = fs['arm_spread_ratio'];
    final ls = fs['wrist_shoulder_dy_l'];
    final rs = fs['wrist_shoulder_dy_r'];
    if (spread != null &&
        ls != null &&
        rs != null &&
        spread.confidence >= config.minConfidence &&
        spread.value >= config.tPoseSpread &&
        ls.value.abs() <= config.tPoseLevelTolerance &&
        rs.value.abs() <= config.tPoseLevelTolerance &&
        !lUp &&
        !rUp) {
      return Gesture.tPose;
    }

    if (lUp != rUp) {
      final other = lUp ? r.value : l.value;
      if (other < 0) return Gesture.oneHandUp;
    }
    return null;
  }

  void reset() {
    _candidate = null;
    _since = null;
  }
}
