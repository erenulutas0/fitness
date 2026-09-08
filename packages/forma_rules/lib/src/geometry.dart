import 'dart:math' as math;

/// Immutable 2D vector (image space: x right, y down).
class Vec2 {
  const Vec2(this.x, this.y);

  final double x;
  final double y;

  static const zero = Vec2(0, 0);

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);
  Vec2 operator /(double s) => Vec2(x / s, y / s);
  Vec2 operator -() => Vec2(-x, -y);

  double get length => math.sqrt(x * x + y * y);
  double dot(Vec2 o) => x * o.x + y * o.y;

  /// 2D cross product (z component).
  double cross(Vec2 o) => x * o.y - y * o.x;

  Vec2 get normalized {
    final l = length;
    return l == 0 ? zero : this / l;
  }

  static Vec2 mid(Vec2 a, Vec2 b) => Vec2((a.x + b.x) / 2, (a.y + b.y) / 2);

  static double distance(Vec2 a, Vec2 b) => (a - b).length;

  @override
  String toString() => 'Vec2(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)})';
}

/// Immutable 3D vector.
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const zero = Vec3(0, 0, 0);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  Vec3 operator /(double s) => Vec3(x / s, y / s, z / s);

  double get length => math.sqrt(x * x + y * y + z * z);
  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  Vec3 get normalized {
    final l = length;
    return l == 0 ? zero : this / l;
  }

  static Vec3 mid(Vec3 a, Vec3 b) =>
      Vec3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2);

  static double distance(Vec3 a, Vec3 b) => (a - b).length;

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

double degrees(double radians) => radians * 180 / math.pi;
double radians(double deg) => deg * math.pi / 180;

/// Interior angle at [b] formed by [a]-[b]-[c], in degrees (0..180).
double angleDeg2(Vec2 a, Vec2 b, Vec2 c) {
  final v1 = a - b;
  final v2 = c - b;
  final l = v1.length * v2.length;
  if (l == 0) return 0;
  final cos = (v1.dot(v2) / l).clamp(-1.0, 1.0);
  return degrees(math.acos(cos));
}

/// Interior angle at [b] formed by [a]-[b]-[c] in 3D, degrees (0..180).
double angleDeg3(Vec3 a, Vec3 b, Vec3 c) {
  final v1 = a - b;
  final v2 = c - b;
  final l = v1.length * v2.length;
  if (l == 0) return 0;
  final cos = (v1.dot(v2) / l).clamp(-1.0, 1.0);
  return degrees(math.acos(cos));
}

/// Angle between the vector [from]→[to] and the "up" direction in image
/// space (0 = pointing straight up, 90 = horizontal, 180 = straight down).
double angleFromVerticalDeg(Vec2 from, Vec2 to) {
  final v = to - from;
  if (v.length == 0) return 0;
  const up = Vec2(0, -1);
  final cos = v.normalized.dot(up).clamp(-1.0, 1.0);
  return degrees(math.acos(cos));
}

/// Signed perpendicular offset of [p] from the line through [a] and [b].
///
/// The magnitude is the perpendicular distance; the sign is positive when
/// [p] lies *below* the line in image space (larger y), which for a
/// horizontal body (plank / push-up) means "sagging toward the floor".
double signedOffsetFromLine(Vec2 p, Vec2 a, Vec2 b) {
  final ab = b - a;
  final len = ab.length;
  if (len == 0) return 0;
  final t = (p - a).dot(ab) / (len * len);
  final proj = a + ab * t;
  final off = p - proj;
  final mag = off.length;
  if (mag == 0) return 0;
  return off.y >= 0 ? mag : -mag;
}

double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

double lerp(double a, double b, double t) => a + (b - a) * t;
