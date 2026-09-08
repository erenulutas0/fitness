// Generates the synthetic golden fixtures under test/fixtures/.
//
// Run from packages/forma_rules:  dart run tool/gen_fixtures.dart
import 'dart:io';

import 'package:forma_rules/forma_rules.dart';

void main() {
  const syn = SyntheticPose();
  final out = Directory('test/fixtures')..createSync(recursive: true);

  List<FixtureLabel> allReps(int reps, List<String> rules) => [
    for (var i = 1; i <= reps; i++) FixtureLabel(rep: i, rules: rules),
  ];

  final fixtures = <LandmarkFixture>[
    LandmarkFixture(
      id: 'syn_squat_side_clean',
      exerciseId: 'bw_squat',
      view: CameraView.side,
      synthetic: true,
      expectedReps: 5,
      frames: syn.squat(view: CameraView.side, reps: 5),
      notes: 'clean half-cosine squats, 90° bottom',
    ),
    LandmarkFixture(
      id: 'syn_squat_side_noisy',
      exerciseId: 'bw_squat',
      view: CameraView.side,
      synthetic: true,
      expectedReps: 5,
      frames: syn.squat(
        view: CameraView.side,
        reps: 5,
        noiseStd: 0.004,
        seed: 9,
      ),
      notes: 'gaussian landmark noise std 0.004',
    ),
    LandmarkFixture(
      id: 'syn_squat_side_shallow',
      exerciseId: 'bw_squat',
      view: CameraView.side,
      synthetic: true,
      expectedReps: 4,
      errorLabels: allReps(4, ['shallow_depth']),
      frames: syn.squat(view: CameraView.side, reps: 4, peakAngle: 118),
    ),
    LandmarkFixture(
      id: 'syn_squat_side_lean_heels',
      exerciseId: 'bw_squat',
      view: CameraView.side,
      synthetic: true,
      expectedReps: 3,
      errorLabels: allReps(3, ['torso_lean', 'heel_rise']),
      frames: syn.squat(
        view: CameraView.side,
        reps: 3,
        extraTorsoLeanDeg: 35,
        heelRise: 0.08,
      ),
    ),
    LandmarkFixture(
      id: 'syn_squat_front_clean',
      exerciseId: 'bw_squat',
      view: CameraView.front,
      synthetic: true,
      expectedReps: 5,
      frames: syn.squat(view: CameraView.front, reps: 5),
    ),
    LandmarkFixture(
      id: 'syn_squat_front_valgus',
      exerciseId: 'bw_squat',
      view: CameraView.front,
      synthetic: true,
      expectedReps: 4,
      errorLabels: allReps(4, ['knee_valgus']),
      frames: syn.squat(view: CameraView.front, reps: 4, valgus: 0.3),
    ),
    LandmarkFixture(
      id: 'syn_pushup_clean',
      exerciseId: 'push_up',
      view: CameraView.side,
      synthetic: true,
      expectedReps: 5,
      frames: syn.pushUp(reps: 5),
    ),
    LandmarkFixture(
      id: 'syn_pushup_sag',
      exerciseId: 'push_up',
      view: CameraView.side,
      synthetic: true,
      expectedReps: 3,
      errorLabels: allReps(3, ['hip_sag']),
      frames: syn.pushUp(reps: 3, hipSag: 0.1),
    ),
    LandmarkFixture(
      id: 'syn_plank_clean',
      exerciseId: 'plank',
      view: CameraView.side,
      synthetic: true,
      expectedHoldMs: 15000,
      frames: syn.plank(durationMs: 15000),
    ),
    LandmarkFixture(
      id: 'syn_plank_sag',
      exerciseId: 'plank',
      view: CameraView.side,
      synthetic: true,
      expectedHoldMs: 15000,
      errorLabels: const [
        FixtureLabel(rep: 1, rules: ['hip_sag']),
      ],
      frames: syn.plank(durationMs: 15000, hipSag: 0.1),
    ),
    LandmarkFixture(
      id: 'syn_bridge_clean',
      exerciseId: 'glute_bridge',
      view: CameraView.side,
      synthetic: true,
      expectedReps: 5,
      frames: syn.gluteBridge(reps: 5),
    ),
    LandmarkFixture(
      id: 'syn_bridge_partial',
      exerciseId: 'glute_bridge',
      view: CameraView.side,
      synthetic: true,
      expectedReps: 4,
      errorLabels: allReps(4, ['insufficient_extension']),
      frames: syn.gluteBridge(reps: 4, peakAngle: 158),
    ),
  ];

  for (final fx in fixtures) {
    final file = File('${out.path}/${fx.id}.json');
    file.writeAsStringSync(fx.toJsonString());
    stdout.writeln('wrote ${file.path} (${fx.frames.length} frames)');
  }
}
