import 'dart:math' as math;

import '../geometry.dart';
import '../landmarks.dart';
import '../pose_frame.dart';

/// One Euro filter (Casiez et al., 2012): low-latency smoothing whose cutoff
/// rises with speed, so slow jitter is removed while fast motion stays sharp.
class OneEuroFilter {
  OneEuroFilter({this.minCutoff = 1.0, this.beta = 0.0, this.dCutoff = 1.0});

  /// Minimum cutoff frequency (Hz). Lower = smoother at rest.
  final double minCutoff;

  /// Speed coefficient. Higher = less lag during fast motion.
  final double beta;

  /// Cutoff for the derivative estimate (Hz).
  final double dCutoff;

  double? _xPrev;
  double _dxPrev = 0;
  int? _tPrevMs;

  bool get isInitialized => _xPrev != null;

  double filter(double x, int tMs) {
    final xPrev = _xPrev;
    final tPrev = _tPrevMs;
    if (xPrev == null || tPrev == null) {
      _xPrev = x;
      _tPrevMs = tMs;
      return x;
    }
    final dt = (tMs - tPrev) / 1000.0;
    if (dt <= 0) return xPrev;
    final dx = (x - xPrev) / dt;
    final edx = _lowpass(dx, _dxPrev, _alpha(dCutoff, dt));
    final cutoff = minCutoff + beta * edx.abs();
    final xf = _lowpass(x, xPrev, _alpha(cutoff, dt));
    _xPrev = xf;
    _dxPrev = edx;
    _tPrevMs = tMs;
    return xf;
  }

  void reset() {
    _xPrev = null;
    _dxPrev = 0;
    _tPrevMs = null;
  }

  static double _alpha(double cutoff, double dt) {
    final tau = 1 / (2 * math.pi * cutoff);
    return 1 / (1 + tau / dt);
  }

  static double _lowpass(double x, double prev, double a) =>
      a * x + (1 - a) * prev;
}

/// Smoothing parameters for [LandmarkSmoother].
class SmoothingConfig {
  const SmoothingConfig({
    this.minCutoff = 1.5,
    this.beta = 0.1,
    this.dCutoff = 1.0,
    this.resetAfterGapMs = 700,
  });

  /// No smoothing at all (useful for tests / synthetic input).
  static const none = SmoothingConfig(minCutoff: double.infinity);

  final double minCutoff;
  final double beta;
  final double dCutoff;

  /// If frames stop for longer than this, the filters restart from scratch.
  final int resetAfterGapMs;

  bool get isDisabled => minCutoff == double.infinity;
}

/// Applies a One Euro filter to x, y, z of every landmark (and every world
/// landmark). Visibility / presence pass through untouched.
class LandmarkSmoother {
  LandmarkSmoother([this.config = const SmoothingConfig()])
    : _img = List.generate(PoseLandmark.count * 3, (_) => _make(config)),
      _world = List.generate(PoseLandmark.count * 3, (_) => _make(config));

  final SmoothingConfig config;
  final List<OneEuroFilter> _img;
  final List<OneEuroFilter> _world;
  int? _lastTs;

  static OneEuroFilter _make(SmoothingConfig c) =>
      OneEuroFilter(minCutoff: c.minCutoff, beta: c.beta, dCutoff: c.dCutoff);

  PoseFrame smooth(PoseFrame f) {
    if (config.isDisabled || !f.hasPose) return f;
    final last = _lastTs;
    if (last != null && f.timestampMs - last > config.resetAfterGapMs) reset();
    _lastTs = f.timestampMs;

    final t = f.timestampMs;
    final lms = List<Landmark>.generate(PoseLandmark.count, (i) {
      final l = f.landmarks[i];
      if (l.visibility <= 0 && l.presence <= 0) return l;
      return l.copyWith(
        x: _img[i * 3].filter(l.x, t),
        y: _img[i * 3 + 1].filter(l.y, t),
        z: _img[i * 3 + 2].filter(l.z, t),
      );
    });
    List<Vec3>? world;
    final w = f.worldLandmarks;
    if (w != null) {
      world = List<Vec3>.generate(
        PoseLandmark.count,
        (i) => Vec3(
          _world[i * 3].filter(w[i].x, t),
          _world[i * 3 + 1].filter(w[i].y, t),
          _world[i * 3 + 2].filter(w[i].z, t),
        ),
      );
    }
    return f.copyWith(landmarks: lms, worldLandmarks: world);
  }

  void reset() {
    for (final f in _img) {
      f.reset();
    }
    for (final f in _world) {
      f.reset();
    }
    _lastTs = null;
  }
}
