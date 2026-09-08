import 'dart:math' as math;

import '../geometry.dart';
import '../landmarks.dart';
import '../pose_frame.dart';
import '../rules/exercise_definition.dart';

/// A full-body skeleton in metres. Axes: x = person's left, y = up,
/// z = the direction the (standing) person faces. Ground is y = 0.
typedef Skeleton3D = Map<PoseLandmark, Vec3>;

/// Segment lengths of the synthetic body (metres, ~1.75 m adult).
class BodyModel {
  const BodyModel({
    this.torso = 0.5,
    this.thigh = 0.45,
    this.shin = 0.43,
    this.upperArm = 0.3,
    this.forearm = 0.27,
    this.shoulderHalf = 0.2,
    this.hipHalf = 0.13,
    this.ankleHeight = 0.07,
    this.footLength = 0.22,
  });

  final double torso;
  final double thigh;
  final double shin;
  final double upperArm;
  final double forearm;
  final double shoulderHalf;
  final double hipHalf;
  final double ankleHeight;
  final double footLength;
}

/// Builds parametric 3D skeletons for the MVP exercises. Used to generate
/// deterministic test fixtures and to drive the UI without a camera.
class SkeletonBuilder {
  const SkeletonBuilder([this.body = const BodyModel()]);

  final BodyModel body;

  /// Bodyweight squat. [kneeAngleDeg] 180 = standing, ~90 = parallel.
  /// [valgus] 0..1 moves the knees toward the midline (front-view error).
  /// [heelRise] metres the heels lift (side-view error).
  Skeleton3D squat({
    required double kneeAngleDeg,
    double extraTorsoLeanDeg = 0,
    double valgus = 0,
    double heelRise = 0,
    double stanceHalf = 0.2,
  }) {
    final flex = 180 - kneeAngleDeg;
    final a = radians(flex * 0.35);
    final b = radians(flex * 0.65);
    final g = radians(flex * 0.30 + extraTorsoLeanDeg);
    final sk = <PoseLandmark, Vec3>{};

    for (final sx in [1.0, -1.0]) {
      final left = sx > 0;
      final ankle = Vec3(sx * stanceHalf, body.ankleHeight, 0);
      final knee = Vec3(
        sx * stanceHalf * (1 - valgus),
        ankle.y + body.shin * math.cos(a),
        ankle.z + body.shin * math.sin(a),
      );
      final hip = Vec3(
        sx * body.hipHalf,
        knee.y + body.thigh * math.cos(b),
        knee.z - body.thigh * math.sin(b),
      );
      sk[left ? PoseLandmark.leftAnkle : PoseLandmark.rightAnkle] = ankle;
      sk[left ? PoseLandmark.leftKnee : PoseLandmark.rightKnee] = knee;
      sk[left ? PoseLandmark.leftHip : PoseLandmark.rightHip] = hip;
      sk[left ? PoseLandmark.leftHeel : PoseLandmark.rightHeel] =
          ankle + Vec3(0, -body.ankleHeight + heelRise, -0.06);
      sk[left ? PoseLandmark.leftFootIndex : PoseLandmark.rightFootIndex] =
          ankle + Vec3(0, -body.ankleHeight, body.footLength - 0.06);
    }
    final hipMid = Vec3.mid(
      sk[PoseLandmark.leftHip]!,
      sk[PoseLandmark.rightHip]!,
    );
    final up = Vec3(0, math.cos(g), math.sin(g));
    final fwd = Vec3(0, -math.sin(g), math.cos(g));
    final shoulderMid = hipMid + up * body.torso;
    for (final sx in [1.0, -1.0]) {
      final left = sx > 0;
      final shoulder = shoulderMid + Vec3(sx * body.shoulderHalf, 0, 0);
      final elbow = shoulder + fwd * body.upperArm;
      final wrist = elbow + fwd * body.forearm;
      _arm(sk, left, shoulder, elbow, wrist, fwd, sx);
    }
    _head(sk, shoulderMid, up: up, fwd: fwd);
    return sk;
  }

  /// Push-up, prone, head toward +z. [elbowAngleDeg] 180 = top, ~90 = bottom.
  /// [hipSag] metres the hips drop below the shoulder–ankle line (negative =
  /// pike).
  Skeleton3D pushUp({required double elbowAngleDeg, double hipSag = 0}) {
    final phi = radians(180 - elbowAngleDeg);
    final sk = <PoseLandmark, Vec3>{};
    Vec3? shoulderMid;
    for (final sx in [1.0, -1.0]) {
      final wrist = Vec3(sx * body.shoulderHalf, 0, 0);
      final elbow = wrist + Vec3(0, body.forearm, 0);
      final shoulder =
          elbow +
          Vec3(
            0,
            body.upperArm * math.cos(phi),
            -body.upperArm * math.sin(phi),
          );
      _arm(sk, sx > 0, shoulder, elbow, wrist, const Vec3(0, 0, 1), sx);
      shoulderMid = shoulderMid == null
          ? shoulder
          : Vec3.mid(shoulderMid, shoulder);
    }
    _proneLowerBody(sk, shoulderMid!, hipSag);
    _head(sk, shoulderMid, up: const Vec3(0, 0, 1), fwd: const Vec3(0, -1, 0));
    return sk;
  }

  /// Forearm plank, prone, head toward +z. [headDropDeg] tilts the head
  /// toward the floor.
  Skeleton3D plank({double hipSag = 0, double headDropDeg = 0}) {
    final sk = <PoseLandmark, Vec3>{};
    Vec3? shoulderMid;
    for (final sx in [1.0, -1.0]) {
      final elbow = Vec3(sx * body.shoulderHalf, 0, 0);
      final wrist = elbow + Vec3(0, 0, body.forearm);
      final shoulder = elbow + Vec3(0, body.upperArm, 0);
      _arm(sk, sx > 0, shoulder, elbow, wrist, const Vec3(0, 0, 1), sx);
      shoulderMid = shoulderMid == null
          ? shoulder
          : Vec3.mid(shoulderMid, shoulder);
    }
    _proneLowerBody(sk, shoulderMid!, hipSag);
    final d = radians(headDropDeg);
    _head(
      sk,
      shoulderMid,
      up: Vec3(0, -math.sin(d), math.cos(d)),
      fwd: Vec3(0, -math.cos(d), -math.sin(d)),
    );
    return sk;
  }

  /// Glute bridge, supine, head toward −z, feet flat. [hipAngleDeg] is the
  /// shoulder–hip–knee angle: ~117 lying, 180 fully extended.
  Skeleton3D gluteBridge({required double hipAngleDeg}) {
    final sk = <PoseLandmark, Vec3>{};
    const shoulderMid = Vec3(0, 0.10, 0);
    final kneeTilt = radians(15);
    final ankleMid = Vec3(0, body.ankleHeight, 0.83);
    final kneeMid =
        ankleMid +
        Vec3(
          0,
          body.shin * math.cos(kneeTilt),
          -body.shin * math.sin(kneeTilt),
        );

    // Hip lies on a circle of radius `thigh` around the knee; rotate from
    // "on the ground" toward "in line with the shoulder".
    final dyRest = kneeMid.y - 0.09;
    final dzRest = math.sqrt(
      math.max(body.thigh * body.thigh - dyRest * dyRest, 1e-6),
    );
    final uRest = Vec3(0, -dyRest, -dzRest).normalized;
    final uTop = (shoulderMid - kneeMid).normalized;
    Vec3 hipAt(double t) => kneeMid + _slerp(uRest, uTop, t) * body.thigh;

    var bestT = 0.0;
    var bestErr = double.infinity;
    for (var i = 0; i <= 200; i++) {
      final t = i / 200;
      final err = (angleDeg3(shoulderMid, hipAt(t), kneeMid) - hipAngleDeg)
          .abs();
      if (err < bestErr) {
        bestErr = err;
        bestT = t;
      }
    }
    final hipMid = hipAt(bestT);

    for (final sx in [1.0, -1.0]) {
      final left = sx > 0;
      final ankle = ankleMid + Vec3(sx * 0.1, 0, 0);
      final knee = kneeMid + Vec3(sx * 0.1, 0, 0);
      final hip = hipMid + Vec3(sx * body.hipHalf, 0, 0);
      final shoulder = shoulderMid + Vec3(sx * body.shoulderHalf, 0, 0);
      final elbow = shoulder + Vec3(sx * 0.05, -0.05, 0.28);
      final wrist = elbow + Vec3(0, 0, body.forearm);
      sk[left ? PoseLandmark.leftAnkle : PoseLandmark.rightAnkle] = ankle;
      sk[left ? PoseLandmark.leftKnee : PoseLandmark.rightKnee] = knee;
      sk[left ? PoseLandmark.leftHip : PoseLandmark.rightHip] = hip;
      sk[left ? PoseLandmark.leftHeel : PoseLandmark.rightHeel] =
          ankle + Vec3(0, -body.ankleHeight, -0.06);
      sk[left ? PoseLandmark.leftFootIndex : PoseLandmark.rightFootIndex] =
          ankle + Vec3(0, -body.ankleHeight, body.footLength - 0.06);
      _arm(sk, left, shoulder, elbow, wrist, const Vec3(0, 0, 1), sx);
    }
    _head(sk, shoulderMid, up: const Vec3(0, 0, -1), fwd: const Vec3(0, 1, 0));
    return sk;
  }

  void _proneLowerBody(Skeleton3D sk, Vec3 shoulderMid, double hipSag) {
    final ankleMid = Vec3(0, body.ankleHeight, shoulderMid.z - 1.35);
    final axis = ankleMid - shoulderMid;
    for (final sx in [1.0, -1.0]) {
      final left = sx > 0;
      final hip =
          shoulderMid + axis * 0.37 + Vec3(sx * body.hipHalf, -hipSag, 0);
      final knee = shoulderMid + axis * 0.70 + Vec3(sx * 0.1, 0, 0);
      final ankle = ankleMid + Vec3(sx * 0.1, 0, 0);
      sk[left ? PoseLandmark.leftHip : PoseLandmark.rightHip] = hip;
      sk[left ? PoseLandmark.leftKnee : PoseLandmark.rightKnee] = knee;
      sk[left ? PoseLandmark.leftAnkle : PoseLandmark.rightAnkle] = ankle;
      sk[left ? PoseLandmark.leftHeel : PoseLandmark.rightHeel] =
          ankle + const Vec3(0, 0.04, -0.07);
      sk[left ? PoseLandmark.leftFootIndex : PoseLandmark.rightFootIndex] =
          ankle + Vec3(0, -body.ankleHeight, 0.05);
    }
  }

  void _arm(
    Skeleton3D sk,
    bool left,
    Vec3 shoulder,
    Vec3 elbow,
    Vec3 wrist,
    Vec3 handDir,
    double sx,
  ) {
    sk[left ? PoseLandmark.leftShoulder : PoseLandmark.rightShoulder] =
        shoulder;
    sk[left ? PoseLandmark.leftElbow : PoseLandmark.rightElbow] = elbow;
    sk[left ? PoseLandmark.leftWrist : PoseLandmark.rightWrist] = wrist;
    final hand = wrist + handDir * 0.06;
    sk[left ? PoseLandmark.leftPinky : PoseLandmark.rightPinky] =
        hand + Vec3(sx * 0.02, 0, 0);
    sk[left ? PoseLandmark.leftIndex : PoseLandmark.rightIndex] =
        hand + Vec3(-sx * 0.02, 0, 0);
    sk[left ? PoseLandmark.leftThumb : PoseLandmark.rightThumb] =
        wrist + handDir * 0.03 + Vec3(-sx * 0.03, 0, 0);
  }

  void _head(
    Skeleton3D sk,
    Vec3 shoulderMid, {
    required Vec3 up,
    required Vec3 fwd,
  }) {
    const lateral = Vec3(1, 0, 0);
    sk[PoseLandmark.nose] = shoulderMid + up * 0.17 + fwd * 0.09;
    for (final sx in [1.0, -1.0]) {
      final left = sx > 0;
      final eye = shoulderMid + up * 0.19 + fwd * 0.08 + lateral * (sx * 0.035);
      sk[left ? PoseLandmark.leftEye : PoseLandmark.rightEye] = eye;
      sk[left ? PoseLandmark.leftEyeInner : PoseLandmark.rightEyeInner] =
          eye + lateral * (-sx * 0.015);
      sk[left ? PoseLandmark.leftEyeOuter : PoseLandmark.rightEyeOuter] =
          eye + lateral * (sx * 0.015);
      sk[left ? PoseLandmark.leftEar : PoseLandmark.rightEar] =
          shoulderMid + up * 0.17 + lateral * (sx * 0.08);
      sk[left ? PoseLandmark.mouthLeft : PoseLandmark.mouthRight] =
          shoulderMid + up * 0.12 + fwd * 0.08 + lateral * (sx * 0.025);
    }
  }

  static Vec3 _slerp(Vec3 a, Vec3 b, double t) {
    final dot = a.dot(b).clamp(-1.0, 1.0);
    final omega = math.acos(dot);
    if (omega < 1e-4) return (a * (1 - t) + b * t).normalized;
    final so = math.sin(omega);
    return (a * (math.sin((1 - t) * omega) / so) +
            b * (math.sin(t * omega) / so))
        .normalized;
  }
}

/// Projects [Skeleton3D]s into [PoseFrame]s the way a camera + MediaPipe
/// would (orthographic, no lens distortion).
class SkeletonProjector {
  SkeletonProjector({
    required this.view,
    this.width = 720,
    this.height = 1280,
    this.metresPerImageHeight = 2.2,
    this.visibility = 1.0,
    this.noiseStd = 0,
    this.includeWorld = true,
    int seed = 1,
  }) : _rng = math.Random(seed);

  final CameraView view;
  final int width;
  final int height;

  /// Vertical field of view in metres (sets how big the person appears).
  final double metresPerImageHeight;
  final double visibility;

  /// Gaussian noise (std, normalized image units) added to x and y.
  final double noiseStd;
  final bool includeWorld;
  final math.Random _rng;

  double get aspect => width / height;

  /// Camera-space coordinates: (right, down, depth).
  Vec3 _cam(Vec3 p) => switch (view) {
    CameraView.front => Vec3(p.x, -p.y, -p.z),
    CameraView.side => Vec3(p.z, -p.y, p.x),
  };

  PoseFrame project(Skeleton3D sk, {required int tMs}) {
    final cams = <PoseLandmark, Vec3>{
      for (final e in sk.entries) e.key: _cam(e.value),
    };
    var xMin = double.infinity;
    var xMax = -double.infinity;
    var yMin = double.infinity;
    var yMax = -double.infinity;
    for (final c in cams.values) {
      xMin = math.min(xMin, c.x);
      xMax = math.max(xMax, c.x);
      yMin = math.min(yMin, c.y);
      yMax = math.max(yMax, c.y);
    }
    final cx = (xMin + xMax) / 2;
    final cy = (yMin + yMax) / 2;
    final k = 1 / metresPerImageHeight;
    final hipL = cams[PoseLandmark.leftHip] ?? Vec3.zero;
    final hipR = cams[PoseLandmark.rightHip] ?? Vec3.zero;
    final hipMid = Vec3.mid(hipL, hipR);

    final landmarks = List<Landmark>.generate(PoseLandmark.count, (i) {
      final c = cams[PoseLandmark.values[i]];
      if (c == null) return Landmark.missing;
      final nx = 0.5 + (c.x - cx) * k / aspect + _noise();
      final ny = 0.5 + (c.y - cy) * k + _noise();
      return Landmark(
        x: nx,
        y: ny,
        z: (c.z - hipMid.z) * k,
        visibility: visibility,
      );
    });
    List<Vec3>? world;
    if (includeWorld) {
      world = List<Vec3>.generate(PoseLandmark.count, (i) {
        final c = cams[PoseLandmark.values[i]] ?? hipMid;
        return c - hipMid;
      });
    }
    return PoseFrame(
      timestampMs: tMs,
      width: width,
      height: height,
      landmarks: landmarks,
      worldLandmarks: world,
    );
  }

  double _noise() {
    if (noiseStd == 0) return 0;
    // Box–Muller.
    final u1 = math.max(_rng.nextDouble(), 1e-12);
    final u2 = _rng.nextDouble();
    return noiseStd * math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }
}

/// Ready-made motion sequences for tests and the camera-less HUD preview.
class SyntheticPose {
  const SyntheticPose({this.builder = const SkeletonBuilder()});

  final SkeletonBuilder builder;

  /// Half-cosine profile: [restValue] → [peakValue] → [restValue] per rep,
  /// with [pauseMs] of rest between reps and a [leadInMs] rest at the start.
  static List<(int, double)> repProfile({
    required int reps,
    required double restValue,
    required double peakValue,
    int periodMs = 2400,
    int pauseMs = 700,
    int leadInMs = 600,
    int fps = 30,
  }) {
    final out = <(int, double)>[];
    final dt = 1000 / fps;
    final active = reps * (periodMs + pauseMs);
    final total = leadInMs + active + pauseMs;
    for (var t = 0.0; t <= total; t += dt) {
      var v = restValue;
      if (t >= leadInMs && t - leadInMs < active) {
        final local = (t - leadInMs) % (periodMs + pauseMs);
        if (local < periodMs) {
          final phase = local / periodMs; // 0..1
          v =
              restValue +
              (peakValue - restValue) * (1 - math.cos(2 * math.pi * phase)) / 2;
        }
      }
      out.add((t.round(), v));
    }
    return out;
  }

  List<PoseFrame> squat({
    required CameraView view,
    int reps = 5,
    double restAngle = 172,
    double peakAngle = 90,
    double valgus = 0,
    double extraTorsoLeanDeg = 0,
    double heelRise = 0,
    int periodMs = 2400,
    int pauseMs = 700,
    int fps = 30,
    double noiseStd = 0,
    int seed = 1,
    int width = 720,
    int height = 1280,
  }) {
    final proj = SkeletonProjector(
      view: view,
      noiseStd: noiseStd,
      seed: seed,
      width: width,
      height: height,
    );
    return [
      for (final (t, angle) in repProfile(
        reps: reps,
        restValue: restAngle,
        peakValue: peakAngle,
        periodMs: periodMs,
        pauseMs: pauseMs,
        fps: fps,
      ))
        proj.project(
          builder.squat(
            kneeAngleDeg: angle,
            // Errors are expressed most at depth; scale with flexion.
            valgus:
                valgus *
                ((restAngle - angle) / (restAngle - peakAngle)).clamp(0.0, 1.0),
            extraTorsoLeanDeg:
                extraTorsoLeanDeg *
                ((restAngle - angle) / (restAngle - peakAngle)).clamp(0.0, 1.0),
            heelRise:
                heelRise *
                ((restAngle - angle) / (restAngle - peakAngle)).clamp(0.0, 1.0),
          ),
          tMs: t,
        ),
    ];
  }

  List<PoseFrame> pushUp({
    int reps = 5,
    double restAngle = 170,
    double peakAngle = 85,
    double hipSag = 0,
    int periodMs = 2000,
    int pauseMs = 500,
    int fps = 30,
    double noiseStd = 0,
    int seed = 1,
    int width = 1280,
    int height = 720,
  }) {
    final proj = SkeletonProjector(
      view: CameraView.side,
      noiseStd: noiseStd,
      seed: seed,
      width: width,
      height: height,
    );
    return [
      for (final (t, angle) in repProfile(
        reps: reps,
        restValue: restAngle,
        peakValue: peakAngle,
        periodMs: periodMs,
        pauseMs: pauseMs,
        fps: fps,
      ))
        proj.project(
          builder.pushUp(elbowAngleDeg: angle, hipSag: hipSag),
          tMs: t,
        ),
    ];
  }

  List<PoseFrame> plank({
    int durationMs = 20000,
    double hipSag = 0,
    double headDropDeg = 0,
    int fps = 30,
    double noiseStd = 0,
    int seed = 1,
    int width = 1280,
    int height = 720,
  }) {
    final proj = SkeletonProjector(
      view: CameraView.side,
      noiseStd: noiseStd,
      seed: seed,
      width: width,
      height: height,
    );
    final sk = builder.plank(hipSag: hipSag, headDropDeg: headDropDeg);
    final dt = 1000 / fps;
    return [
      for (var t = 0.0; t <= durationMs; t += dt)
        proj.project(sk, tMs: t.round()),
    ];
  }

  List<PoseFrame> gluteBridge({
    int reps = 5,
    double restAngle = 120,
    double peakAngle = 178,
    int periodMs = 2200,
    int pauseMs = 600,
    int fps = 30,
    double noiseStd = 0,
    int seed = 1,
    int width = 1280,
    int height = 720,
  }) {
    final proj = SkeletonProjector(
      view: CameraView.side,
      noiseStd: noiseStd,
      seed: seed,
      width: width,
      height: height,
    );
    return [
      for (final (t, angle) in repProfile(
        reps: reps,
        restValue: restAngle,
        peakValue: peakAngle,
        periodMs: periodMs,
        pauseMs: pauseMs,
        fps: fps,
      ))
        proj.project(builder.gluteBridge(hipAngleDeg: angle), tMs: t),
    ];
  }
}
