import 'dart:math' as math;

import 'package:forma_rules/forma_rules.dart';
import 'package:test/test.dart';

void main() {
  test('constant input passes through unchanged', () {
    final f = OneEuroFilter(minCutoff: 1, beta: 0.1);
    for (var t = 0; t < 1000; t += 33) {
      expect(f.filter(0.42, t), closeTo(0.42, 1e-12));
    }
  });

  test('reduces high-frequency noise on a slow signal', () {
    final rng = math.Random(3);
    final f = OneEuroFilter(minCutoff: 1, beta: 0.02);
    var rawErr = 0.0;
    var filtErr = 0.0;
    var n = 0;
    for (var t = 0; t < 20000; t += 33) {
      final clean = math.sin(t / 1000 * 2 * math.pi * 0.05);
      final noisy = clean + (rng.nextDouble() - 0.5) * 0.8;
      final out = f.filter(noisy, t);
      if (t > 1000) {
        rawErr += (noisy - clean).abs();
        filtErr += (out - clean).abs();
        n++;
      }
    }
    expect(filtErr / n, lessThan(rawErr / n * 0.6));
  });

  test('follows fast motion with beta > 0', () {
    final slow = OneEuroFilter(minCutoff: 0.5);
    final fast = OneEuroFilter(minCutoff: 0.5, beta: 1);
    double lagSlow = 0;
    double lagFast = 0;
    for (var t = 0; t <= 2000; t += 33) {
      final x = t < 1000 ? 0.0 : 1.0; // step at 1 s
      final a = slow.filter(x, t);
      final b = fast.filter(x, t);
      if (t > 1000) {
        lagSlow += (x - a).abs();
        lagFast += (x - b).abs();
      }
    }
    expect(lagFast, lessThan(lagSlow));
  });

  test('LandmarkSmoother keeps visibility and resets after a gap', () {
    final smoother = LandmarkSmoother(
      const SmoothingConfig(minCutoff: 1, beta: 0.1, resetAfterGapMs: 500),
    );
    final frames = const SyntheticPose().squat(view: CameraView.side, reps: 1);
    final a = smoother.smooth(frames[0]);
    expect(a[PoseLandmark.leftKnee].visibility, 1);
    // First frame passes through untouched.
    expect(a[PoseLandmark.leftKnee].x, frames[0][PoseLandmark.leftKnee].x);
    smoother.smooth(frames[1]);
    // A long gap resets, so the next frame passes through untouched again.
    final late = frames[10].copyWith();
    final shifted = PoseFrame(
      timestampMs: frames[1].timestampMs + 5000,
      landmarks: late.landmarks,
      worldLandmarks: late.worldLandmarks,
      width: late.width,
      height: late.height,
    );
    final out = smoother.smooth(shifted);
    expect(out[PoseLandmark.leftKnee].y, shifted[PoseLandmark.leftKnee].y);
  });

  test('SmoothingConfig.none is a no-op', () {
    final smoother = LandmarkSmoother(SmoothingConfig.none);
    final frames = const SyntheticPose().squat(
      view: CameraView.side,
      reps: 1,
      noiseStd: 0.01,
    );
    for (final f in frames) {
      expect(identical(smoother.smooth(f), f), isTrue);
    }
  });
}
