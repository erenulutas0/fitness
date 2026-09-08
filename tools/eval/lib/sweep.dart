/// Threshold sweep (docs/10 Prompt 9).
///
/// Replays the labelled corpus over a grid of parameter values and reports
/// which value scores best. It never writes anything back to `content/`:
/// CLAUDE.md says thresholds are tuned with the harness, and a number that
/// wins on a handful of recordings is a suggestion, not a decision.
library;

import 'dart:convert';

import 'package:forma_rules/forma_rules.dart';

import 'forma_eval.dart';

/// A definition as plain, mutable JSON. Going through encode/decode rather
/// than using `toJson()` directly matters: the literals inside `toJson()` are
/// typed maps (`Map<String, Map<String, dynamic>>`), and writing a number into
/// one of those throws at run time.
Map<String, dynamic> _mutableJson(ExerciseDefinition def) =>
    json.decode(json.encode(def.toJson())) as Map<String, dynamic>;

/// Numeric literal in a rule expression, ignoring digits inside identifiers
/// (`knee_angle_3d`) and the fractional halves of a decimal.
final _literal = RegExp(r'(?<![A-Za-z0-9_.])(\d+(?:\.\d+)?)(?![A-Za-z0-9_.])');

/// Thrown for a malformed `--sweep` argument or an unknown parameter path.
class SweepException implements Exception {
  SweepException(this.message);

  final String message;

  @override
  String toString() => 'SweepException: $message';
}

/// One tunable number and the values to try for it.
class SweepAxis {
  SweepAxis({required this.path, required this.values, this.exerciseId});

  /// Parses `[<exerciseId>/]<path>=<range>`, where the range is either
  /// `start:end:step` or a comma-separated list.
  factory SweepAxis.parse(String spec, {String? defaultExercise}) {
    final eq = spec.indexOf('=');
    if (eq <= 0) {
      throw SweepException('"$spec" is not <path>=<range>');
    }
    var path = spec.substring(0, eq).trim();
    var exercise = defaultExercise;
    final slash = path.indexOf('/');
    if (slash >= 0) {
      exercise = path.substring(0, slash);
      path = path.substring(slash + 1);
    }
    final values = parseRange(spec.substring(eq + 1).trim());
    if (values.isEmpty) throw SweepException('"$spec" has no values');
    return SweepAxis(path: path, values: values, exerciseId: exercise);
  }

  static List<double> parseRange(String text) {
    if (text.contains(':')) {
      final parts = text.split(':');
      if (parts.length != 3) {
        throw SweepException('range "$text" must be start:end:step');
      }
      final start = _number(parts[0], text);
      final end = _number(parts[1], text);
      final step = _number(parts[2], text);
      if (step <= 0) throw SweepException('range "$text": step must be > 0');
      if (end < start) throw SweepException('range "$text": end < start');
      final out = <double>[];
      // Walk by multiples rather than accumulating, so 0.05 steps do not drift.
      for (var i = 0; start + i * step <= end + 1e-9; i++) {
        out.add(_round(start + i * step));
      }
      return out;
    }
    return [
      for (final t in text.split(',')) _number(t, text),
    ];
  }

  static double _number(String s, String context) {
    final v = double.tryParse(s.trim());
    if (v == null) throw SweepException('"$context": "$s" is not a number');
    return v;
  }

  static double _round(double v) => double.parse(v.toStringAsFixed(6));

  final String path;
  final List<double> values;

  /// Which exercise the path belongs to; null for session-level paths.
  final String? exerciseId;

  bool get isSessionLevel =>
      path.startsWith('smoothing.') || path.startsWith('session.');

  /// The rule this axis tunes, if any — used to pick a sensible objective.
  String? get ruleId => path.startsWith('rules.') ? path.split('.')[1] : null;

  String get label =>
      isSessionLevel || exerciseId == null ? path : '$exerciseId/$path';

  @override
  String toString() => '$label=${values.join(",")}';
}

/// What the sweep maximises (or minimises, for rep MAE).
class SweepObjective {
  const SweepObjective._(
    this.label,
    this.higherIsBetter,
    this._read, [
    this.ruleId,
  ]);

  factory SweepObjective.parse(String spec) {
    if (spec.startsWith('rule-f1:')) {
      return SweepObjective.ruleF1(spec.substring('rule-f1:'.length));
    }
    return switch (spec) {
      'f1' => const SweepObjective._('F1', true, _overallF1),
      'precision' => const SweepObjective._(
        'precision',
        true,
        _overallPrecision,
      ),
      'recall' => const SweepObjective._('recall', true, _overallRecall),
      'rep-mae' => const SweepObjective._('rep MAE', false, _repMae),
      _ => throw SweepException(
        'unknown objective "$spec" '
        '(f1 | precision | recall | rep-mae | rule-f1:<ruleId>)',
      ),
    };
  }

  /// Scores one rule instead of the whole exercise, which is what you want
  /// when the sweep is about that rule's threshold.
  factory SweepObjective.ruleF1(String ruleId) => SweepObjective._(
    '$ruleId F1',
    true,
    (r, ex) => r.exercises[ex]?.rules[ruleId]?.f1 ?? 0,
    ruleId,
  );

  /// The objective that fits the axes when the caller did not choose one:
  /// a sweep over rep thresholds is about counting, a sweep over one rule is
  /// about that rule, anything else falls back to the exercise F1.
  factory SweepObjective.forAxes(List<SweepAxis> axes) {
    final ruleIds = {for (final a in axes) a.ruleId}..remove(null);
    if (ruleIds.length == 1) return SweepObjective.ruleF1(ruleIds.first!);
    final tunesCounting = axes.every(
      (a) => a.path.startsWith('rep.') || a.isSessionLevel,
    );
    if (tunesCounting) return SweepObjective.parse('rep-mae');
    return SweepObjective.parse('f1');
  }

  static double _overallF1(EvalReport r, String ex) =>
      r.exercises[ex]?.overall.f1 ?? 0;
  static double _overallPrecision(EvalReport r, String ex) =>
      r.exercises[ex]?.overall.precision ?? 0;
  static double _overallRecall(EvalReport r, String ex) =>
      r.exercises[ex]?.overall.recall ?? 0;
  static double _repMae(EvalReport r, String ex) =>
      r.exercises[ex]?.repMae ?? double.infinity;

  final String label;
  final bool higherIsBetter;
  final double Function(EvalReport, String) _read;

  /// Set when the objective scores a single rule rather than the exercise.
  final String? ruleId;

  double read(EvalReport report, String exerciseId) =>
      _read(report, exerciseId);

  /// True when [a] is a better score than [b].
  bool isBetter(double a, double b) => higherIsBetter ? a > b : a < b;
}

/// One grid point: the values tried and what the corpus scored with them.
class SweepPoint {
  SweepPoint({
    required this.values,
    required this.score,
    required this.report,
    required this.exerciseId,
  });

  final List<double> values;
  final double score;
  final EvalReport report;
  final String exerciseId;

  ExerciseStats? get stats => report.exercises[exerciseId];
  double get precision => stats?.overall.precision ?? 0;
  double get recall => stats?.overall.recall ?? 0;
  double get f1 => stats?.overall.f1 ?? 0;
  double get repMae => stats?.repMae ?? 0;
  double get cuesPerRep => stats?.cuesPerRep ?? 0;
}

/// The full result of a sweep, ready to print.
class SweepResult {
  SweepResult({
    required this.axes,
    required this.objective,
    required this.points,
    required this.baseline,
    required this.currentValues,
    required this.exerciseId,
    required this.warnings,
    required this.supported,
  });

  final List<SweepAxis> axes;
  final SweepObjective objective;
  final List<SweepPoint> points;

  /// The corpus scored with the values that are in `content/` today.
  final SweepPoint baseline;
  final List<double> currentValues;
  final String exerciseId;
  final List<String> warnings;

  /// Whether the corpus can rank these values at all. Without a single
  /// labelled error, "best F1" only means "fires least often", and a sweep
  /// that names a winner from that would be inviting a wrong threshold.
  final bool supported;

  SweepPoint get best => points.reduce(
    (a, b) => objective.isBetter(a.score, b.score) ? a : b,
  );

  /// True when the winner is indistinguishable from what we already ship.
  bool get isNoise => (best.score - baseline.score).abs() < 0.01;

  /// True when the winner only ties the current value.
  bool get keepsCurrent =>
      !objective.isBetter(best.score, baseline.score) || isNoise;

  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('# Threshold sweep — $exerciseId')
      ..writeln()
      ..writeln(
        'Objective: **${objective.label}** '
        '(${objective.higherIsBetter ? 'higher' : 'lower'} is better) · '
        'grid points: ${points.length} · fixtures: ${baseline.report.fixtureCount}',
      )
      ..writeln();

    if (warnings.isNotEmpty) {
      b.writeln('> **Read this before believing the table.**');
      for (final w in warnings) {
        b.writeln('> - $w');
      }
      b.writeln();
    }

    b
      ..writeln('## Suggestion')
      ..writeln();
    if (!supported) {
      for (var i = 0; i < axes.length; i++) {
        b.writeln('- `${axes[i].label}`: now **${_num(currentValues[i])}**');
      }
      b
        ..writeln()
        ..writeln(
          '**No suggestion.** This corpus cannot rank these values — see the '
          'note above. The grid is printed for information (the cues/rep '
          'column still shows how often each value would speak up), but a '
          'winner picked from it would only be the value that stays quiet.',
        );
    } else {
      for (var i = 0; i < axes.length; i++) {
        b.writeln(
          '- `${axes[i].label}`: now **${_num(currentValues[i])}**, '
          'best **${_num(best.values[i])}**',
        );
      }
      b
        ..writeln()
        ..writeln(
          '${objective.label}: ${_score(baseline.score)} → '
          '${_score(best.score)}'
          '${keepsCurrent ? ' — **no reason to change**' : ''}',
        )
        ..writeln()
        ..writeln(
          keepsCurrent
              ? 'The grid found nothing better than the current values (or the '
                    'difference is inside the noise of this corpus). Leave '
                    '`content/` alone.'
              : 'Nothing was written. Change `content/` by hand only if the '
                    'gain survives a look at the recordings it comes from.',
        );
    }
    b
      ..writeln()
      ..writeln('## Grid')
      ..writeln();

    // The objective gets its own bolded column; a standard column showing the
    // same number is just noise.
    final columns = <String, String Function(SweepPoint)>{
      'precision': (p) => _pct(p.precision),
      'recall': (p) => _pct(p.recall),
      'F1': (p) => _pct(p.f1),
      'rep MAE': (p) => p.repMae.toStringAsFixed(2),
      'cues/rep': (p) => p.cuesPerRep.toStringAsFixed(2),
    }..remove(objective.label);
    final header = [
      for (final a in axes) a.label,
      objective.label,
      ...columns.keys,
    ];
    b
      ..writeln('| ${header.join(' | ')} |')
      ..writeln('|${List.filled(header.length, '---').join('|')}|');
    final sorted = [...points]
      ..sort((x, y) => objective.isBetter(x.score, y.score) ? -1 : 1);
    for (final p in sorted) {
      final marks = <String>[
        for (final v in p.values) _num(v),
        '**${_score(p.score)}**',
        for (final cell in columns.values) cell(p),
      ];
      final current = _sameValues(p.values, currentValues) ? ' ←şu an' : '';
      b.writeln('| ${marks.join(' | ')} |$current');
    }
    return b.toString();
  }

  static bool _sameValues(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 1e-9) return false;
    }
    return true;
  }

  static String _num(double v) => v == v.roundToDouble() && v.abs() < 1e6
      ? v.toStringAsFixed(v.abs() < 1 ? 2 : 0)
      : v.toStringAsFixed(3);

  /// Scores always get the same number of decimals, so a column of them can
  /// be compared by eye.
  static String _score(double v) =>
      v.isFinite ? v.toStringAsFixed(3) : v.toString();
  static String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
}

/// Runs the grid. [maxPoints] guards against a sweep that would take hours.
SweepResult runSweep({
  required EvalCorpus corpus,
  required List<SweepAxis> axes,
  required String exerciseId,
  SweepObjective? objective,
  int maxPoints = 512,
}) {
  if (axes.isEmpty) throw SweepException('nothing to sweep');
  if (!corpus.definitions.containsKey(exerciseId)) {
    throw SweepException('unknown exercise "$exerciseId"');
  }
  final obj = objective ?? SweepObjective.forAxes(axes);
  var total = 1;
  for (final a in axes) {
    total *= a.values.length;
  }
  if (total > maxPoints) {
    throw SweepException(
      '$total grid points is more than the $maxPoints limit; '
      'narrow the ranges or raise --max-points',
    );
  }

  final currentValues = [
    for (final a in axes) _readCurrent(corpus, a, exerciseId),
  ];
  final points = <SweepPoint>[];
  for (final combo in _product([for (final a in axes) a.values])) {
    points.add(
      _evaluate(
        corpus: corpus,
        axes: axes,
        values: combo,
        exerciseId: exerciseId,
        objective: obj,
      ),
    );
  }
  final baseline = _evaluate(
    corpus: corpus,
    axes: axes,
    values: currentValues,
    exerciseId: exerciseId,
    objective: obj,
  );
  final support = _support(corpus, axes, exerciseId, obj);

  return SweepResult(
    axes: axes,
    objective: obj,
    points: points,
    baseline: baseline,
    currentValues: currentValues,
    exerciseId: exerciseId,
    warnings: support.warnings,
    supported: support.supported,
  );
}

/// Honest warnings about what this corpus can and cannot answer, plus whether
/// it can answer at all.
({List<String> warnings, bool supported}) _support(
  EvalCorpus corpus,
  List<SweepAxis> axes,
  String exerciseId,
  SweepObjective objective,
) {
  final out = <String>[];
  final relevant = corpus.fixtures.where((f) => f.exerciseId == exerciseId);
  final labelledUnits = <String, int>{};
  var labelledFixtures = 0;
  for (final fx in relevant) {
    if (fx.errorLabels.isNotEmpty) labelledFixtures++;
    for (final label in fx.errorLabels) {
      for (final id in label.rules) {
        labelledUnits[id] = (labelledUnits[id] ?? 0) + 1;
      }
    }
  }
  if (labelledFixtures == 0) {
    out.add(
      'No recording of $exerciseId carries an error label, so recall and F1 '
      'are measured against "every rep was clean". This sweep can only tell '
      'you which value fires least, not which value is right.',
    );
  }
  for (final axis in axes) {
    final ruleId = axis.ruleId;
    if (ruleId == null) continue;
    final n = labelledUnits[ruleId] ?? 0;
    if (n < 10) {
      out.add(
        'Rule `$ruleId` has $n labelled rep${n == 1 ? '' : 's'} in this '
        'corpus. Below ~10 the F1 column moves on single reps — treat the '
        'ranking as a hint, not a measurement.',
      );
    }
  }
  final countsReps = relevant.any((f) => f.expectedReps != null);
  if (!objective.higherIsBetter && !countsReps) {
    out.add(
      'No fixture declares expectedReps, so rep MAE is 0 everywhere and the '
      'ranking is meaningless.',
    );
  }
  final supported = objective.higherIsBetter
      ? (objective.ruleId != null
            ? (labelledUnits[objective.ruleId] ?? 0) > 0
            : labelledUnits.isNotEmpty)
      : countsReps;
  return (warnings: out, supported: supported);
}

SweepPoint _evaluate({
  required EvalCorpus corpus,
  required List<SweepAxis> axes,
  required List<double> values,
  required String exerciseId,
  required SweepObjective objective,
}) {
  final knobs = _SessionKnobs();
  final patched = <String, Map<String, dynamic>>{};
  for (var i = 0; i < axes.length; i++) {
    final axis = axes[i];
    if (axis.isSessionLevel) {
      knobs.apply(axis.path, values[i]);
      continue;
    }
    final id = axis.exerciseId ?? exerciseId;
    final patchedJson = patched.putIfAbsent(
      id,
      () => _mutableJson(corpus.definitions[id]!),
    );
    applyOverride(patchedJson, axis.path, values[i]);
  }
  final overrides = <String, ExerciseDefinition>{
    for (final e in patched.entries)
      e.key: ExerciseDefinition.fromJson(e.value),
  };
  for (final def in overrides.values) {
    final errors = def.validate();
    if (errors.isNotEmpty) {
      throw SweepException('${def.id} invalid at $values: ${errors.first}');
    }
  }
  final report = corpus.evaluate(
    overrides: overrides,
    config: knobs.build(),
  );
  return SweepPoint(
    values: values,
    score: objective.read(report, exerciseId),
    report: report,
    exerciseId: exerciseId,
  );
}

Iterable<List<double>> _product(List<List<double>> lists) sync* {
  final idx = List.filled(lists.length, 0);
  while (true) {
    yield [for (var i = 0; i < lists.length; i++) lists[i][idx[i]]];
    var d = lists.length - 1;
    while (d >= 0) {
      idx[d]++;
      if (idx[d] < lists[d].length) break;
      idx[d] = 0;
      d--;
    }
    if (d < 0) return;
  }
}

/// Session-level knobs, seeded from the values the app actually ships.
class _SessionKnobs {
  static const _base = SessionConfig();
  static const _smooth = SmoothingConfig();

  double minCutoff = _smooth.minCutoff;
  double beta = _smooth.beta;
  double dCutoff = _smooth.dCutoff;
  double minTrackingConfidence = _base.minTrackingConfidence;
  double minSignalConfidence = _base.minSignalConfidence;
  double extractorMinVisibility = _base.extractorMinVisibility;
  double maxBodyHeightFraction = _base.maxBodyHeightFraction;
  double maxShinThighRatio = _base.maxShinThighRatio;

  void apply(String path, double value) {
    switch (path) {
      case 'smoothing.minCutoff':
        minCutoff = value;
      case 'smoothing.beta':
        beta = value;
      case 'smoothing.dCutoff':
        dCutoff = value;
      case 'session.minTrackingConfidence':
        minTrackingConfidence = value;
      case 'session.minSignalConfidence':
        minSignalConfidence = value;
      case 'session.extractorMinVisibility':
        extractorMinVisibility = value;
      case 'session.maxBodyHeightFraction':
        maxBodyHeightFraction = value;
      case 'session.maxShinThighRatio':
        maxShinThighRatio = value;
      default:
        throw SweepException('unknown session path "$path"');
    }
  }

  SessionConfig build() => SessionConfig(
    smoothing: SmoothingConfig(
      minCutoff: minCutoff,
      beta: beta,
      dCutoff: dCutoff,
      resetAfterGapMs: _smooth.resetAfterGapMs,
    ),
    minTrackingConfidence: minTrackingConfidence,
    minSignalConfidence: minSignalConfidence,
    extractorMinVisibility: extractorMinVisibility,
    maxBodyHeightFraction: maxBodyHeightFraction,
    maxShinThighRatio: maxShinThighRatio,
  );
}

double _readCurrent(EvalCorpus corpus, SweepAxis axis, String exerciseId) {
  if (axis.isSessionLevel) {
    final knobs = _SessionKnobs();
    return switch (axis.path) {
      'smoothing.minCutoff' => knobs.minCutoff,
      'smoothing.beta' => knobs.beta,
      'smoothing.dCutoff' => knobs.dCutoff,
      'session.minTrackingConfidence' => knobs.minTrackingConfidence,
      'session.minSignalConfidence' => knobs.minSignalConfidence,
      'session.extractorMinVisibility' => knobs.extractorMinVisibility,
      'session.maxBodyHeightFraction' => knobs.maxBodyHeightFraction,
      'session.maxShinThighRatio' => knobs.maxShinThighRatio,
      _ => throw SweepException('unknown session path "${axis.path}"'),
    };
  }
  final id = axis.exerciseId ?? exerciseId;
  final def = corpus.definitions[id];
  if (def == null) throw SweepException('unknown exercise "$id"');
  return readOverride(_mutableJson(def), axis.path);
}

/// Reads the value a path points at, so the report can say what we ship today.
double readOverride(Map<String, dynamic> json, String path) {
  final parts = path.split('.');
  if (parts.length >= 3 &&
      parts[0] == 'rules' &&
      parts[2].startsWith('threshold')) {
    final rule = _findRule(json, parts[1]);
    final wanted = _wantedLiteral(parts[2]);
    final found = _literals(rule['expr'] as String);
    if (found.isEmpty) {
      throw SweepException('rule ${parts[1]}: no number in "${rule['expr']}"');
    }
    if (wanted != null) return wanted;
    if (found.length > 1) {
      throw SweepException(
        'rule ${parts[1]}: "${rule['expr']}" has more than one threshold '
        '(${found.join(", ")}); say which with threshold@<value>',
      );
    }
    return found.first;
  }
  final target = _resolve(json, parts);
  final value = target.map[target.key];
  if (value is! num) {
    throw SweepException('"$path" is not a number (it is $value)');
  }
  return value.toDouble();
}

/// Writes `path = value` into a decoded exercise JSON map, in place.
void applyOverride(Map<String, dynamic> json, String path, double value) {
  final parts = path.split('.');
  if (parts.length >= 3 &&
      parts[0] == 'rules' &&
      parts[2].startsWith('threshold')) {
    final rule = _findRule(json, parts[1]);
    rule['expr'] = _rewriteLiteral(
      rule['expr'] as String,
      _wantedLiteral(parts[2]),
      value,
      parts[1],
    );
    return;
  }
  final target = _resolve(json, parts);
  if (!target.map.containsKey(target.key)) {
    throw SweepException('"$path" does not exist in ${json['id']}');
  }
  if (target.map[target.key] is! num) {
    throw SweepException('"$path" is not a number');
  }
  target.map[target.key] = _isIntField(target.key) ? value.round() : value;
}

bool _isIntField(String key) => const {
  'minDurationMs',
  'maxDurationMs',
  'minHoldMs',
  'exitGraceMs',
  'refireMs',
  'minConsecutiveFrames',
  'minGatedFrames',
  'severity',
  'version',
}.contains(key);

({Map<String, dynamic> map, String key}) _resolve(
  Map<String, dynamic> json,
  List<String> parts,
) {
  if (parts.length < 2) {
    throw SweepException('"${parts.join(".")}" is too short to be a path');
  }
  if (parts[0] == 'rules') {
    if (parts.length != 3) {
      throw SweepException('rule paths look like rules.<id>.<field>');
    }
    return (map: _findRule(json, parts[1]), key: parts[2]);
  }
  var map = json;
  for (var i = 0; i < parts.length - 1; i++) {
    final next = map[parts[i]];
    if (next is! Map<String, dynamic>) {
      // `rep.restThreshold` on a per-view rep block is ambiguous; be explicit.
      throw SweepException(
        '"${parts.sublist(0, i + 1).join(".")}" is not an object '
        '${parts[0] == 'rep' ? '(name the view: rep.side.<field>)' : ''}',
      );
    }
    map = next;
  }
  return (map: map, key: parts.last);
}

Map<String, dynamic> _findRule(Map<String, dynamic> json, String id) {
  final rules = (json['rules'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>();
  for (final r in rules) {
    if (r['id'] == id) return r;
  }
  throw SweepException('${json['id']}: no rule "$id"');
}

double? _wantedLiteral(String field) {
  final at = field.indexOf('@');
  if (at < 0) return null;
  final v = double.tryParse(field.substring(at + 1));
  if (v == null) throw SweepException('"$field": @ needs a number');
  return v;
}

List<double> _literals(String expr) {
  final seen = <double>{};
  for (final m in _literal.allMatches(expr)) {
    seen.add(double.parse(m.group(1)!));
  }
  return seen.toList()..sort();
}

/// Replaces a threshold inside a rule expression.
///
/// `knee_ankle_ratio_l < 0.85 || knee_ankle_ratio_r < 0.85` holds one
/// threshold written twice, so every occurrence of the same number moves
/// together; an expression with several different numbers has to say which.
String _rewriteLiteral(String expr, double? wanted, double value, String id) {
  final found = _literals(expr);
  if (found.isEmpty) throw SweepException('rule $id: no number in "$expr"');
  final target = wanted ?? (found.length == 1 ? found.first : null);
  if (target == null) {
    throw SweepException(
      'rule $id: "$expr" has more than one threshold '
      '(${found.join(", ")}); say which with threshold@<value>',
    );
  }
  if (!found.contains(target)) {
    throw SweepException('rule $id: "$expr" has no threshold $target');
  }
  final text = _format(value);
  var replaced = 0;
  final out = expr.replaceAllMapped(_literal, (m) {
    if (double.parse(m.group(1)!) != target) return m.group(0)!;
    replaced++;
    return text;
  });
  if (replaced == 0) throw SweepException('rule $id: nothing replaced');
  return out;
}

String _format(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
