import 'dart:convert';

import '../pose_frame.dart';
import '../rules/exercise_definition.dart';

/// Ground-truth error labels for one rep (or one hold) of a fixture.
class FixtureLabel {
  const FixtureLabel({required this.rep, required this.rules});

  factory FixtureLabel.fromJson(Map<String, dynamic> j) => FixtureLabel(
    rep: (j['rep'] as num).toInt(),
    rules: ((j['rules'] as List<dynamic>?) ?? const []).cast<String>(),
  );

  /// 1-based rep index.
  final int rep;
  final List<String> rules;

  Map<String, dynamic> toJson() => {'rep': rep, 'rules': rules};
}

/// A recorded (or synthetic) landmark sequence with labels
/// (`docs/fixtures-schema.md`). No video, no identity.
class LandmarkFixture {
  const LandmarkFixture({
    required this.id,
    required this.exerciseId,
    required this.view,
    required this.frames,
    this.schemaVersion = 1,
    this.person = 'anon',
    this.environment = 'unknown',
    this.device,
    this.modelVariant,
    this.recordedAt,
    this.synthetic = false,
    this.expectedReps,
    this.expectedHoldMs,
    this.errorLabels = const [],
    this.notes,
  });

  factory LandmarkFixture.fromJson(Map<String, dynamic> j) {
    final view = CameraView.parse(j['view'] as String? ?? '');
    if (view == null) throw FormatException('fixture ${j['id']}: bad view');
    return LandmarkFixture(
      id: j['id'] as String,
      schemaVersion: (j['schemaVersion'] as num?)?.toInt() ?? 1,
      exerciseId: j['exerciseId'] as String,
      view: view,
      person: j['person'] as String? ?? 'anon',
      environment: j['environment'] as String? ?? 'unknown',
      device: j['device'] as String?,
      modelVariant: j['modelVariant'] as String?,
      recordedAt: j['recordedAt'] as String?,
      synthetic: j['synthetic'] as bool? ?? false,
      expectedReps: (j['expectedReps'] as num?)?.toInt(),
      expectedHoldMs: (j['expectedHoldMs'] as num?)?.toInt(),
      errorLabels: [
        for (final l in (j['errorLabels'] as List<dynamic>?) ?? const [])
          FixtureLabel.fromJson(l as Map<String, dynamic>),
      ],
      notes: j['notes'] as String?,
      frames: [
        for (final f in j['frames'] as List<dynamic>)
          PoseFrame.fromJson(f as Map<String, dynamic>),
      ],
    );
  }

  static LandmarkFixture parse(String jsonText) =>
      LandmarkFixture.fromJson(json.decode(jsonText) as Map<String, dynamic>);

  final int schemaVersion;
  final String id;
  final String exerciseId;
  final CameraView view;
  final String person;
  final String environment;
  final String? device;
  final String? modelVariant;
  final String? recordedAt;
  final bool synthetic;
  final int? expectedReps;
  final int? expectedHoldMs;
  final List<FixtureLabel> errorLabels;
  final String? notes;
  final List<PoseFrame> frames;

  int get durationMs =>
      frames.isEmpty ? 0 : frames.last.timestampMs - frames.first.timestampMs;

  Set<String> labeledRulesForRep(int rep) => {
    for (final l in errorLabels)
      if (l.rep == rep) ...l.rules,
  };

  /// How many reps were labeled with each rule.
  Map<String, int> get labeledRuleCounts {
    final out = <String, int>{};
    for (final l in errorLabels) {
      for (final r in l.rules.toSet()) {
        out[r] = (out[r] ?? 0) + 1;
      }
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'exerciseId': exerciseId,
    'view': view.name,
    'person': person,
    'environment': environment,
    if (device != null) 'device': device,
    if (modelVariant != null) 'modelVariant': modelVariant,
    if (recordedAt != null) 'recordedAt': recordedAt,
    'synthetic': synthetic,
    if (expectedReps != null) 'expectedReps': expectedReps,
    if (expectedHoldMs != null) 'expectedHoldMs': expectedHoldMs,
    'errorLabels': [for (final l in errorLabels) l.toJson()],
    if (notes != null) 'notes': notes,
    'frames': [for (final f in frames) f.toJson()],
  };

  String toJsonString({bool pretty = false}) => pretty
      ? const JsonEncoder.withIndent('  ').convert(toJson())
      : json.encode(toJson());
}

/// Plays a fixture back as frames, either as fast as possible (tests) or in
/// real time (UI development without a camera).
class FixtureReplayer {
  const FixtureReplayer(this.fixture);

  final LandmarkFixture fixture;

  /// Synchronous, instant.
  Iterable<PoseFrame> frames() => fixture.frames;

  /// Real-time (or [speed]× faster) playback; loops when [loop] is true.
  Stream<PoseFrame> stream({double speed = 1.0, bool loop = false}) async* {
    var offset = 0;
    do {
      PoseFrame? prev;
      for (final f in fixture.frames) {
        if (prev != null) {
          final delta = ((f.timestampMs - prev.timestampMs) / speed).round();
          if (delta > 0) {
            await Future<void>.delayed(Duration(milliseconds: delta));
          }
        }
        yield offset == 0 ? f : _shift(f, offset);
        prev = f;
      }
      offset += fixture.durationMs + 500;
    } while (loop);
  }

  static PoseFrame _shift(PoseFrame f, int offsetMs) => PoseFrame(
    timestampMs: f.timestampMs + offsetMs,
    landmarks: f.landmarks,
    worldLandmarks: f.worldLandmarks,
    width: f.width,
    height: f.height,
    fps: f.fps,
    inferenceMs: f.inferenceMs,
    brightness: f.brightness,
  );
}
