import 'dart:io';

import 'package:forma_rules/forma_rules.dart';
import 'package:test/test.dart';

/// docs/10 Prompt 4: < 2 ms per frame at 30 Hz on a laptop; on a phone the
/// budget is looser but the whole Dart side must stay far below the 33 ms
/// frame period.
void main() {
  test('full pipeline stays under 2 ms per frame (average)', () {
    final def = ExerciseDefinition.parse(
      File('../../content/exercises/bw_squat.json').readAsStringSync(),
    );
    final frames = const SyntheticPose().squat(
      view: CameraView.front,
      reps: 20,
      valgus: 0.3,
      noiseStd: 0.004,
    );
    final session = ExerciseSession(definition: def, view: CameraView.front);
    final scheduler = FeedbackScheduler(
      catalog: CueCatalog.parse(
        File('../../content/cues/cues.json').readAsStringSync(),
      ),
    );
    // warm-up
    for (final f in frames.take(60)) {
      scheduler.handle(session.process(f), nowMs: f.timestampMs);
    }
    final sw = Stopwatch()..start();
    for (final f in frames.skip(60)) {
      scheduler.handle(session.process(f), nowMs: f.timestampMs);
    }
    sw.stop();
    final perFrameUs = sw.elapsedMicroseconds / (frames.length - 60);
    stdout.writeln(
      'pipeline: ${perFrameUs.toStringAsFixed(0)} µs/frame over ${frames.length - 60} frames',
    );
    expect(session.reps.length, 20);
    expect(perFrameUs, lessThan(2000));
  });
}
