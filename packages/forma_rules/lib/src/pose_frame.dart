import 'geometry.dart';
import 'landmarks.dart';

/// One detected body landmark in normalized image coordinates.
///
/// [x] and [y] are in `[0, 1]` relative to image width/height (y down).
/// [z] is MediaPipe's relative depth (same scale as x, hip-centred).
/// [visibility] is the model's estimate that the point is visible (0..1);
/// [presence] that it is inside the frame (0..1).
class Landmark {
  const Landmark({
    required this.x,
    required this.y,
    this.z = 0,
    this.visibility = 1,
    this.presence = 1,
  });

  factory Landmark.fromList(List<num> v) => Landmark(
    x: v[0].toDouble(),
    y: v[1].toDouble(),
    z: v.length > 2 ? v[2].toDouble() : 0,
    visibility: v.length > 3 ? v[3].toDouble() : 1,
    presence: v.length > 4 ? v[4].toDouble() : 1,
  );

  static const Landmark missing = Landmark(
    x: 0,
    y: 0,
    visibility: 0,
    presence: 0,
  );

  final double x;
  final double y;
  final double z;
  final double visibility;
  final double presence;

  Vec2 get p2 => Vec2(x, y);
  Vec3 get p3 => Vec3(x, y, z);

  Landmark copyWith({
    double? x,
    double? y,
    double? z,
    double? visibility,
    double? presence,
  }) => Landmark(
    x: x ?? this.x,
    y: y ?? this.y,
    z: z ?? this.z,
    visibility: visibility ?? this.visibility,
    presence: presence ?? this.presence,
  );

  List<double> toList() => [x, y, z, visibility, presence];

  @override
  String toString() =>
      'Landmark(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, z=${z.toStringAsFixed(3)}, v=${visibility.toStringAsFixed(2)})';
}

/// One frame of pose output from the native engine.
class PoseFrame {
  PoseFrame({
    required this.timestampMs,
    required this.landmarks,
    this.worldLandmarks,
    this.width = 0,
    this.height = 0,
    this.fps,
    this.inferenceMs,
    this.brightness,
  }) : assert(landmarks.length == PoseLandmark.count, 'expected 33 landmarks'),
       assert(
         worldLandmarks == null || worldLandmarks.length == PoseLandmark.count,
         'expected 33 world landmarks',
       );

  /// A frame in which no person was detected.
  factory PoseFrame.empty(int timestampMs, {int width = 0, int height = 0}) =>
      PoseFrame(
        timestampMs: timestampMs,
        landmarks: List.filled(PoseLandmark.count, Landmark.missing),
        width: width,
        height: height,
      );

  /// Compact JSON: `{"t":..,"w":..,"h":..,"lm":[165 numbers],"world":[99]?}`.
  factory PoseFrame.fromJson(Map<String, dynamic> json) {
    final lm = (json['lm'] as List<dynamic>).cast<num>();
    final landmarks = List<Landmark>.generate(
      PoseLandmark.count,
      (i) => Landmark.fromList(lm.sublist(i * 5, i * 5 + 5)),
    );
    List<Vec3>? world;
    final w = json['world'];
    if (w is List && w.isNotEmpty) {
      final ws = w.cast<num>();
      world = List<Vec3>.generate(
        PoseLandmark.count,
        (i) => Vec3(
          ws[i * 3].toDouble(),
          ws[i * 3 + 1].toDouble(),
          ws[i * 3 + 2].toDouble(),
        ),
      );
    }
    return PoseFrame(
      timestampMs: (json['t'] as num).toInt(),
      width: (json['w'] as num?)?.toInt() ?? 0,
      height: (json['h'] as num?)?.toInt() ?? 0,
      landmarks: landmarks,
      worldLandmarks: world,
      fps: (json['fps'] as num?)?.toDouble(),
      inferenceMs: (json['inf'] as num?)?.toDouble(),
      brightness: (json['br'] as num?)?.toDouble(),
    );
  }

  final int timestampMs;
  final int width;
  final int height;

  /// 33 landmarks in normalized image coordinates.
  final List<Landmark> landmarks;

  /// 33 landmarks in metres, hip-centred (MediaPipe "world landmarks").
  final List<Vec3>? worldLandmarks;

  final double? fps;
  final double? inferenceMs;

  /// Mean luma of the frame (0..1) if the native layer reports it.
  final double? brightness;

  /// Width / height; 1 when the size is unknown.
  double get aspect => (width > 0 && height > 0) ? width / height : 1;

  bool get hasPose => landmarks.any((l) => l.visibility > 0 || l.presence > 0);

  Landmark operator [](PoseLandmark l) => landmarks[l.index];

  Vec3? world(PoseLandmark l) => worldLandmarks?[l.index];

  double meanVisibility(Iterable<PoseLandmark> ls) {
    var sum = 0.0;
    var n = 0;
    for (final l in ls) {
      sum += landmarks[l.index].visibility;
      n++;
    }
    return n == 0 ? 0 : sum / n;
  }

  PoseFrame copyWith({List<Landmark>? landmarks, List<Vec3>? worldLandmarks}) =>
      PoseFrame(
        timestampMs: timestampMs,
        landmarks: landmarks ?? this.landmarks,
        worldLandmarks: worldLandmarks ?? this.worldLandmarks,
        width: width,
        height: height,
        fps: fps,
        inferenceMs: inferenceMs,
        brightness: brightness,
      );

  Map<String, dynamic> toJson() => {
    't': timestampMs,
    'w': width,
    'h': height,
    'lm': [for (final l in landmarks) ...l.toList()],
    if (worldLandmarks != null)
      'world': [
        for (final w in worldLandmarks!) ...[w.x, w.y, w.z],
      ],
    if (fps != null) 'fps': fps,
    if (inferenceMs != null) 'inf': inferenceMs,
    if (brightness != null) 'br': brightness,
  };
}
