import 'package:forma_rules/forma_rules.dart';
import 'package:test/test.dart';

void main() {
  group('angleDeg2', () {
    test('straight line is 180', () {
      expect(
        angleDeg2(Vec2.zero, const Vec2(1, 0), const Vec2(2, 0)),
        closeTo(180, 1e-9),
      );
    });
    test('right angle is 90', () {
      expect(
        angleDeg2(const Vec2(0, 1), Vec2.zero, const Vec2(1, 0)),
        closeTo(90, 1e-9),
      );
    });
    test('degenerate returns 0', () {
      expect(
        angleDeg2(const Vec2(1, 1), const Vec2(1, 1), const Vec2(2, 2)),
        0,
      );
    });
  });

  group('angleDeg3', () {
    test('matches 2D when z is 0', () {
      expect(
        angleDeg3(const Vec3(0, 1, 0), Vec3.zero, const Vec3(1, 0, 0)),
        closeTo(90, 1e-9),
      );
    });
  });

  group('angleFromVerticalDeg', () {
    test('up is 0, horizontal is 90, down is 180', () {
      expect(
        angleFromVerticalDeg(Vec2.zero, const Vec2(0, -1)),
        closeTo(0, 1e-9),
      );
      expect(
        angleFromVerticalDeg(Vec2.zero, const Vec2(1, 0)),
        closeTo(90, 1e-9),
      );
      expect(
        angleFromVerticalDeg(Vec2.zero, const Vec2(0, 1)),
        closeTo(180, 1e-9),
      );
    });
  });

  group('signedOffsetFromLine', () {
    test('below the line (larger y) is positive', () {
      final d = signedOffsetFromLine(
        const Vec2(0.5, 0.2),
        Vec2.zero,
        const Vec2(1, 0),
      );
      expect(d, closeTo(0.2, 1e-9));
    });
    test('above the line is negative', () {
      final d = signedOffsetFromLine(
        const Vec2(0.5, -0.3),
        Vec2.zero,
        const Vec2(1, 0),
      );
      expect(d, closeTo(-0.3, 1e-9));
    });
    test('independent of line direction', () {
      final a = signedOffsetFromLine(
        const Vec2(0.5, 0.2),
        Vec2.zero,
        const Vec2(1, 0),
      );
      final b = signedOffsetFromLine(
        const Vec2(0.5, 0.2),
        const Vec2(1, 0),
        Vec2.zero,
      );
      expect(a, closeTo(b, 1e-9));
    });
  });
}
