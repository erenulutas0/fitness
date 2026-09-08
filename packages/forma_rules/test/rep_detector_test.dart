import 'dart:math' as math;

import 'package:forma_rules/forma_rules.dart';
import 'package:test/test.dart';

List<RepEvent> run(RepDetector d, Iterable<(int, double)> signal) {
  final out = <RepEvent>[];
  for (final (t, v) in signal) {
    out.addAll(d.update(v, t));
  }
  return out;
}

void main() {
  const squat = RepConfig(
    restThreshold: 155,
    peakThreshold: 125,
    hysteresis: 8,
    minDurationMs: 700,
  );

  test('counts clean half-cosine reps exactly once each', () {
    final d = RepDetector(squat);
    final events = run(
      d,
      SyntheticPose.repProfile(reps: 8, restValue: 172, peakValue: 90),
    );
    expect(d.count, 8);
    expect(events.whereType<RepCompleted>().length, 8);
    expect(events.whereType<RepRejected>(), isEmpty);
    final first = events.whereType<RepCompleted>().first.summary;
    expect(first.index, 1);
    expect(first.extremeValue, closeTo(90, 1.5));
    expect(first.toPeakMs, greaterThan(500));
    expect(first.toRestMs, greaterThan(500));
  });

  test('noise around a threshold does not double count (hysteresis)', () {
    final d = RepDetector(squat);
    final rng = math.Random(11);
    final noisy = [
      for (final (t, v) in SyntheticPose.repProfile(
        reps: 6,
        restValue: 172,
        peakValue: 90,
      ))
        (t, v + (rng.nextDouble() - 0.5) * 6),
    ];
    run(d, noisy);
    expect(d.count, 6);
  });

  test('shallow movement that never reaches the peak zone is not a rep', () {
    final d = RepDetector(squat);
    run(d, SyntheticPose.repProfile(reps: 4, restValue: 172, peakValue: 135));
    expect(d.count, 0);
    expect(d.phase, RepPhase.rest);
  });

  test('too-fast reps are rejected', () {
    final d = RepDetector(squat);
    final events = run(
      d,
      SyntheticPose.repProfile(
        reps: 3,
        restValue: 172,
        peakValue: 90,
        periodMs: 400,
        pauseMs: 300,
      ),
    );
    expect(d.count, 0);
    expect(events.whereType<RepRejected>().length, 3);
    expect(
      events.whereType<RepRejected>().first.reason,
      RepRejectReason.tooFast,
    );
  });

  test('too-slow reps are rejected when maxDurationMs is set', () {
    final d = RepDetector(
      const RepConfig(
        restThreshold: 155,
        peakThreshold: 125,
        hysteresis: 8,
        minDurationMs: 700,
        maxDurationMs: 3000,
      ),
    );
    final events = run(
      d,
      SyntheticPose.repProfile(
        reps: 2,
        restValue: 172,
        peakValue: 90,
        periodMs: 6000,
      ),
    );
    expect(d.count, 0);
    expect(
      events.whereType<RepRejected>().every(
        (e) => e.reason == RepRejectReason.tooSlow,
      ),
      isTrue,
    );
  });

  test('increasing signals (glute bridge) work the same way', () {
    final d = RepDetector(
      const RepConfig(
        restThreshold: 135,
        peakThreshold: 155,
        hysteresis: 5,
        minDurationMs: 600,
      ),
    );
    run(d, SyntheticPose.repProfile(reps: 5, restValue: 118, peakValue: 178));
    expect(d.count, 5);
  });

  test('phase sequence is rest → toPeak → peak → toRest → rest', () {
    final d = RepDetector(squat);
    final events = run(
      d,
      SyntheticPose.repProfile(reps: 1, restValue: 172, peakValue: 90),
    );
    final phases = events.whereType<PhaseChanged>().map((e) => e.to).toList();
    expect(phases, [
      RepPhase.toPeak,
      RepPhase.peak,
      RepPhase.toRest,
      RepPhase.rest,
    ]);
  });

  test('HoldDetector accumulates and tolerates short dropouts', () {
    final h = HoldDetector(const HoldConfig(minHoldMs: 1000, exitGraceMs: 500));
    final events = <HoldEvent>[];
    for (var t = 0; t <= 6000; t += 33) {
      // 200 ms dropout at 2 s should not end the hold
      final ok = t >= 300 && !(t >= 2000 && t < 2200) && t < 4500;
      events.addAll(h.update(ok, t));
    }
    expect(events.whereType<HoldStarted>().length, 1);
    final ended = events.whereType<HoldEnded>().single;
    expect(ended.heldMs, closeTo(4200, 80));
    expect(events.whereType<HoldProgress>().length, greaterThanOrEqualTo(3));
  });

  test('HoldDetector drops holds shorter than minHoldMs', () {
    final h = HoldDetector(const HoldConfig(minHoldMs: 1000, exitGraceMs: 200));
    final events = <HoldEvent>[];
    for (var t = 0; t <= 3000; t += 33) {
      events.addAll(h.update(t >= 500 && t < 900, t));
    }
    expect(events.whereType<HoldEnded>(), isEmpty);
  });
}
