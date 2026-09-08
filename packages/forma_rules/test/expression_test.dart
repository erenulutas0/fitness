import 'package:forma_rules/forma_rules.dart';
import 'package:test/test.dart';

class _MapScope implements EvalScope {
  _MapScope(this.vars, {this.landmarks = const {}});

  final Map<String, EvalValue> vars;
  final Map<String, double> landmarks;

  @override
  EvalValue? variable(String name) => vars[name];

  @override
  EvalValue? landmarkCall(String fn, List<String> landmarkNames) {
    final key = '$fn(${landmarkNames.join(',')})';
    final v = landmarks[key];
    return v == null ? null : EvalValue.scalar(v);
  }
}

void main() {
  const ev = ExpressionEvaluator();
  double evalNum(String src, [Map<String, EvalValue> vars = const {}]) =>
      ev.eval(ExpressionParser.parse(src), _MapScope(vars)).asDouble;

  group('parser + evaluator', () {
    test('arithmetic precedence', () {
      expect(evalNum('1 + 2 * 3'), 7);
      expect(evalNum('(1 + 2) * 3'), 9);
      expect(evalNum('10 / 4 - 1'), 1.5);
      expect(evalNum('-3 * -2'), 6);
      expect(evalNum('2 * 3 + 4 * 5'), 26);
    });

    test('comparisons and logic', () {
      expect(evalNum('3 < 4'), 1);
      expect(evalNum('3 >= 4'), 0);
      expect(evalNum('3 < 4 && 5 > 6'), 0);
      expect(evalNum('3 < 4 || 5 > 6'), 1);
      expect(evalNum('!(3 < 4)'), 0);
      expect(evalNum('1 == 1 && 2 != 3'), 1);
      expect(evalNum('true && !false'), 1);
    });

    test('logic binds looser than comparison', () {
      expect(evalNum('1 < 2 || 3 < 2 && 0'), 1);
    });

    test('variables and confidence propagate', () {
      final scope = _MapScope({
        'a': const EvalValue.scalar(100, confidence: 0.9),
        'b': const EvalValue.scalar(50, confidence: 0.4),
      });
      final v = ev.eval(ExpressionParser.parse('a - b > 10'), scope);
      expect(v.truthy, isTrue);
      expect(v.confidence, 0.4);
    });

    test('builtins on scalars', () {
      expect(evalNum('min(3, 9)'), 3);
      expect(evalNum('max(3, 9)'), 9);
      expect(evalNum('abs(-4)'), 4);
      expect(evalNum('sqrt(16)'), 4);
      expect(evalNum('clamp(15, 0, 10)'), 10);
    });

    test('series reducers', () {
      final scope = _MapScope({
        's': const EvalValue.series([3, 1, 4, 1, 5], confidence: 0.8),
      });
      Expr p(String s) => ExpressionParser.parse(s);
      expect(ev.eval(p('min(s)'), scope).asDouble, 1);
      expect(ev.eval(p('max(s)'), scope).asDouble, 5);
      expect(ev.eval(p('mean(s)'), scope).asDouble, closeTo(2.8, 1e-9));
      expect(ev.eval(p('first(s)'), scope).asDouble, 3);
      expect(ev.eval(p('last(s)'), scope).asDouble, 5);
      expect(ev.eval(p('range(s)'), scope).asDouble, 4);
      expect(ev.eval(p('count(s)'), scope).asDouble, 5);
      expect(ev.eval(p('min(s) > 0 && max(s) < 6'), scope).truthy, isTrue);
      // elementwise arithmetic on a series, then reduce
      expect(ev.eval(p('max(s * 2 + 1)'), scope).asDouble, 11);
      expect(ev.eval(p('mean(s > 2)'), scope).asDouble, closeTo(0.6, 1e-9));
    });

    test('landmark functions receive raw names', () {
      final scope = _MapScope({}, landmarks: {'angle(hip,knee,ankle)': 95});
      final v = ev.eval(
        ExpressionParser.parse('angle(hip, knee, ankle) < 100'),
        scope,
      );
      expect(v.truthy, isTrue);
    });

    test('division by zero does not throw', () {
      expect(evalNum('1 / 0'), double.infinity);
      expect(evalNum('0 / 0'), 0);
    });

    test('unknown identifier throws at eval', () {
      expect(() => evalNum('foo + 1'), throwsA(isA<ExpressionException>()));
    });

    test('syntax errors throw at parse', () {
      expect(
        () => ExpressionParser.parse('1 +'),
        throwsA(isA<ExpressionException>()),
      );
      expect(
        () => ExpressionParser.parse('(1 + 2'),
        throwsA(isA<ExpressionException>()),
      );
      expect(
        () => ExpressionParser.parse('1 # 2'),
        throwsA(isA<ExpressionException>()),
      );
    });

    test('wrong arity throws at eval', () {
      expect(() => evalNum('min()'), throwsA(isA<ExpressionException>()));
      expect(() => evalNum('clamp(1, 2)'), throwsA(isA<ExpressionException>()));
    });
  });

  group('validator', () {
    final validator = ExpressionValidator(
      variables: FeatureNames.all,
      isPoint: FeatureNames.isPoint,
    );

    test('accepts the documented squat rules', () {
      for (final src in [
        'knee_ankle_ratio_l < 0.85 || knee_ankle_ratio_r < 0.85',
        'min(angle(hip, knee, ankle)) > 110',
        'min(knee_angle) > 105',
        'max(torso_angle) > 55',
        'hip_line_deviation > 0.045',
        'body_line_angle > 150 && torso_angle > 55 && vis_core > 0.5',
      ]) {
        expect(
          validator.validate(ExpressionParser.parse(src)),
          isEmpty,
          reason: src,
        );
      }
    });

    test('rejects unknown names and bad arity', () {
      expect(
        validator.validate(ExpressionParser.parse('knee_angel > 1')),
        isNotEmpty,
      );
      expect(
        validator.validate(ExpressionParser.parse('angle(hip, knee)')),
        isNotEmpty,
      );
      expect(
        validator.validate(ExpressionParser.parse('angle(hip, kne, ankle)')),
        isNotEmpty,
      );
      expect(validator.validate(ExpressionParser.parse('foo(1)')), isNotEmpty);
      expect(
        validator.validate(ExpressionParser.parse('mean(1, 2)')),
        isNotEmpty,
      );
    });

    test('referencedIdentifiers collects names', () {
      final ids = referencedIdentifiers(
        ExpressionParser.parse('a + min(b) > angle(hip, knee, ankle)'),
      );
      expect(ids, {'a', 'b', 'hip', 'knee', 'ankle'});
    });
  });
}
