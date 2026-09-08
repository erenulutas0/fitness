/// MediaPipe Pose Landmarker 33-point topology (BlazePose GHUM).
///
/// The [index] order is fixed by MediaPipe. [dslName] is FORMA's vocabulary
/// used inside rule expressions (`angle(hip_l, knee_l, ankle_l)`).
enum PoseLandmark {
  nose('nose'),
  leftEyeInner('eye_inner_l'),
  leftEye('eye_l'),
  leftEyeOuter('eye_outer_l'),
  rightEyeInner('eye_inner_r'),
  rightEye('eye_r'),
  rightEyeOuter('eye_outer_r'),
  leftEar('ear_l'),
  rightEar('ear_r'),
  mouthLeft('mouth_l'),
  mouthRight('mouth_r'),
  leftShoulder('shoulder_l'),
  rightShoulder('shoulder_r'),
  leftElbow('elbow_l'),
  rightElbow('elbow_r'),
  leftWrist('wrist_l'),
  rightWrist('wrist_r'),
  leftPinky('pinky_l'),
  rightPinky('pinky_r'),
  leftIndex('index_l'),
  rightIndex('index_r'),
  leftThumb('thumb_l'),
  rightThumb('thumb_r'),
  leftHip('hip_l'),
  rightHip('hip_r'),
  leftKnee('knee_l'),
  rightKnee('knee_r'),
  leftAnkle('ankle_l'),
  rightAnkle('ankle_r'),
  leftHeel('heel_l'),
  rightHeel('heel_r'),
  leftFootIndex('foot_index_l'),
  rightFootIndex('foot_index_r')
  ;

  const PoseLandmark(this.dslName);

  /// Name used in the rule DSL.
  final String dslName;

  /// Number of landmarks per frame.
  static const int count = 33;

  static final Map<String, PoseLandmark> _byName = {
    for (final l in values) l.dslName: l,
  };

  static PoseLandmark? fromDslName(String name) => _byName[name];

  /// Whether this landmark belongs to the left side of the body.
  bool get isLeft => dslName.endsWith('_l') || this == PoseLandmark.mouthLeft;

  /// Whether this landmark belongs to the right side of the body.
  bool get isRight => dslName.endsWith('_r') || this == PoseLandmark.mouthRight;
}

/// Landmarks used to judge whether the "core" of the body is tracked.
const List<PoseLandmark> coreLandmarks = [
  PoseLandmark.leftShoulder,
  PoseLandmark.rightShoulder,
  PoseLandmark.leftHip,
  PoseLandmark.rightHip,
  PoseLandmark.leftKnee,
  PoseLandmark.rightKnee,
  PoseLandmark.leftAnkle,
  PoseLandmark.rightAnkle,
];

const List<PoseLandmark> upperBodyLandmarks = [
  PoseLandmark.nose,
  PoseLandmark.leftShoulder,
  PoseLandmark.rightShoulder,
  PoseLandmark.leftElbow,
  PoseLandmark.rightElbow,
  PoseLandmark.leftWrist,
  PoseLandmark.rightWrist,
  PoseLandmark.leftHip,
  PoseLandmark.rightHip,
];

const List<PoseLandmark> lowerBodyLandmarks = [
  PoseLandmark.leftHip,
  PoseLandmark.rightHip,
  PoseLandmark.leftKnee,
  PoseLandmark.rightKnee,
  PoseLandmark.leftAnkle,
  PoseLandmark.rightAnkle,
  PoseLandmark.leftHeel,
  PoseLandmark.rightHeel,
  PoseLandmark.leftFootIndex,
  PoseLandmark.rightFootIndex,
];

/// Skeleton edges (pairs of landmarks) for drawing an overlay.
const List<(PoseLandmark, PoseLandmark)> skeletonEdges = [
  (PoseLandmark.leftShoulder, PoseLandmark.rightShoulder),
  (PoseLandmark.leftShoulder, PoseLandmark.leftElbow),
  (PoseLandmark.leftElbow, PoseLandmark.leftWrist),
  (PoseLandmark.rightShoulder, PoseLandmark.rightElbow),
  (PoseLandmark.rightElbow, PoseLandmark.rightWrist),
  (PoseLandmark.leftShoulder, PoseLandmark.leftHip),
  (PoseLandmark.rightShoulder, PoseLandmark.rightHip),
  (PoseLandmark.leftHip, PoseLandmark.rightHip),
  (PoseLandmark.leftHip, PoseLandmark.leftKnee),
  (PoseLandmark.leftKnee, PoseLandmark.leftAnkle),
  (PoseLandmark.rightHip, PoseLandmark.rightKnee),
  (PoseLandmark.rightKnee, PoseLandmark.rightAnkle),
  (PoseLandmark.leftAnkle, PoseLandmark.leftHeel),
  (PoseLandmark.leftHeel, PoseLandmark.leftFootIndex),
  (PoseLandmark.leftAnkle, PoseLandmark.leftFootIndex),
  (PoseLandmark.rightAnkle, PoseLandmark.rightHeel),
  (PoseLandmark.rightHeel, PoseLandmark.rightFootIndex),
  (PoseLandmark.rightAnkle, PoseLandmark.rightFootIndex),
  (PoseLandmark.nose, PoseLandmark.leftEye),
  (PoseLandmark.nose, PoseLandmark.rightEye),
  (PoseLandmark.leftEye, PoseLandmark.leftEar),
  (PoseLandmark.rightEye, PoseLandmark.rightEar),
];
