import 'dart:io';

import 'package:forma_rules/forma_rules.dart';
import 'package:test/test.dart';

ExerciseDefinition load(String id) => ExerciseDefinition.parse(
  File('../../content/exercises/$id.json').readAsStringSync(),
);

void main() {
  test('fixture JSON round-trips (coordinates rounded to 6 digits)', () {
    final frames = const SyntheticPose().squat(view: CameraView.side, reps: 2);
    final fx = LandmarkFixture(
      id: 'rt',
      exerciseId: 'bw_squat',
      view: CameraView.side,
      synthetic: true,
      expectedReps: 2,
      errorLabels: const [
        FixtureLabel(rep: 2, rules: ['shallow_depth']),
      ],
      frames: frames,
    );
    final back = LandmarkFixture.parse(fx.toJsonString());
    expect(back.frames.length, frames.length);
    expect(
      back.frames[5][PoseLandmark.leftKnee].x,
      closeTo(frames[5][PoseLandmark.leftKnee].x, 1e-6),
    );
    expect(
      back.frames[5].world(PoseLandmark.leftKnee)!.y,
      closeTo(frames[5].world(PoseLandmark.leftKnee)!.y, 1e-6),
    );
    expect(back.labeledRulesForRep(2), {'shallow_depth'});
    expect(back.labeledRuleCounts, {'shallow_depth': 1});
    expect(back.durationMs, fx.durationMs);
  });

  test('rebased() starts the recording at zero and keeps spacing', () {
    final frames = const SyntheticPose().squat(view: CameraView.side, reps: 1);
    final shifted = [for (final f in frames) f.shifted(1788870000000)];
    final fx = LandmarkFixture(
      id: 'rebase',
      exerciseId: 'bw_squat',
      view: CameraView.side,
      frames: shifted,
    ).rebased();
    expect(fx.frames.first.timestampMs, 0);
    expect(fx.durationMs, frames.last.timestampMs - frames.first.timestampMs);
    expect(fx.frames[3].timestampMs, frames[3].timestampMs);
  });

  test('PoseFrame.empty is serialisable and has no pose', () {
    final f = PoseFrame.fromJson(
      PoseFrame.empty(10, width: 640, height: 480).toJson(),
    );
    expect(f.hasPose, isFalse);
    expect(f.aspect, closeTo(640 / 480, 1e-9));
  });

  test(
    'replayer streams frames with shifted timestamps when looping',
    () async {
      final frames = const SyntheticPose().squat(
        view: CameraView.side,
        reps: 1,
        fps: 10,
      );
      final fx = LandmarkFixture(
        id: 's',
        exerciseId: 'bw_squat',
        view: CameraView.side,
        frames: frames,
      );
      final out = await FixtureReplayer(
        fx,
      ).stream(speed: 1000, loop: true).take(frames.length + 2).toList();
      expect(out.length, frames.length + 2);
      expect(
        out[frames.length].timestampMs,
        greaterThan(out[frames.length - 1].timestampMs),
      );
    },
  );

  group('golden replay of committed fixtures', () {
    final dir = Directory('test/fixtures');
    final files = dir.existsSync()
        ? (dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path)))
        : <File>[];

    test('fixtures exist (run `dart run tool/gen_fixtures.dart`)', () {
      expect(files, isNotEmpty);
    });

    for (final file in files) {
      test(file.uri.pathSegments.last, () {
        final fx = LandmarkFixture.parse(file.readAsStringSync());
        final def = load(fx.exerciseId);
        final session = ExerciseSession(
          definition: def,
          view: fx.view,
          config: const SessionConfig(smoothing: SmoothingConfig.none),
        );
        fx.frames.forEach(session.process);
        final result = session.finish();
        if (fx.expectedReps != null) {
          expect(result.repCount, fx.expectedReps, reason: 'rep count');
        }
        if (fx.expectedHoldMs != null) {
          expect(
            result.totalHoldMs,
            closeTo(fx.expectedHoldMs!, 150),
            reason: 'hold ms',
          );
        }
        // Every labeled error must be detected on that rep, and unlabeled
        // reps must be clean (synthetic fixtures are exact).
        for (var i = 0; i < result.reps.length; i++) {
          final rep = result.reps[i];
          expect(
            rep.failedRules.toSet(),
            fx.labeledRulesForRep(rep.index),
            reason: 'rep ${rep.index}',
          );
        }
        for (final h in result.holds) {
          expect(
            h.failedRules.toSet(),
            fx.labeledRulesForRep(h.index),
            reason: 'hold ${h.index}',
          );
        }
      });
    }
  });
}
