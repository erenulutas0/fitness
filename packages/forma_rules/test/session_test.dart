import 'dart:io';

import 'package:forma_rules/forma_rules.dart';
import 'package:test/test.dart';

ExerciseDefinition load(String id) => ExerciseDefinition.parse(
  File('../../content/exercises/$id.json').readAsStringSync(),
);

class Run {
  Run(this.session, this.events, this.result);

  final ExerciseSession session;
  final List<SessionEvent> events;
  final SetResult result;

  List<RepResult> get reps => result.reps;
  Set<String> ruleIds() => {
    for (final e in events.whereType<SessionRuleTriggered>()) e.rule.ruleId,
  };
  int count(String ruleId) => events
      .whereType<SessionRuleTriggered>()
      .where((e) => e.rule.ruleId == ruleId)
      .length;
}

Run run(
  ExerciseDefinition def,
  CameraView view,
  List<PoseFrame> frames, {
  SessionConfig? config,
}) {
  final s = ExerciseSession(
    definition: def,
    view: view,
    config: config ?? const SessionConfig(smoothing: SmoothingConfig.none),
  );
  final events = <SessionEvent>[];
  for (final f in frames) {
    events.addAll(s.process(f));
  }
  return Run(s, events, s.finish());
}

void main() {
  const syn = SyntheticPose();
  final squat = load('bw_squat');
  final pushUp = load('push_up');
  final plank = load('plank');
  final bridge = load('glute_bridge');

  group('bw_squat side view', () {
    test('5 clean reps → 5 reps, score 100, no corrections', () {
      final r = run(
        squat,
        CameraView.side,
        syn.squat(view: CameraView.side, reps: 5),
      );
      expect(r.reps.length, 5);
      expect(
        r.reps.every((x) => x.score.rounded == 100),
        isTrue,
        reason: r.reps.map((x) => x.score).toString(),
      );
      expect(r.ruleIds(), isEmpty);
      expect(r.result.formScore, 100);
      expect(r.result.errorCounts, isEmpty);
      final snap = r.session.snapshot;
      expect(snap.repCount, 5);
      expect(snap.tracking, isTrue);
    });

    test('shallow reps are counted but flagged (D13)', () {
      final r = run(
        squat,
        CameraView.side,
        syn.squat(view: CameraView.side, reps: 4, peakAngle: 118),
      );
      expect(r.reps.length, 4);
      expect(r.count('shallow_depth'), 4);
      expect(r.reps.first.failedRules, ['shallow_depth']);
      expect(r.reps.first.score.rounded, 70);
      expect(r.reps.first.ruleResults['shallow_depth']!.value, 1.0);
      expect(r.reps.first.summary.extremeValue, closeTo(118, 2));
    });

    test('forward lean triggers torso_lean at rep end', () {
      final r = run(
        squat,
        CameraView.side,
        syn.squat(view: CameraView.side, reps: 3, extraTorsoLeanDeg: 35),
      );
      expect(r.reps.length, 3);
      expect(r.count('torso_lean'), 3);
      expect(r.reps.first.score.rounded, 80);
    });

    test('heel rise fires live during the rep and is scored', () {
      final r = run(
        squat,
        CameraView.side,
        syn.squat(view: CameraView.side, reps: 3, heelRise: 0.08),
      );
      expect(r.reps.length, 3);
      expect(r.count('heel_rise'), greaterThanOrEqualTo(3));
      // live cue arrives before the rep completes
      final firstRule = r.events.indexWhere((e) => e is SessionRuleTriggered);
      final firstRep = r.events.indexWhere((e) => e is SessionRepCompleted);
      expect(firstRule, lessThan(firstRep));
      expect(r.reps.every((x) => x.failedRules.contains('heel_rise')), isTrue);
    });

    test('noisy input with smoothing still counts every rep', () {
      final r = run(
        squat,
        CameraView.side,
        syn.squat(view: CameraView.side, reps: 6, noiseStd: 0.006, seed: 5),
        config: const SessionConfig(),
      );
      expect(r.reps.length, 6);
      expect(r.result.formScore, greaterThan(90));
    });

    test(
      'frames without a person freeze the session and report tracking loss',
      () {
        final frames = syn.squat(view: CameraView.side, reps: 2);
        final withGap = <PoseFrame>[
          ...frames.take(20),
          for (var i = 0; i < 15; i++)
            PoseFrame.empty(frames[19].timestampMs + 33 * (i + 1)),
          ...frames.skip(20),
        ];
        final r = run(squat, CameraView.side, withGap);
        final tracking = r.events.whereType<SessionTrackingChanged>().toList();
        expect(tracking.length, 3); // gained, lost, regained
        expect(tracking[1].tracking, isFalse);
        expect(r.reps.length, 2);
      },
    );
  });

  group('tracking loss', () {
    test('a rep interrupted mid-way is not counted when tracking returns', () {
      // Device bug (2026-09-08): the FSM stayed in `peak` while the user was
      // out of frame and completed the rep on their return.
      final frames = syn.squat(view: CameraView.side, reps: 2);
      // Blank the frames around the first bottom position.
      final withGap = <PoseFrame>[
        for (var i = 0; i < frames.length; i++)
          if (i >= 40 && i < 70)
            PoseFrame.empty(frames[i].timestampMs)
          else
            frames[i],
      ];
      final r = run(squat, CameraView.side, withGap);
      expect(r.reps.length, 1, reason: 'only the untouched second rep counts');
      expect(r.reps.single.index, 1);
      final snap = r.session.snapshot;
      expect(snap.signalValue, isNotNull);
    });

    test('snapshot hides stale signal and tempo while out of frame', () {
      final frames = syn.squat(view: CameraView.side, reps: 1);
      final withTail = <PoseFrame>[
        ...frames,
        for (var i = 1; i <= 20; i++)
          PoseFrame.empty(frames.last.timestampMs + 33 * i),
      ];
      final r = run(squat, CameraView.side, withTail);
      final snap = r.session.snapshot;
      expect(snap.tracking, isFalse);
      expect(snap.signalValue, isNull);
      expect(snap.currentRepElapsedMs, isNull);
      expect(snap.repCount, 1);
    });

    test('a hold stops accruing time once the person leaves the frame', () {
      final frames = syn.plank(durationMs: 10000);
      final withTail = <PoseFrame>[
        ...frames,
        for (var i = 1; i <= 90; i++)
          PoseFrame.empty(frames.last.timestampMs + 33 * i),
      ];
      final r = run(plank, CameraView.side, withTail);
      expect(r.result.holds.length, 1);
      expect(r.result.holds.single.heldMs, closeTo(10000, 150));
    });
  });

  group('bw_squat front view', () {
    test('clean reps count via 3D knee angle', () {
      final r = run(
        squat,
        CameraView.front,
        syn.squat(view: CameraView.front, reps: 5),
      );
      expect(r.reps.length, 5);
      expect(r.ruleIds(), isEmpty);
    });

    test('knee valgus fires live and fails the rep', () {
      final r = run(
        squat,
        CameraView.front,
        syn.squat(view: CameraView.front, reps: 4, valgus: 0.3),
      );
      expect(r.reps.length, 4);
      expect(r.count('knee_valgus'), greaterThanOrEqualTo(4));
      expect(
        r.reps.every((x) => x.failedRules.contains('knee_valgus')),
        isTrue,
      );
      expect(r.reps.first.score.rounded, 60);
      expect(
        r.reps.first.ruleResults['knee_valgus']!.fraction,
        greaterThan(0.3),
      );
    });

    test('mild valgus below threshold stays silent (no false positive)', () {
      final r = run(
        squat,
        CameraView.front,
        syn.squat(view: CameraView.front, reps: 4, valgus: 0.08),
      );
      expect(r.reps.length, 4);
      expect(r.count('knee_valgus'), 0);
    });
  });

  group('push_up', () {
    test('clean reps', () {
      final r = run(pushUp, CameraView.side, syn.pushUp(reps: 5));
      expect(r.reps.length, 5);
      expect(r.ruleIds(), isEmpty);
    });

    test('sagging hips trigger hip_sag, piked hips trigger hip_pike', () {
      final sag = run(
        pushUp,
        CameraView.side,
        syn.pushUp(reps: 3, hipSag: 0.1),
      );
      expect(sag.reps.length, 3);
      expect(sag.ruleIds(), contains('hip_sag'));
      expect(sag.ruleIds(), isNot(contains('hip_pike')));
      final pike = run(
        pushUp,
        CameraView.side,
        syn.pushUp(reps: 3, hipSag: -0.12),
      );
      expect(pike.ruleIds(), contains('hip_pike'));
      expect(pike.ruleIds(), isNot(contains('hip_sag')));
    });

    test('half reps trigger shallow_depth', () {
      final r = run(
        pushUp,
        CameraView.side,
        syn.pushUp(reps: 3, peakAngle: 110),
      );
      expect(r.reps.length, 3);
      expect(r.count('shallow_depth'), 3);
    });
  });

  group('plank (hold)', () {
    test('a clean 20 s plank is one hold with score 100', () {
      final r = run(plank, CameraView.side, syn.plank(durationMs: 20000));
      expect(r.events.whereType<SessionHoldStarted>().length, 1);
      expect(r.result.holds.length, 1);
      expect(r.result.holds.single.heldMs, closeTo(20000, 100));
      expect(r.result.holds.single.score.rounded, 100);
      expect(r.events.whereType<SessionHoldProgress>().length, greaterThan(15));
    });

    test('sagging plank fires hip_sag repeatedly (refire) and scores 60', () {
      final r = run(
        plank,
        CameraView.side,
        syn.plank(durationMs: 20000, hipSag: 0.1),
      );
      expect(r.count('hip_sag'), greaterThanOrEqualTo(3));
      expect(r.result.holds.single.score.rounded, 60);
      expect(r.result.holds.single.failedRules, ['hip_sag']);
    });

    test('head drop is a minor penalty', () {
      final r = run(
        plank,
        CameraView.side,
        syn.plank(durationMs: 10000, headDropDeg: 45),
      );
      expect(r.result.holds.single.failedRules, ['head_drop']);
      expect(r.result.holds.single.score.rounded, 85);
    });
  });

  group('glute_bridge', () {
    test('full extension counts clean', () {
      final r = run(bridge, CameraView.side, syn.gluteBridge(reps: 5));
      expect(r.reps.length, 5);
      expect(r.ruleIds(), isEmpty);
    });

    test('partial extension is counted but flagged', () {
      final r = run(
        bridge,
        CameraView.side,
        syn.gluteBridge(reps: 4, peakAngle: 158),
      );
      expect(r.reps.length, 4);
      expect(r.count('insufficient_extension'), 4);
      expect(r.reps.first.score.rounded, 70);
    });
  });

  test('SetResult JSON is serialisable', () {
    final r = run(
      squat,
      CameraView.front,
      syn.squat(view: CameraView.front, reps: 2, valgus: 0.3),
    );
    final json = r.result.toJson();
    expect(json['exerciseId'], 'bw_squat');
    expect((json['reps'] as List).length, 2);
    expect((json['errorCounts'] as Map)['knee_valgus'], 2);
  });

  test('gestures: hands up fires after the hold time', () {
    final def = squat;
    final s = ExerciseSession(
      definition: def,
      view: CameraView.front,
      config: const SessionConfig(
        smoothing: SmoothingConfig.none,
        detectGestures: true,
        gestures: GestureConfig(holdMs: 1000),
      ),
    );
    const builder = SkeletonBuilder();
    final proj = SkeletonProjector(view: CameraView.front);
    final standing = builder.squat(kneeAngleDeg: 175);
    // raise both wrists above the head
    final handsUp = Map<PoseLandmark, Vec3>.from(standing)
      ..[PoseLandmark.leftWrist] =
          standing[PoseLandmark.nose]! + const Vec3(0.2, 0.25, 0)
      ..[PoseLandmark.rightWrist] =
          standing[PoseLandmark.nose]! + const Vec3(-0.2, 0.25, 0);
    final gestures = <Gesture>[];
    for (var t = 0; t <= 2500; t += 33) {
      final sk = t < 500 ? standing : handsUp;
      for (final e in s.process(proj.project(sk, tMs: t))) {
        if (e is SessionGesture) gestures.add(e.gesture);
      }
    }
    expect(gestures, [Gesture.handsUp]);
  });
}
