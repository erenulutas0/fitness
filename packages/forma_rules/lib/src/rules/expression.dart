import 'dart:math' as math;

/// Thrown for lexing / parsing / evaluation errors in rule expressions.
class ExpressionException implements Exception {
  ExpressionException(this.message, {this.position});

  final String message;
  final int? position;

  @override
  String toString() => position == null
      ? 'ExpressionException: $message'
      : 'ExpressionException at $position: $message';
}

// ---------------------------------------------------------------------------
// AST
// ---------------------------------------------------------------------------

sealed class Expr {
  const Expr();
}

class NumLit extends Expr {
  const NumLit(this.value);

  final double value;
}

class Ident extends Expr {
  const Ident(this.name);

  final String name;
}

class Unary extends Expr {
  const Unary(this.op, this.operand);

  final String op;
  final Expr operand;
}

class Binary extends Expr {
  const Binary(this.op, this.left, this.right);

  final String op;
  final Expr left;
  final Expr right;
}

class Call extends Expr {
  const Call(this.fn, this.args);

  final String fn;
  final List<Expr> args;
}

// ---------------------------------------------------------------------------
// Lexer + parser
// ---------------------------------------------------------------------------

enum _T { number, ident, op, lparen, rparen, comma, end }

class _Tok {
  const _Tok(this.t, this.text, this.pos, [this.value]);

  final _T t;
  final String text;
  final int pos;
  final double? value;
}

/// Recursive-descent parser for the rule DSL.
///
/// Grammar (lowest → highest precedence):
/// `||`, `&&`, `!`, comparisons (`< <= > >= == !=`), `+ -`, `* /`, unary `-`,
/// primary (number, identifier, call, parenthesised).
class ExpressionParser {
  ExpressionParser._(String src) : _toks = _lex(src);

  /// Parses [source] into an AST; throws [ExpressionException] on error.
  static Expr parse(String source) {
    final p = ExpressionParser._(source);
    final e = p._or();
    if (p._peek.t != _T.end) {
      throw ExpressionException(
        'unexpected "${p._peek.text}"',
        position: p._peek.pos,
      );
    }
    return e;
  }

  final List<_Tok> _toks;
  int _i = 0;

  _Tok get _peek => _toks[_i];
  _Tok _next() => _toks[_i++];

  bool _acceptOp(String op) {
    if (_peek.t == _T.op && _peek.text == op) {
      _i++;
      return true;
    }
    return false;
  }

  Expr _or() {
    var e = _and();
    while (_acceptOp('||')) {
      e = Binary('||', e, _and());
    }
    return e;
  }

  Expr _and() {
    var e = _not();
    while (_acceptOp('&&')) {
      e = Binary('&&', e, _not());
    }
    return e;
  }

  Expr _not() {
    if (_acceptOp('!')) return Unary('!', _not());
    return _cmp();
  }

  Expr _cmp() {
    final e = _add();
    for (final op in const ['<=', '>=', '==', '!=', '<', '>']) {
      if (_acceptOp(op)) return Binary(op, e, _add());
    }
    return e;
  }

  Expr _add() {
    var e = _mul();
    while (true) {
      if (_acceptOp('+')) {
        e = Binary('+', e, _mul());
      } else if (_acceptOp('-')) {
        e = Binary('-', e, _mul());
      } else {
        return e;
      }
    }
  }

  Expr _mul() {
    var e = _unary();
    while (true) {
      if (_acceptOp('*')) {
        e = Binary('*', e, _unary());
      } else if (_acceptOp('/')) {
        e = Binary('/', e, _unary());
      } else {
        return e;
      }
    }
  }

  Expr _unary() {
    if (_acceptOp('-')) return Unary('-', _unary());
    return _primary();
  }

  Expr _primary() {
    final t = _next();
    switch (t.t) {
      case _T.number:
        return NumLit(t.value!);
      case _T.ident:
        if (t.text == 'true') return const NumLit(1);
        if (t.text == 'false') return const NumLit(0);
        if (_peek.t == _T.lparen) {
          _next();
          final args = <Expr>[];
          if (_peek.t != _T.rparen) {
            args.add(_or());
            while (_peek.t == _T.comma) {
              _next();
              args.add(_or());
            }
          }
          if (_next().t != _T.rparen) {
            throw ExpressionException('expected ")"', position: t.pos);
          }
          return Call(t.text, args);
        }
        return Ident(t.text);
      case _T.lparen:
        final e = _or();
        if (_next().t != _T.rparen) {
          throw ExpressionException('expected ")"', position: t.pos);
        }
        return e;
      case _T.rparen:
      case _T.comma:
      case _T.op:
      case _T.end:
        throw ExpressionException(
          'unexpected "${t.text.isEmpty ? 'end of expression' : t.text}"',
          position: t.pos,
        );
    }
  }

  static const _twoCharOps = ['<=', '>=', '==', '!=', '&&', '||'];
  static const _oneCharOps = ['<', '>', '+', '-', '*', '/', '!'];

  static List<_Tok> _lex(String s) {
    final out = <_Tok>[];
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        i++;
        continue;
      }
      if (_isDigit(c) || (c == '.' && i + 1 < s.length && _isDigit(s[i + 1]))) {
        final start = i;
        while (i < s.length && (_isDigit(s[i]) || s[i] == '.')) {
          i++;
        }
        if (i < s.length && (s[i] == 'e' || s[i] == 'E')) {
          i++;
          if (i < s.length && (s[i] == '+' || s[i] == '-')) i++;
          while (i < s.length && _isDigit(s[i])) {
            i++;
          }
        }
        final text = s.substring(start, i);
        final v = double.tryParse(text);
        if (v == null) {
          throw ExpressionException('bad number "$text"', position: start);
        }
        out.add(_Tok(_T.number, text, start, v));
        continue;
      }
      if (_isIdentStart(c)) {
        final start = i;
        while (i < s.length && _isIdentPart(s[i])) {
          i++;
        }
        out.add(_Tok(_T.ident, s.substring(start, i), start));
        continue;
      }
      if (c == '(') {
        out.add(_Tok(_T.lparen, c, i++));
        continue;
      }
      if (c == ')') {
        out.add(_Tok(_T.rparen, c, i++));
        continue;
      }
      if (c == ',') {
        out.add(_Tok(_T.comma, c, i++));
        continue;
      }
      final two = i + 1 < s.length ? s.substring(i, i + 2) : '';
      if (_twoCharOps.contains(two)) {
        out.add(_Tok(_T.op, two, i));
        i += 2;
        continue;
      }
      if (_oneCharOps.contains(c)) {
        out.add(_Tok(_T.op, c, i++));
        continue;
      }
      throw ExpressionException('unexpected character "$c"', position: i);
    }
    out.add(_Tok(_T.end, '', s.length));
    return out;
  }

  static bool _isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 48 && u <= 57;
  }

  static bool _isIdentStart(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || c == '_';
  }

  static bool _isIdentPart(String c) => _isIdentStart(c) || _isDigit(c);
}

// ---------------------------------------------------------------------------
// Values + evaluation
// ---------------------------------------------------------------------------

/// A value in the DSL: a scalar or a series (one value per frame of a rep).
/// Booleans are represented as 1 / 0.
class EvalValue {
  const EvalValue.scalar(double this.scalar, {this.confidence = 1})
    : series = null;
  const EvalValue.series(List<double> this.series, {this.confidence = 1})
    : scalar = null;

  static const EvalValue trueValue = EvalValue.scalar(1);
  static const EvalValue falseValue = EvalValue.scalar(0);

  final double? scalar;
  final List<double>? series;

  /// Confidence in `[0, 1]` — min over every leaf used to compute the value.
  final double confidence;

  bool get isSeries => series != null;

  /// Truthiness of a scalar (non-zero). A series is truthy when its mean > 0.5.
  bool get truthy {
    final s = scalar;
    if (s != null) return s != 0 && !s.isNaN;
    final ser = series!;
    if (ser.isEmpty) return false;
    return ser.reduce((a, b) => a + b) / ser.length > 0.5;
  }

  /// Scalar value, or the mean of a series.
  double get asDouble {
    final s = scalar;
    if (s != null) return s;
    final ser = series!;
    return ser.isEmpty ? double.nan : ser.reduce((a, b) => a + b) / ser.length;
  }

  EvalValue withConfidence(double c) => isSeries
      ? EvalValue.series(series!, confidence: c)
      : EvalValue.scalar(scalar!, confidence: c);

  @override
  String toString() => isSeries
      ? 'series(${series!.length})@$confidence'
      : '$scalar@$confidence';
}

/// Resolves identifiers and landmark functions for the evaluator.
abstract class EvalScope {
  /// Value of a feature variable, or null if unknown.
  EvalValue? variable(String name);

  /// Landmark-level function (`angle`, `dist`, `dx`, `dy`) called with the raw
  /// landmark names written in the expression.
  EvalValue? landmarkCall(String fn, List<String> landmarkNames);
}

/// Functions whose arguments are landmark *names*, not values.
const Set<String> landmarkFunctions = {'angle', 'dist', 'dx', 'dy'};

/// Built-in numeric functions and their accepted arities.
const Map<String, List<int>> builtinFunctions = {
  'min': [1, 2],
  'max': [1, 2],
  'mean': [1],
  'first': [1],
  'last': [1],
  'range': [1],
  'count': [1],
  'abs': [1],
  'sqrt': [1],
  'clamp': [3],
};

/// Evaluates an [Expr] against an [EvalScope].
class ExpressionEvaluator {
  const ExpressionEvaluator();

  EvalValue eval(Expr e, EvalScope scope) {
    switch (e) {
      case NumLit(:final value):
        return EvalValue.scalar(value);
      case Ident(:final name):
        final v = scope.variable(name);
        if (v == null) throw ExpressionException('unknown identifier "$name"');
        return v;
      case Unary(:final op, :final operand):
        final v = eval(operand, scope);
        return switch (op) {
          '-' => _map1(v, (x) => -x),
          '!' => _map1(v, (x) => x == 0 ? 1 : 0),
          _ => throw ExpressionException('bad unary "$op"'),
        };
      case Binary(:final op, :final left, :final right):
        final l = eval(left, scope);
        final r = eval(right, scope);
        return _binary(op, l, r);
      case Call(:final fn, :final args):
        if (landmarkFunctions.contains(fn)) {
          final names = <String>[];
          for (final a in args) {
            if (a is! Ident) {
              throw ExpressionException('"$fn" expects landmark names');
            }
            names.add(a.name);
          }
          final v = scope.landmarkCall(fn, names);
          if (v == null) {
            throw ExpressionException(
              'cannot resolve $fn(${names.join(', ')})',
            );
          }
          return v;
        }
        final vals = [for (final a in args) eval(a, scope)];
        return _builtin(fn, vals);
    }
  }

  EvalValue _map1(EvalValue v, double Function(double) f) {
    final s = v.scalar;
    if (s != null) return EvalValue.scalar(f(s), confidence: v.confidence);
    return EvalValue.series(
      [for (final x in v.series!) f(x)],
      confidence: v.confidence,
    );
  }

  static double _div(double a, double b) {
    if (b != 0) return a / b;
    if (a == 0) return 0;
    return a > 0 ? double.infinity : -double.infinity;
  }

  EvalValue _binary(String op, EvalValue l, EvalValue r) {
    final c = math.min(l.confidence, r.confidence);
    double f(double a, double b) => switch (op) {
      '+' => a + b,
      '-' => a - b,
      '*' => a * b,
      '/' => _div(a, b),
      '<' => a < b ? 1 : 0,
      '<=' => a <= b ? 1 : 0,
      '>' => a > b ? 1 : 0,
      '>=' => a >= b ? 1 : 0,
      '==' => a == b ? 1 : 0,
      '!=' => a != b ? 1 : 0,
      '&&' => (a != 0 && b != 0) ? 1 : 0,
      '||' => (a != 0 || b != 0) ? 1 : 0,
      _ => throw ExpressionException('bad operator "$op"'),
    };
    return _combine(l, r, f, c);
  }

  static EvalValue _combine(
    EvalValue l,
    EvalValue r,
    double Function(double, double) f,
    double c,
  ) {
    final ls = l.scalar;
    final rs = r.scalar;
    if (ls != null && rs != null) {
      return EvalValue.scalar(f(ls, rs), confidence: c);
    }
    if (ls != null) {
      return EvalValue.series([
        for (final x in r.series!) f(ls, x),
      ], confidence: c);
    }
    if (rs != null) {
      return EvalValue.series([
        for (final x in l.series!) f(x, rs),
      ], confidence: c);
    }
    final a = l.series!;
    final b = r.series!;
    final n = math.min(a.length, b.length);
    return EvalValue.series(
      [for (var i = 0; i < n; i++) f(a[i], b[i])],
      confidence: c,
    );
  }

  EvalValue _builtin(String fn, List<EvalValue> args) {
    final arity = builtinFunctions[fn];
    if (arity == null) throw ExpressionException('unknown function "$fn"');
    if (!arity.contains(args.length)) {
      throw ExpressionException(
        '"$fn" expects ${arity.join(' or ')} argument(s), got ${args.length}',
      );
    }
    final c = args.map((a) => a.confidence).fold(1.0, math.min);

    EvalValue reduce(EvalValue v, double Function(List<double>) g) {
      final s = v.series;
      if (s == null) return EvalValue.scalar(v.scalar!, confidence: c);
      if (s.isEmpty) return const EvalValue.scalar(double.nan, confidence: 0);
      return EvalValue.scalar(g(s), confidence: c);
    }

    switch (fn) {
      case 'min':
        if (args.length == 2) return _combine(args[0], args[1], math.min, c);
        return reduce(args[0], (s) => s.reduce(math.min));
      case 'max':
        if (args.length == 2) return _combine(args[0], args[1], math.max, c);
        return reduce(args[0], (s) => s.reduce(math.max));
      case 'mean':
        return reduce(args[0], (s) => s.reduce((a, b) => a + b) / s.length);
      case 'first':
        return reduce(args[0], (s) => s.first);
      case 'last':
        return reduce(args[0], (s) => s.last);
      case 'range':
        return reduce(args[0], (s) => s.reduce(math.max) - s.reduce(math.min));
      case 'count':
        final s = args[0].series;
        return EvalValue.scalar(
          s == null ? 1 : s.length.toDouble(),
          confidence: c,
        );
      case 'abs':
        return _map1(args[0], (x) => x.abs()).withConfidence(c);
      case 'sqrt':
        return _map1(args[0], math.sqrt).withConfidence(c);
      case 'clamp':
        final lo = args[1].asDouble;
        final hi = args[2].asDouble;
        return _map1(args[0], (x) => x.clamp(lo, hi)).withConfidence(c);
    }
    throw ExpressionException('unknown function "$fn"');
  }
}

/// Static validation of an expression against a vocabulary.
class ExpressionValidator {
  const ExpressionValidator({required this.variables, required this.isPoint});

  final Set<String> variables;
  final bool Function(String name) isPoint;

  /// Returns a list of problems (empty = valid).
  List<String> validate(Expr e) {
    final errors = <String>[];
    void walk(Expr x) {
      switch (x) {
        case NumLit():
          break;
        case Ident(:final name):
          if (!variables.contains(name)) {
            errors.add('unknown identifier "$name"');
          }
        case Unary(:final operand):
          walk(operand);
        case Binary(:final left, :final right):
          walk(left);
          walk(right);
        case Call(:final fn, :final args):
          if (landmarkFunctions.contains(fn)) {
            final need = fn == 'angle' ? 3 : 2;
            if (args.length != need) {
              errors.add('"$fn" expects $need landmark names');
            }
            for (final a in args) {
              if (a is! Ident) {
                errors.add('"$fn" arguments must be landmark names');
              } else if (!isPoint(a.name)) {
                errors.add('unknown landmark "${a.name}"');
              }
            }
          } else {
            final arity = builtinFunctions[fn];
            if (arity == null) {
              errors.add('unknown function "$fn"');
            } else if (!arity.contains(args.length)) {
              errors.add('"$fn" expects ${arity.join(' or ')} argument(s)');
            }
            args.forEach(walk);
          }
      }
    }

    walk(e);
    return errors;
  }
}

/// Collects identifier names referenced by an expression.
Set<String> referencedIdentifiers(Expr e) {
  final out = <String>{};
  void walk(Expr x) {
    switch (x) {
      case NumLit():
        break;
      case Ident(:final name):
        out.add(name);
      case Unary(:final operand):
        walk(operand);
      case Binary(:final left, :final right):
        walk(left);
        walk(right);
      case Call(:final fn, :final args):
        if (landmarkFunctions.contains(fn)) {
          for (final a in args) {
            if (a is Ident) out.add(a.name);
          }
        } else {
          args.forEach(walk);
        }
    }
  }

  walk(e);
  return out;
}
