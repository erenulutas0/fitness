import 'dart:math' as math;

import '../geometry.dart';
import '../landmarks.dart';
import '../pose_frame.dart';

/// Which side of the body a value came from.
enum Side { left, right }

/// A scalar feature with a confidence (min visibility of the landmarks used).
class FeatureValue {
  const FeatureValue(this.value, this.confidence);

  final double value;
  final double confidence;

  @override
  String toString() =>
      '${value.toStringAsFixed(3)}@${confidence.toStringAsFixed(2)}';
}

/// A resolved 2D point (image space, aspect corrected) with confidence.
class ResolvedPoint {
  const ResolvedPoint(this.p, this.confidence, {this.world});

  final Vec2 p;
  final double confidence;
  final Vec3? world;
}

/// Names of every feature produced by [FeatureExtractor]; used for DSL
/// validation and documentation.
abstract final class FeatureNames {
  static const perSide = <String>[
    'knee_angle',
    'hip_angle',
    'elbow_angle',
    'shoulder_angle',
    'neck_angle',
    'ankle_angle',
    'heel_rise',
    'knee_ankle_ratio',
    'wrist_head_dy',
    'wrist_shoulder_dy',
    'knee_angle_3d',
    'hip_angle_3d',
  ];

  static const global = <String>[
    'torso_angle',
    'body_line_angle',
    'hip_line_deviation',
    'knee_separation_ratio',
    'shoulder_level_diff',
    'hip_level_diff',
    'hip_knee_dy',
    'hip_ankle_dy',
    'stance_width_ratio',
    'shoulder_width_ratio',
    'arm_spread_ratio',
    'torso_length',
    'bbox_x_min',
    'bbox_x_max',
    'bbox_y_min',
    'bbox_y_max',
    'bbox_height',
    'bbox_width',
    'vis_full',
    'vis_core',
    'vis_upper',
    'vis_lower',
    'has_world',
  ];

  /// Every feature name, including `_l` / `_r` / side-agnostic variants.
  static final Set<String> all = {
    for (final n in perSide) ...['${n}_l', '${n}_r', n],
    ...global,
  };

  /// Point names accepted by `angle()` / `dist()` in addition to raw
  /// landmark names.
  static const virtualPoints = <String>[
    'shoulder_mid',
    'hip_mid',
    'knee_mid',
    'ankle_mid',
    'shoulder',
    'elbow',
    'wrist',
    'hip',
    'knee',
    'ankle',
    'heel',
    'foot_index',
    'ear',
  ];

  static bool isPoint(String name) =>
      PoseLandmark.fromDslName(name) != null || virtualPoints.contains(name);
}

/// The output of [FeatureExtractor] for one frame.
class FeatureSet {
  FeatureSet({
    required this.frame,
    required this.values,
    required this.dominantSide,
    required this.aspect,
  });

  final PoseFrame frame;
  final Map<String, FeatureValue> values;
  final Side dominantSide;
  final double aspect;

  FeatureValue? operator [](String name) => values[name];

  double? value(String name) => values[name]?.value;

  double confidence(String name) => values[name]?.confidence ?? 0;

  /// Aspect-corrected image point for a landmark.
  Vec2 pointOf(PoseLandmark l) {
    final lm = frame[l];
    return Vec2(lm.x * aspect, lm.y);
  }

  /// Resolve a DSL point name (`hip_l`, `hip_mid`, `hip`) to a point.
  ResolvedPoint? point(String name) {
    final exact = PoseLandmark.fromDslName(name);
    if (exact != null) {
      final lm = frame[exact];
      return ResolvedPoint(
        pointOf(exact),
        lm.visibility,
        world: frame.world(exact),
      );
    }
    if (name.endsWith('_mid')) {
      final base = name.substring(0, name.length - 4);
      final l = PoseLandmark.fromDslName('${base}_l');
      final r = PoseLandmark.fromDslName('${base}_r');
      if (l == null || r == null) return null;
      final wl = frame.world(l);
      final wr = frame.world(r);
      return ResolvedPoint(
        Vec2.mid(pointOf(l), pointOf(r)),
        math.min(frame[l].visibility, frame[r].visibility),
        world: (wl != null && wr != null) ? Vec3.mid(wl, wr) : null,
      );
    }
    final suffix = dominantSide == Side.left ? '_l' : '_r';
    final dom = PoseLandmark.fromDslName('$name$suffix');
    if (dom == null) return null;
    return ResolvedPoint(
      pointOf(dom),
      frame[dom].visibility,
      world: frame.world(dom),
    );
  }
}

/// Turns a [PoseFrame] into named scalar features (angles, ratios,
/// alignments) that the rule DSL and the rep detector consume.
///
/// All 2D math is done in aspect-corrected image coordinates so that angles
/// are geometrically correct for non-square frames.
class FeatureExtractor {
  FeatureExtractor({this.minVisibility = 0.5});

  /// Below this visibility a side is not trusted when merging left/right.
  final double minVisibility;

  FeatureSet extract(PoseFrame f) {
    final aspect = f.aspect;
    Vec2 p(PoseLandmark l) => Vec2(f[l].x * aspect, f[l].y);
    double vis(PoseLandmark l) => f[l].visibility;
    double minVis(List<PoseLandmark> ls) => ls.map(vis).reduce(math.min);

    final leftScore =
        vis(PoseLandmark.leftShoulder) +
        vis(PoseLandmark.leftHip) +
        vis(PoseLandmark.leftKnee) +
        vis(PoseLandmark.leftAnkle);
    final rightScore =
        vis(PoseLandmark.rightShoulder) +
        vis(PoseLandmark.rightHip) +
        vis(PoseLandmark.rightKnee) +
        vis(PoseLandmark.rightAnkle);
    final dominant = leftScore >= rightScore ? Side.left : Side.right;

    final v = <String, FeatureValue>{};

    FeatureValue angle(PoseLandmark a, PoseLandmark b, PoseLandmark c) =>
        FeatureValue(angleDeg2(p(a), p(b), p(c)), minVis([a, b, c]));

    void perSide(String name, FeatureValue l, FeatureValue r) {
      v['${name}_l'] = l;
      v['${name}_r'] = r;
      v[name] = _merge(l, r);
    }

    // --- joint angles -----------------------------------------------------
    perSide(
      'knee_angle',
      angle(
        PoseLandmark.leftHip,
        PoseLandmark.leftKnee,
        PoseLandmark.leftAnkle,
      ),
      angle(
        PoseLandmark.rightHip,
        PoseLandmark.rightKnee,
        PoseLandmark.rightAnkle,
      ),
    );
    perSide(
      'hip_angle',
      angle(
        PoseLandmark.leftShoulder,
        PoseLandmark.leftHip,
        PoseLandmark.leftKnee,
      ),
      angle(
        PoseLandmark.rightShoulder,
        PoseLandmark.rightHip,
        PoseLandmark.rightKnee,
      ),
    );
    perSide(
      'elbow_angle',
      angle(
        PoseLandmark.leftShoulder,
        PoseLandmark.leftElbow,
        PoseLandmark.leftWrist,
      ),
      angle(
        PoseLandmark.rightShoulder,
        PoseLandmark.rightElbow,
        PoseLandmark.rightWrist,
      ),
    );
    perSide(
      'shoulder_angle',
      angle(
        PoseLandmark.leftElbow,
        PoseLandmark.leftShoulder,
        PoseLandmark.leftHip,
      ),
      angle(
        PoseLandmark.rightElbow,
        PoseLandmark.rightShoulder,
        PoseLandmark.rightHip,
      ),
    );
    perSide(
      'neck_angle',
      angle(
        PoseLandmark.leftEar,
        PoseLandmark.leftShoulder,
        PoseLandmark.leftHip,
      ),
      angle(
        PoseLandmark.rightEar,
        PoseLandmark.rightShoulder,
        PoseLandmark.rightHip,
      ),
    );
    perSide(
      'ankle_angle',
      angle(
        PoseLandmark.leftKnee,
        PoseLandmark.leftAnkle,
        PoseLandmark.leftFootIndex,
      ),
      angle(
        PoseLandmark.rightKnee,
        PoseLandmark.rightAnkle,
        PoseLandmark.rightFootIndex,
      ),
    );

    // --- reference points / lengths ---------------------------------------
    final shoulderMid = Vec2.mid(
      p(PoseLandmark.leftShoulder),
      p(PoseLandmark.rightShoulder),
    );
    final hipMid = Vec2.mid(p(PoseLandmark.leftHip), p(PoseLandmark.rightHip));
    final kneeMid = Vec2.mid(
      p(PoseLandmark.leftKnee),
      p(PoseLandmark.rightKnee),
    );
    final ankleMid = Vec2.mid(
      p(PoseLandmark.leftAnkle),
      p(PoseLandmark.rightAnkle),
    );
    final torsoLen = math.max(Vec2.distance(shoulderMid, hipMid), 1e-6);
    final shoulderWidth =
        (p(PoseLandmark.leftShoulder).x - p(PoseLandmark.rightShoulder).x)
            .abs();
    final ankleSep =
        (p(PoseLandmark.leftAnkle).x - p(PoseLandmark.rightAnkle).x).abs();
    final kneeSep = (p(PoseLandmark.leftKnee).x - p(PoseLandmark.rightKnee).x)
        .abs();
    final shoulderVis = minVis([
      PoseLandmark.leftShoulder,
      PoseLandmark.rightShoulder,
    ]);
    final hipVis = minVis([PoseLandmark.leftHip, PoseLandmark.rightHip]);
    final kneeVis = minVis([PoseLandmark.leftKnee, PoseLandmark.rightKnee]);
    final ankleVis = minVis([PoseLandmark.leftAnkle, PoseLandmark.rightAnkle]);
    final torsoVis = math.min(shoulderVis, hipVis);

    v['torso_length'] = FeatureValue(torsoLen, torsoVis);
    v['torso_angle'] = FeatureValue(
      angleFromVerticalDeg(hipMid, shoulderMid),
      torsoVis,
    );
    v['body_line_angle'] = FeatureValue(
      angleDeg2(shoulderMid, hipMid, ankleMid),
      math.min(torsoVis, ankleVis),
    );
    final bodyLen = math.max(Vec2.distance(shoulderMid, ankleMid), 1e-6);
    v['hip_line_deviation'] = FeatureValue(
      signedOffsetFromLine(hipMid, shoulderMid, ankleMid) / bodyLen,
      math.min(torsoVis, ankleVis),
    );

    // --- heel rise (side view): heel above toe, normalized by shin length --
    FeatureValue heelRise(
      PoseLandmark heel,
      PoseLandmark toe,
      PoseLandmark ankle,
      PoseLandmark knee,
    ) {
      final shin = math.max(Vec2.distance(p(ankle), p(knee)), 1e-6);
      return FeatureValue(
        (p(toe).y - p(heel).y) / shin,
        minVis([heel, toe, ankle, knee]),
      );
    }

    perSide(
      'heel_rise',
      heelRise(
        PoseLandmark.leftHeel,
        PoseLandmark.leftFootIndex,
        PoseLandmark.leftAnkle,
        PoseLandmark.leftKnee,
      ),
      heelRise(
        PoseLandmark.rightHeel,
        PoseLandmark.rightFootIndex,
        PoseLandmark.rightAnkle,
        PoseLandmark.rightKnee,
      ),
    );

    // --- knee valgus proxies (front view) ---------------------------------
    // Per side: knee offset from the body centre-line relative to the ankle
    // offset. 1.0 = knee stacked over ankle, < 1 = knee caving inward.
    final centreX = ankleMid.x;
    FeatureValue kneeAnkleRatio(PoseLandmark knee, PoseLandmark ankle) {
      final ankleOff = p(ankle).x - centreX;
      final kneeOff = p(knee).x - centreX;
      if (ankleOff.abs() < 0.02) return const FeatureValue(1, 0);
      return FeatureValue(
        kneeOff / ankleOff,
        minVis([knee, ankle, PoseLandmark.leftAnkle, PoseLandmark.rightAnkle]),
      );
    }

    perSide(
      'knee_ankle_ratio',
      kneeAnkleRatio(PoseLandmark.leftKnee, PoseLandmark.leftAnkle),
      kneeAnkleRatio(PoseLandmark.rightKnee, PoseLandmark.rightAnkle),
    );
    v['knee_separation_ratio'] = ankleSep < 0.02
        ? const FeatureValue(1, 0)
        : FeatureValue(kneeSep / ankleSep, math.min(kneeVis, ankleVis));

    // --- levels / symmetry ------------------------------------------------
    final sw = math.max(shoulderWidth, 1e-6);
    v['shoulder_level_diff'] = FeatureValue(
      (p(PoseLandmark.leftShoulder).y - p(PoseLandmark.rightShoulder).y) / sw,
      shoulderVis,
    );
    v['hip_level_diff'] = FeatureValue(
      (p(PoseLandmark.leftHip).y - p(PoseLandmark.rightHip).y) / sw,
      hipVis,
    );

    // --- heights ----------------------------------------------------------
    final thighLen = math.max(Vec2.distance(hipMid, kneeMid), 1e-6);
    v['hip_knee_dy'] = FeatureValue(
      (kneeMid.y - hipMid.y) / thighLen,
      math.min(hipVis, kneeVis),
    );
    v['hip_ankle_dy'] = FeatureValue(
      (ankleMid.y - hipMid.y) / torsoLen,
      math.min(hipVis, ankleVis),
    );
    v['stance_width_ratio'] = FeatureValue(
      ankleSep / sw,
      math.min(ankleVis, shoulderVis),
    );
    v['shoulder_width_ratio'] = FeatureValue(
      shoulderWidth / torsoLen,
      torsoVis,
    );

    // --- arms / gestures --------------------------------------------------
    final nose = p(PoseLandmark.nose);
    FeatureValue wristHeadDy(PoseLandmark wrist) => FeatureValue(
      (nose.y - p(wrist).y) / torsoLen,
      minVis([wrist, PoseLandmark.nose]),
    );
    FeatureValue wristShoulderDy(PoseLandmark wrist, PoseLandmark shoulder) =>
        FeatureValue(
          (p(shoulder).y - p(wrist).y) / torsoLen,
          minVis([wrist, shoulder]),
        );
    perSide(
      'wrist_head_dy',
      wristHeadDy(PoseLandmark.leftWrist),
      wristHeadDy(PoseLandmark.rightWrist),
    );
    perSide(
      'wrist_shoulder_dy',
      wristShoulderDy(PoseLandmark.leftWrist, PoseLandmark.leftShoulder),
      wristShoulderDy(PoseLandmark.rightWrist, PoseLandmark.rightShoulder),
    );
    v['arm_spread_ratio'] = FeatureValue(
      (p(PoseLandmark.leftWrist).x - p(PoseLandmark.rightWrist).x).abs() / sw,
      minVis([
        PoseLandmark.leftWrist,
        PoseLandmark.rightWrist,
        PoseLandmark.leftShoulder,
        PoseLandmark.rightShoulder,
      ]),
    );

    // --- bounding box & visibility ----------------------------------------
    var xMin = double.infinity;
    var xMax = -double.infinity;
    var yMin = double.infinity;
    var yMax = -double.infinity;
    var anyVisible = false;
    for (final l in PoseLandmark.values) {
      final lm = f[l];
      if (lm.visibility < minVisibility) continue;
      anyVisible = true;
      xMin = math.min(xMin, lm.x);
      xMax = math.max(xMax, lm.x);
      yMin = math.min(yMin, lm.y);
      yMax = math.max(yMax, lm.y);
    }
    if (!anyVisible) {
      xMin = xMax = yMin = yMax = 0;
    }
    v['bbox_x_min'] = FeatureValue(xMin, 1);
    v['bbox_x_max'] = FeatureValue(xMax, 1);
    v['bbox_y_min'] = FeatureValue(yMin, 1);
    v['bbox_y_max'] = FeatureValue(yMax, 1);
    v['bbox_height'] = FeatureValue(yMax - yMin, 1);
    v['bbox_width'] = FeatureValue(xMax - xMin, 1);
    v['vis_full'] = FeatureValue(f.meanVisibility(PoseLandmark.values), 1);
    v['vis_core'] = FeatureValue(f.meanVisibility(coreLandmarks), 1);
    v['vis_upper'] = FeatureValue(f.meanVisibility(upperBodyLandmarks), 1);
    v['vis_lower'] = FeatureValue(f.meanVisibility(lowerBodyLandmarks), 1);

    // --- 3D (world landmarks) ---------------------------------------------
    final w = f.worldLandmarks;
    v['has_world'] = FeatureValue(w == null ? 0 : 1, 1);
    if (w != null) {
      FeatureValue angle3(PoseLandmark a, PoseLandmark b, PoseLandmark c) =>
          FeatureValue(
            angleDeg3(w[a.index], w[b.index], w[c.index]),
            minVis([a, b, c]),
          );
      perSide(
        'knee_angle_3d',
        angle3(
          PoseLandmark.leftHip,
          PoseLandmark.leftKnee,
          PoseLandmark.leftAnkle,
        ),
        angle3(
          PoseLandmark.rightHip,
          PoseLandmark.rightKnee,
          PoseLandmark.rightAnkle,
        ),
      );
      perSide(
        'hip_angle_3d',
        angle3(
          PoseLandmark.leftShoulder,
          PoseLandmark.leftHip,
          PoseLandmark.leftKnee,
        ),
        angle3(
          PoseLandmark.rightShoulder,
          PoseLandmark.rightHip,
          PoseLandmark.rightKnee,
        ),
      );
    } else {
      // Fall back to 2D so rules written against *_3d still evaluate (with
      // reduced confidence) on engines without world landmarks.
      for (final s in ['_l', '_r', '']) {
        final k = v['knee_angle$s']!;
        final h = v['hip_angle$s']!;
        v['knee_angle_3d$s'] = FeatureValue(k.value, k.confidence * 0.6);
        v['hip_angle_3d$s'] = FeatureValue(h.value, h.confidence * 0.6);
      }
    }

    return FeatureSet(
      frame: f,
      values: v,
      dominantSide: dominant,
      aspect: aspect,
    );
  }

  /// Average both sides when both are trustworthy, otherwise use the better.
  FeatureValue _merge(FeatureValue l, FeatureValue r) {
    final lOk = l.confidence >= minVisibility;
    final rOk = r.confidence >= minVisibility;
    if (lOk && rOk) {
      return FeatureValue(
        (l.value + r.value) / 2,
        math.min(l.confidence, r.confidence),
      );
    }
    return l.confidence >= r.confidence ? l : r;
  }
}
