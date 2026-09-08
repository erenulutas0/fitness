import 'dart:typed_data';

import 'package:forma_rules/forma_rules.dart';

/// Binary wire format shared by the Android/iOS engines and Dart.
///
/// Little-endian:
/// ```text
/// header (40 bytes)
///   int64  timestampMs
///   int32  width
///   int32  height
///   float  fps
///   float  inferenceMs
///   float  brightness      (0..1, or -1 if unknown)
///   int32  rotationDeg     (already applied; informational)
///   int32  hasPose         (0/1)
///   int32  hasWorld        (0/1)
/// body
///   33 × (x, y, z, visibility, presence) float32   = 660 bytes
///   [33 × (x, y, z) float32 if hasWorld]           = 396 bytes
/// ```
abstract final class PoseFrameCodec {
  static const int headerBytes = 40;
  static const int landmarkBytes = PoseLandmark.count * 5 * 4;
  static const int worldBytes = PoseLandmark.count * 3 * 4;
  static const int frameBytesWithoutWorld = headerBytes + landmarkBytes;
  static const int frameBytesWithWorld =
      headerBytes + landmarkBytes + worldBytes;

  static PoseFrame decode(ByteData d) {
    if (d.lengthInBytes < headerBytes) {
      throw const FormatException('pose frame too short');
    }
    const e = Endian.little;
    final ts = d.getInt64(0, e);
    final w = d.getInt32(8, e);
    final h = d.getInt32(12, e);
    final fps = d.getFloat32(16, e);
    final inf = d.getFloat32(20, e);
    final br = d.getFloat32(24, e);
    final hasPose = d.getInt32(32, e) != 0;
    final hasWorld = d.getInt32(36, e) != 0;
    if (!hasPose) {
      return PoseFrame.empty(ts, width: w, height: h);
    }
    if (d.lengthInBytes < frameBytesWithoutWorld) {
      throw const FormatException('pose frame body too short');
    }
    var o = headerBytes;
    final landmarks = List<Landmark>.generate(PoseLandmark.count, (i) {
      final l = Landmark(
        x: d.getFloat32(o, e),
        y: d.getFloat32(o + 4, e),
        z: d.getFloat32(o + 8, e),
        visibility: d.getFloat32(o + 12, e),
        presence: d.getFloat32(o + 16, e),
      );
      o += 20;
      return l;
    });
    List<Vec3>? world;
    if (hasWorld && d.lengthInBytes >= frameBytesWithWorld) {
      world = List<Vec3>.generate(PoseLandmark.count, (i) {
        final v = Vec3(
          d.getFloat32(o, e),
          d.getFloat32(o + 4, e),
          d.getFloat32(o + 8, e),
        );
        o += 12;
        return v;
      });
    }
    return PoseFrame(
      timestampMs: ts,
      width: w,
      height: h,
      landmarks: landmarks,
      worldLandmarks: world,
      fps: fps > 0 ? fps : null,
      inferenceMs: inf > 0 ? inf : null,
      brightness: br >= 0 ? br : null,
    );
  }

  /// Encode (used by tests and the fake engine to round-trip frames).
  static ByteData encode(PoseFrame f, {int rotationDeg = 0}) {
    final hasWorld = f.worldLandmarks != null;
    final hasPose = f.hasPose;
    final size = !hasPose
        ? headerBytes
        : (hasWorld ? frameBytesWithWorld : frameBytesWithoutWorld);
    const e = Endian.little;
    final d = ByteData(size)
      ..setInt64(0, f.timestampMs, e)
      ..setInt32(8, f.width, e)
      ..setInt32(12, f.height, e)
      ..setFloat32(16, f.fps ?? -1, e)
      ..setFloat32(20, f.inferenceMs ?? -1, e)
      ..setFloat32(24, f.brightness ?? -1, e)
      ..setInt32(28, rotationDeg, e)
      ..setInt32(32, hasPose ? 1 : 0, e)
      ..setInt32(36, hasWorld ? 1 : 0, e);
    if (!hasPose) return d;
    var o = headerBytes;
    for (final l in f.landmarks) {
      d
        ..setFloat32(o, l.x, e)
        ..setFloat32(o + 4, l.y, e)
        ..setFloat32(o + 8, l.z, e)
        ..setFloat32(o + 12, l.visibility, e)
        ..setFloat32(o + 16, l.presence, e);
      o += 20;
    }
    if (hasWorld) {
      for (final w in f.worldLandmarks!) {
        d
          ..setFloat32(o, w.x, e)
          ..setFloat32(o + 4, w.y, e)
          ..setFloat32(o + 8, w.z, e);
        o += 12;
      }
    }
    return d;
  }
}
