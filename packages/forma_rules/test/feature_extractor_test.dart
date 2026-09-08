import 'package:forma_rules/forma_rules.dart';
import 'package:test/test.dart';

void main() {
  const builder = SkeletonBuilder();
  final extractor = FeatureExtractor();

  FeatureSet features(
    Skeleton3D sk,
    CameraView view, {
    int w = 720,
    int h = 1280,
  }) => extractor.extract(
    SkeletonProjector(view: view, width: w, height: h).project(sk, tMs: 0),
  );

  group('squat', () {
    test('side-view knee angle matches the model parameter', () {
      for (final angle in [175.0, 140.0, 100.0, 80.0]) {
        final fs = features(
          builder.squat(kneeAngleDeg: angle),
          CameraView.side,
        );
        expect(
          fs.value('knee_angle'),
          closeTo(angle, 1.0),
          reason: 'angle $angle',
        );
        expect(fs.value('knee_angle_l'), closeTo(angle, 1.0));
        expect(fs.confidence('knee_angle'), 1);
      }
    });

    test('front-view 3D knee angle matches while 2D is foreshortened', () {
      final fs = features(builder.squat(kneeAngleDeg: 95), CameraView.front);
      expect(fs.value('knee_angle_3d'), closeTo(95, 1.0));
      expect(fs.value('has_world'), 1);
    });

    test('valgus lowers knee_ankle_ratio in the front view', () {
      final clean = features(builder.squat(kneeAngleDeg: 95), CameraView.front);
      final caved = features(
        builder.squat(kneeAngleDeg: 95, valgus: 0.3),
        CameraView.front,
      );
      expect(clean.value('knee_ankle_ratio_l'), closeTo(1.0, 0.02));
      expect(caved.value('knee_ankle_ratio_l'), closeTo(0.7, 0.03));
      expect(caved.value('knee_ankle_ratio_r'), closeTo(0.7, 0.03));
      expect(caved.value('knee_separation_ratio'), closeTo(0.7, 0.03));
    });

    test('torso angle grows with lean; heel rise is detected', () {
      final upright = features(
        builder.squat(kneeAngleDeg: 95),
        CameraView.side,
      );
      final leaning = features(
        builder.squat(kneeAngleDeg: 95, extraTorsoLeanDeg: 30),
        CameraView.side,
      );
      expect(
        leaning.value('torso_angle')! - upright.value('torso_angle')!,
        closeTo(30, 1.5),
      );
      final heels = features(
        builder.squat(kneeAngleDeg: 95, heelRise: 0.08),
        CameraView.side,
      );
      expect(upright.value('heel_rise'), closeTo(0, 0.02));
      expect(heels.value('heel_rise'), greaterThan(0.15));
    });

    test('aspect ratio does not change angles', () {
      final portrait = features(
        builder.squat(kneeAngleDeg: 100),
        CameraView.side,
      );
      final landscape = features(
        builder.squat(kneeAngleDeg: 100),
        CameraView.side,
        w: 1280,
        h: 720,
      );
      expect(
        portrait.value('knee_angle'),
        closeTo(landscape.value('knee_angle')!, 0.5),
      );
    });
  });

  group('prone exercises', () {
    test('plank body line is straight and hips sag positive', () {
      final straight = features(
        builder.plank(),
        CameraView.side,
        w: 1280,
        h: 720,
      );
      expect(straight.value('body_line_angle'), greaterThan(170));
      expect(straight.value('hip_line_deviation'), closeTo(0, 0.01));
      expect(straight.value('torso_angle'), greaterThan(55));
      final sag = features(
        builder.plank(hipSag: 0.1),
        CameraView.side,
        w: 1280,
        h: 720,
      );
      expect(sag.value('hip_line_deviation'), greaterThan(0.05));
      final pike = features(
        builder.plank(hipSag: -0.12),
        CameraView.side,
        w: 1280,
        h: 720,
      );
      expect(pike.value('hip_line_deviation'), lessThan(-0.06));
    });

    test('head drop lowers neck angle', () {
      final neutral = features(
        builder.plank(),
        CameraView.side,
        w: 1280,
        h: 720,
      );
      final dropped = features(
        builder.plank(headDropDeg: 45),
        CameraView.side,
        w: 1280,
        h: 720,
      );
      expect(neutral.value('neck_angle'), greaterThan(165));
      expect(dropped.value('neck_angle'), lessThan(140));
    });

    test('push-up elbow angle matches the parameter', () {
      for (final a in [170.0, 120.0, 85.0]) {
        final fs = features(
          builder.pushUp(elbowAngleDeg: a),
          CameraView.side,
          w: 1280,
          h: 720,
        );
        expect(fs.value('elbow_angle'), closeTo(a, 1.0));
      }
    });

    test('glute bridge hip angle follows the parameter', () {
      for (final a in [120.0, 150.0, 178.0]) {
        final fs = features(
          builder.gluteBridge(hipAngleDeg: a),
          CameraView.side,
          w: 1280,
          h: 720,
        );
        expect(fs.value('hip_angle'), closeTo(a, 1.5), reason: 'angle $a');
      }
    });
  });

  group('view detection & framing', () {
    test('shoulder width ratio separates front from side', () {
      final front = features(
        builder.squat(kneeAngleDeg: 175),
        CameraView.front,
      );
      final side = features(builder.squat(kneeAngleDeg: 175), CameraView.side);
      expect(front.value('shoulder_width_ratio'), greaterThan(0.45));
      expect(side.value('shoulder_width_ratio'), lessThan(0.25));
      const checker = FramingChecker();
      expect(checker.check(front).detectedView, DetectedView.front);
      expect(checker.check(side).detectedView, DetectedView.side);
      expect(checker.check(front).status, FramingStatus.ok);
    });

    test('too far / too close are reported', () {
      final far = extractor.extract(
        SkeletonProjector(
          view: CameraView.front,
          metresPerImageHeight: 5,
        ).project(builder.squat(kneeAngleDeg: 175), tMs: 0),
      );
      final close = extractor.extract(
        SkeletonProjector(
          view: CameraView.front,
          metresPerImageHeight: 1.6,
        ).project(builder.squat(kneeAngleDeg: 175), tMs: 0),
      );
      const checker = FramingChecker();
      expect(checker.check(far).status, FramingStatus.tooFar);
      expect(checker.check(close).status, FramingStatus.tooClose);
      expect(
        checker.check(extractor.extract(PoseFrame.empty(0))).status,
        FramingStatus.noPose,
      );
    });

    test('a pose nobody can see says so instead of "step back"', () {
      // A detected pose whose landmarks are all below the visibility
      // threshold collapses the bounding box to (0,0). Reading the edges then
      // says "touching the top" and the coach told someone standing three
      // metres away in a dark room to step back, forever.
      final visible = SkeletonProjector(
        view: CameraView.front,
      ).project(builder.squat(kneeAngleDeg: 175), tMs: 0);
      final invisible = PoseFrame(
        timestampMs: 0,
        landmarks: [
          for (final l in visible.landmarks)
            Landmark(x: l.x, y: l.y, z: l.z, visibility: 0.1, presence: 0.1),
        ],
        width: visible.width,
        height: visible.height,
      );
      const checker = FramingChecker();
      final r = checker.check(extractor.extract(invisible));
      expect(r.status, FramingStatus.lowConfidence);
    });
  });

  test('point() resolves raw, mid and side-agnostic names', () {
    final fs = features(builder.squat(kneeAngleDeg: 120), CameraView.side);
    expect(fs.point('hip_l'), isNotNull);
    expect(fs.point('hip_mid'), isNotNull);
    expect(fs.point('hip'), isNotNull);
    expect(fs.point('nope'), isNull);
    final viaDsl = const ExpressionEvaluator().eval(
      ExpressionParser.parse('angle(hip, knee, ankle)'),
      FrameScope(fs),
    );
    expect(viaDsl.asDouble, closeTo(120, 1.0));
  });
}
