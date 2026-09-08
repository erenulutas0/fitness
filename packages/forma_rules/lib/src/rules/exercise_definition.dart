import 'dart:convert';

import '../features/feature_extractor.dart';
import '../rep/rep_detector.dart';
import 'expression.dart';

/// Camera placement relative to the user.
enum CameraView {
  front,
  side
  ;

  static CameraView? parse(String s) => switch (s.toLowerCase()) {
    'front' => CameraView.front,
    'side' => CameraView.side,
    _ => null,
  };
}

enum CountMode { reps, hold }

enum EvaluateAt { instant, repEnd }

/// Thrown when an exercise JSON is malformed.
class ExerciseDefinitionException implements Exception {
  ExerciseDefinitionException(this.message, [this.errors = const []]);

  final String message;
  final List<String> errors;

  @override
  String toString() => errors.isEmpty
      ? 'ExerciseDefinitionException: $message'
      : 'ExerciseDefinitionException: $message\n  - ${errors.join('\n  - ')}';
}

/// Text with Turkish (primary) and English variants.
class LocalizedText {
  const LocalizedText({required this.tr, required this.en});

  factory LocalizedText.fromJson(Object? json) {
    if (json is String) return LocalizedText(tr: json, en: json);
    if (json is Map) {
      final tr = json['tr'] as String? ?? json['en'] as String? ?? '';
      final en = json['en'] as String? ?? tr;
      return LocalizedText(tr: tr, en: en);
    }
    return const LocalizedText(tr: '', en: '');
  }

  final String tr;
  final String en;

  String text(String locale) => locale.startsWith('en') ? en : tr;

  Map<String, String> toJson() => {'tr': tr, 'en': en};
}

/// Rep-detection thresholds for one camera view.
class RepSpec {
  RepSpec({
    required this.signal,
    required this.restThreshold,
    required this.peakThreshold,
    this.hysteresis = 5,
    this.minDurationMs = 500,
    this.maxDurationMs,
  }) : signalExpr = ExpressionParser.parse(signal);

  factory RepSpec.fromJson(Map<String, dynamic> j) {
    final rest = (j['restThreshold'] ?? j['topThreshold']) as num?;
    final peak = (j['peakThreshold'] ?? j['bottomThreshold']) as num?;
    final signal = j['signal'] as String?;
    if (signal == null || rest == null || peak == null) {
      throw ExerciseDefinitionException(
        'rep needs "signal", "restThreshold" and "peakThreshold"',
      );
    }
    return RepSpec(
      signal: signal,
      restThreshold: rest.toDouble(),
      peakThreshold: peak.toDouble(),
      hysteresis: (j['hysteresis'] as num?)?.toDouble() ?? 5,
      minDurationMs: (j['minDurationMs'] as num?)?.toInt() ?? 500,
      maxDurationMs: (j['maxDurationMs'] as num?)?.toInt(),
    );
  }

  final String signal;
  final Expr signalExpr;
  final double restThreshold;
  final double peakThreshold;
  final double hysteresis;
  final int minDurationMs;
  final int? maxDurationMs;

  RepConfig toConfig() => RepConfig(
    restThreshold: restThreshold,
    peakThreshold: peakThreshold,
    hysteresis: hysteresis,
    minDurationMs: minDurationMs,
    maxDurationMs: maxDurationMs,
  );

  Map<String, dynamic> toJson() => {
    'signal': signal,
    'restThreshold': restThreshold,
    'peakThreshold': peakThreshold,
    'hysteresis': hysteresis,
    'minDurationMs': minDurationMs,
    if (maxDurationMs != null) 'maxDurationMs': maxDurationMs,
  };
}

/// Hold (isometric) specification.
class HoldSpec {
  HoldSpec({
    required this.condition,
    this.minHoldMs = 1000,
    this.exitGraceMs = 700,
  }) : conditionExpr = ExpressionParser.parse(condition);

  factory HoldSpec.fromJson(Map<String, dynamic> j) {
    final cond = j['condition'] as String?;
    if (cond == null) {
      throw ExerciseDefinitionException('hold needs "condition"');
    }
    return HoldSpec(
      condition: cond,
      minHoldMs: (j['minHoldMs'] as num?)?.toInt() ?? 1000,
      exitGraceMs: (j['exitGraceMs'] as num?)?.toInt() ?? 700,
    );
  }

  final String condition;
  final Expr conditionExpr;
  final int minHoldMs;
  final int exitGraceMs;

  HoldConfig toConfig() =>
      HoldConfig(minHoldMs: minHoldMs, exitGraceMs: exitGraceMs);

  Map<String, dynamic> toJson() => {
    'condition': condition,
    'minHoldMs': minHoldMs,
    'exitGraceMs': exitGraceMs,
  };
}

/// Explanation shown on the "why did I say that" card.
class RuleExplain {
  const RuleExplain({required this.text, this.sourceId});

  factory RuleExplain.fromJson(Map<String, dynamic> j) => RuleExplain(
    text: LocalizedText.fromJson(j),
    sourceId: j['source'] as String?,
  );

  final LocalizedText text;
  final String? sourceId;

  Map<String, dynamic> toJson() => {
    ...text.toJson(),
    if (sourceId != null) 'source': sourceId,
  };
}

/// One form rule.
class RuleSpec {
  RuleSpec({
    required this.id,
    required this.expr,
    this.views = const {},
    this.phases = const {},
    this.minConfidence = 0.6,
    this.severity = 2,
    this.cue,
    this.evaluateAt = EvaluateAt.instant,
    this.minFraction = 0.3,
    this.minConsecutiveFrames = 3,
    this.minGatedFrames = 3,
    this.refireMs = 5000,
    this.explain,
    this.enabled = true,
    this.disabledNote,
  }) : exprAst = ExpressionParser.parse(expr);

  factory RuleSpec.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    final expr = j['expr'] as String?;
    if (id == null || expr == null) {
      throw ExerciseDefinitionException('rule needs "id" and "expr"');
    }
    final views = <CameraView>{};
    for (final v in (j['views'] as List<dynamic>?) ?? const <dynamic>[]) {
      final cv = CameraView.parse(v as String);
      if (cv == null) {
        throw ExerciseDefinitionException('rule $id: bad view "$v"');
      }
      views.add(cv);
    }
    final phases = <RepPhase>{};
    final rawPhases = (j['phases'] ?? j['phase']) as List<dynamic>? ?? const [];
    for (final p in rawPhases) {
      final rp = RepPhase.parse(p as String);
      if (rp == null) {
        throw ExerciseDefinitionException('rule $id: bad phase "$p"');
      }
      phases.add(rp);
    }
    final evalAt = switch (j['evaluateAt'] as String? ?? 'instant') {
      'instant' => EvaluateAt.instant,
      'rep_end' || 'repEnd' => EvaluateAt.repEnd,
      final other => throw ExerciseDefinitionException(
        'rule $id: bad evaluateAt "$other"',
      ),
    };
    final explainJson = j['explain'];
    return RuleSpec(
      id: id,
      expr: expr,
      views: views,
      phases: phases,
      minConfidence: (j['minConfidence'] as num?)?.toDouble() ?? 0.6,
      severity: (j['severity'] as num?)?.toInt() ?? 2,
      cue: j['cue'] as String?,
      evaluateAt: evalAt,
      minFraction: (j['minFraction'] as num?)?.toDouble() ?? 0.3,
      minConsecutiveFrames: (j['minConsecutiveFrames'] as num?)?.toInt() ?? 3,
      minGatedFrames: (j['minGatedFrames'] as num?)?.toInt() ?? 3,
      refireMs: (j['refireMs'] as num?)?.toInt() ?? 5000,
      explain: explainJson is Map<String, dynamic>
          ? RuleExplain.fromJson(explainJson)
          : null,
      enabled: j['enabled'] as bool? ?? true,
      disabledNote: j['disabledNote'] as String?,
    );
  }

  final String id;
  final String expr;
  final Expr exprAst;

  /// Camera views the rule is reliable in (empty = all).
  final Set<CameraView> views;

  /// Rep phases the rule is evaluated in (empty = all).
  final Set<RepPhase> phases;

  /// Minimum expression confidence for the rule to fire / count.
  final double minConfidence;

  /// 1 (minor) .. 3 (critical). Drives cue priority.
  final int severity;

  /// Cue clip id played when the rule fires (null = silent, score only).
  final String? cue;

  final EvaluateAt evaluateAt;

  /// Instant rules: fraction of gated frames that must be true for the rep
  /// to count as failed.
  final double minFraction;

  /// Instant rules: consecutive true frames before a live cue fires.
  final int minConsecutiveFrames;

  /// Instant rules: minimum gated frames before the fraction is trusted.
  final int minGatedFrames;

  /// Instant rules: a live cue may re-fire within the same rep / hold after
  /// this many milliseconds (holds are long).
  final int refireMs;

  final RuleExplain? explain;

  /// A rule can be switched off in content without deleting it, so a measured
  /// decision (and the evidence behind it) is not lost. Disabled rules are
  /// never evaluated, never scored and never cued.
  final bool enabled;

  /// Why the rule is off; required whenever [enabled] is false.
  final String? disabledNote;

  bool appliesTo(CameraView view) =>
      enabled && (views.isEmpty || views.contains(view));

  bool gates(RepPhase phase) => phases.isEmpty || phases.contains(phase);

  Map<String, dynamic> toJson() => {
    'id': id,
    'expr': expr,
    if (views.isNotEmpty) 'views': [for (final v in views) v.name],
    if (phases.isNotEmpty) 'phases': [for (final p in phases) p.name],
    'minConfidence': minConfidence,
    'severity': severity,
    if (cue != null) 'cue': cue,
    'evaluateAt': evaluateAt == EvaluateAt.instant ? 'instant' : 'rep_end',
    'minFraction': minFraction,
    'minConsecutiveFrames': minConsecutiveFrames,
    'minGatedFrames': minGatedFrames,
    'refireMs': refireMs,
    if (explain != null) 'explain': explain!.toJson(),
    if (!enabled) 'enabled': false,
    if (disabledNote != null) 'disabledNote': disabledNote,
  };
}

/// Scoring weights: `score = 100 * (1 - sum(weights of failed rules))`.
class ScoreSpec {
  const ScoreSpec({
    this.weights = const {},
    this.defaultWeight = 0.2,
    this.cleanThreshold = 85,
  });

  factory ScoreSpec.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ScoreSpec();
    final w = <String, double>{};
    final raw = j['weights'] as Map<String, dynamic>? ?? const {};
    for (final e in raw.entries) {
      w[e.key] = (e.value as num).toDouble();
    }
    return ScoreSpec(
      weights: w,
      defaultWeight: (j['defaultWeight'] as num?)?.toDouble() ?? 0.2,
      cleanThreshold: (j['cleanThreshold'] as num?)?.toDouble() ?? 85,
    );
  }

  final Map<String, double> weights;
  final double defaultWeight;

  /// Rep score at or above this counts as "clean" (positive reinforcement).
  final double cleanThreshold;

  double weightFor(String ruleId) => weights[ruleId] ?? defaultWeight;

  Map<String, dynamic> toJson() => {
    'weights': weights,
    'defaultWeight': defaultWeight,
    'cleanThreshold': cleanThreshold,
  };
}

/// A complete, data-driven exercise definition (`content/exercises/*.json`).
class ExerciseDefinition {
  ExerciseDefinition({
    required this.id,
    required this.version,
    required this.name,
    required this.cameraViews,
    required this.countMode,
    required this.rep,
    required this.rules,
    this.description,
    this.hold,
    this.score = const ScoreSpec(),
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.tags = const [],
    this.status = 'draft',
  });

  factory ExerciseDefinition.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    if (id == null) throw ExerciseDefinitionException('exercise needs "id"');
    final views = <CameraView>[];
    for (final v in (j['cameraViews'] as List<dynamic>?) ?? const <dynamic>[]) {
      final cv = CameraView.parse(v as String);
      if (cv == null) {
        throw ExerciseDefinitionException('$id: bad camera view "$v"');
      }
      views.add(cv);
    }
    if (views.isEmpty) {
      throw ExerciseDefinitionException('$id: cameraViews is empty');
    }

    final mode = switch (j['countMode'] as String? ?? 'reps') {
      'reps' => CountMode.reps,
      'hold' => CountMode.hold,
      final other => throw ExerciseDefinitionException(
        '$id: bad countMode "$other"',
      ),
    };

    final rep = <CameraView, RepSpec>{};
    final rawRep = j['rep'];
    if (rawRep is Map<String, dynamic>) {
      if (rawRep.containsKey('signal')) {
        final spec = RepSpec.fromJson(rawRep);
        for (final v in views) {
          rep[v] = spec;
        }
      } else {
        for (final e in rawRep.entries) {
          final cv = CameraView.parse(e.key);
          if (cv == null) {
            throw ExerciseDefinitionException('$id: bad rep view "${e.key}"');
          }
          rep[cv] = RepSpec.fromJson(e.value as Map<String, dynamic>);
        }
      }
    }
    final rawHold = j['hold'];
    final hold = rawHold is Map<String, dynamic>
        ? HoldSpec.fromJson(rawHold)
        : null;

    final rules = <RuleSpec>[];
    for (final r in (j['rules'] as List<dynamic>?) ?? const <dynamic>[]) {
      rules.add(RuleSpec.fromJson(r as Map<String, dynamic>));
    }

    List<String> strings(String key) =>
        ((j[key] as List<dynamic>?) ?? const <dynamic>[]).cast<String>();

    return ExerciseDefinition(
      id: id,
      version: (j['version'] as num?)?.toInt() ?? 1,
      name: LocalizedText.fromJson(j['name']),
      description: j['description'] == null
          ? null
          : LocalizedText.fromJson(j['description']),
      cameraViews: views,
      countMode: mode,
      rep: rep,
      hold: hold,
      rules: rules,
      score: ScoreSpec.fromJson(j['score'] as Map<String, dynamic>?),
      primaryMuscles: strings('primaryMuscles'),
      secondaryMuscles: strings('secondaryMuscles'),
      tags: strings('tags'),
      status: j['status'] as String? ?? 'draft',
    );
  }

  /// Parses JSON text and validates it; throws on any problem.
  static ExerciseDefinition parse(String jsonText) {
    final decoded = json.decode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw ExerciseDefinitionException('exercise JSON must be an object');
    }
    final def = ExerciseDefinition.fromJson(decoded);
    final errors = def.validate();
    if (errors.isNotEmpty) {
      throw ExerciseDefinitionException('${def.id} is invalid', errors);
    }
    return def;
  }

  final String id;
  final int version;
  final LocalizedText name;
  final LocalizedText? description;
  final List<CameraView> cameraViews;
  final CountMode countMode;
  final Map<CameraView, RepSpec> rep;
  final HoldSpec? hold;
  final List<RuleSpec> rules;
  final ScoreSpec score;

  /// FMA ids of the muscles primarily loaded (anatomy layer, v0.2).
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> tags;

  /// `draft` | `beta` | `stable` — drives what the app exposes.
  final String status;

  RepSpec? repFor(CameraView view) => rep[view];

  Iterable<RuleSpec> rulesFor(CameraView view) =>
      rules.where((r) => r.appliesTo(view));

  /// Static validation: expressions, views, thresholds, weights.
  List<String> validate() {
    final errors = <String>[];
    final validator = ExpressionValidator(
      variables: FeatureNames.all,
      isPoint: FeatureNames.isPoint,
    );

    void check(String what, Expr e) {
      for (final err in validator.validate(e)) {
        errors.add('$what: $err');
      }
    }

    if (countMode == CountMode.reps) {
      for (final v in cameraViews) {
        final r = rep[v];
        if (r == null) {
          errors.add('no rep spec for view ${v.name}');
          continue;
        }
        check('rep.${v.name}.signal', r.signalExpr);
        if (r.restThreshold == r.peakThreshold) {
          errors.add('rep.${v.name}: rest and peak thresholds are equal');
        }
        if (r.hysteresis < 0 ||
            r.hysteresis >= (r.restThreshold - r.peakThreshold).abs()) {
          errors.add(
            'rep.${v.name}: hysteresis must be >= 0 and smaller than the threshold gap',
          );
        }
      }
    } else {
      final h = hold;
      if (h == null) {
        errors.add('countMode is hold but no "hold" spec');
      } else {
        check('hold.condition', h.conditionExpr);
      }
    }

    final ids = <String>{};
    for (final r in rules) {
      if (!ids.add(r.id)) errors.add('duplicate rule id "${r.id}"');
      check('rule ${r.id}', r.exprAst);
      if (r.severity < 1 || r.severity > 3) {
        errors.add('rule ${r.id}: severity must be 1..3');
      }
      if (r.minConfidence < 0 || r.minConfidence > 1) {
        errors.add('rule ${r.id}: minConfidence must be 0..1');
      }
      for (final v in r.views) {
        if (!cameraViews.contains(v)) {
          errors.add('rule ${r.id}: view ${v.name} not in cameraViews');
        }
      }
      if (countMode == CountMode.hold && r.evaluateAt == EvaluateAt.repEnd) {
        errors.add(
          'rule ${r.id}: rep_end rules are evaluated when the hold ends',
        );
      }
      if (!r.enabled && (r.disabledNote?.isEmpty ?? true)) {
        errors.add('rule ${r.id}: a disabled rule needs a disabledNote');
      }
    }
    for (final w in score.weights.keys) {
      if (!ids.contains(w)) errors.add('score weight for unknown rule "$w"');
    }
    return errors;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'status': status,
    'name': name.toJson(),
    if (description != null) 'description': description!.toJson(),
    'cameraViews': [for (final v in cameraViews) v.name],
    'countMode': countMode.name,
    'primaryMuscles': primaryMuscles,
    'secondaryMuscles': secondaryMuscles,
    'tags': tags,
    if (rep.isNotEmpty)
      'rep': {for (final e in rep.entries) e.key.name: e.value.toJson()},
    if (hold != null) 'hold': hold!.toJson(),
    'rules': [for (final r in rules) r.toJson()],
    'score': score.toJson(),
  };
}
