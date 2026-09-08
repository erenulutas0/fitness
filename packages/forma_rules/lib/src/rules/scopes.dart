import 'dart:math' as math;

import '../features/feature_extractor.dart';
import '../geometry.dart';
import 'expression.dart';

/// Scope over a single frame: identifiers are scalar features, landmark
/// functions are computed from the frame's points.
class FrameScope implements EvalScope {
  const FrameScope(this.features);

  final FeatureSet features;

  @override
  EvalValue? variable(String name) {
    final v = features[name];
    if (v == null) return null;
    return EvalValue.scalar(v.value, confidence: v.confidence);
  }

  @override
  EvalValue? landmarkCall(String fn, List<String> landmarkNames) {
    final pts = <ResolvedPoint>[];
    for (final n in landmarkNames) {
      final p = features.point(n);
      if (p == null) return null;
      pts.add(p);
    }
    final conf = pts.map((p) => p.confidence).fold(1.0, math.min);
    switch (fn) {
      case 'angle':
        if (pts.length != 3) return null;
        return EvalValue.scalar(
          angleDeg2(pts[0].p, pts[1].p, pts[2].p),
          confidence: conf,
        );
      case 'dist':
        if (pts.length != 2) return null;
        return EvalValue.scalar(
          Vec2.distance(pts[0].p, pts[1].p),
          confidence: conf,
        );
      case 'dx':
        if (pts.length != 2) return null;
        return EvalValue.scalar(pts[1].p.x - pts[0].p.x, confidence: conf);
      case 'dy':
        if (pts.length != 2) return null;
        return EvalValue.scalar(pts[1].p.y - pts[0].p.y, confidence: conf);
    }
    return null;
  }
}

/// Scope over the frames of one rep: identifiers become series.
class SeriesScope implements EvalScope {
  SeriesScope(this.frames);

  final List<FeatureSet> frames;
  final Map<String, EvalValue> _cache = {};

  @override
  EvalValue? variable(String name) {
    final cached = _cache[name];
    if (cached != null) return cached;
    if (frames.isEmpty) return const EvalValue.series([], confidence: 0);
    final values = <double>[];
    var confSum = 0.0;
    for (final f in frames) {
      final v = f[name];
      if (v == null) return null;
      values.add(v.value);
      confSum += v.confidence;
    }
    final out = EvalValue.series(values, confidence: confSum / frames.length);
    _cache[name] = out;
    return out;
  }

  @override
  EvalValue? landmarkCall(String fn, List<String> landmarkNames) {
    final key = '$fn(${landmarkNames.join(',')})';
    final cached = _cache[key];
    if (cached != null) return cached;
    if (frames.isEmpty) return const EvalValue.series([], confidence: 0);
    final values = <double>[];
    var confSum = 0.0;
    for (final f in frames) {
      final v = FrameScope(f).landmarkCall(fn, landmarkNames);
      if (v == null) return null;
      values.add(v.scalar!);
      confSum += v.confidence;
    }
    final out = EvalValue.series(values, confidence: confSum / frames.length);
    _cache[key] = out;
    return out;
  }
}
