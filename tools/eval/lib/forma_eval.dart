/// Evaluation library: fixtures → pipeline → precision / recall / F1.
library;

import 'dart:io';

import 'package:forma_rules/forma_rules.dart';

class RuleStats {
  int tp = 0;
  int fp = 0;
  int fn = 0;

  double get precision => tp + fp == 0 ? 1 : tp / (tp + fp);
  double get recall => tp + fn == 0 ? 1 : tp / (tp + fn);
  double get f1 => precision + recall == 0
      ? 0
      : 2 * precision * recall / (precision + recall);

  Map<String, Object?> toJson() => {
    'tp': tp,
    'fp': fp,
    'fn': fn,
    'precision': precision,
    'recall': recall,
    'f1': f1,
  };
}

class ExerciseStats {
  ExerciseStats(this.exerciseId);

  final String exerciseId;
  final Map<String, RuleStats> rules = {};
  int fixtures = 0;
  int labeledReps = 0;
  int detectedReps = 0;
  double repAbsError = 0;
  int repFixtures = 0;
  int cues = 0;

  RuleStats rule(String id) => rules.putIfAbsent(id, RuleStats.new);

  double get repMae => repFixtures == 0 ? 0 : repAbsError / repFixtures;
  double get cuesPerRep => detectedReps == 0 ? 0 : cues / detectedReps;

  /// Micro-averaged over all rule decisions of this exercise.
  RuleStats get overall {
    final s = RuleStats();
    for (final r in rules.values) {
      s
        ..tp += r.tp
        ..fp += r.fp
        ..fn += r.fn;
    }
    return s;
  }

  Map<String, Object?> toJson() => {
    'exerciseId': exerciseId,
    'fixtures': fixtures,
    'repMae': repMae,
    'cuesPerRep': cuesPerRep,
    'overall': overall.toJson(),
    'rules': {for (final e in rules.entries) e.key: e.value.toJson()},
  };
}

class EvalReport {
  EvalReport({
    required this.exercises,
    required this.fixtureCount,
    required this.smoothing,
    required this.generatedAt,
  });

  final Map<String, ExerciseStats> exercises;
  final int fixtureCount;
  final bool smoothing;
  final DateTime generatedAt;
  final List<String> warnings = [];

  bool get meetsGate2 => exercises.values.every(
    (e) => e.overall.precision >= 0.8 && e.overall.recall >= 0.7,
  );

  Map<String, Object?> toJson() => {
    'generatedAt': generatedAt.toIso8601String(),
    'fixtures': fixtureCount,
    'smoothing': smoothing,
    'meetsGate2': meetsGate2,
    'exercises': {for (final e in exercises.entries) e.key: e.value.toJson()},
    'warnings': warnings,
  };

  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('# FORMA eval report')
      ..writeln()
      ..writeln(
        'Generated: ${generatedAt.toIso8601String()} · fixtures: $fixtureCount · smoothing: $smoothing · '
        '**Gate 2: ${meetsGate2 ? 'PASS' : 'FAIL'}** (precision ≥ 0.80, recall ≥ 0.70 per exercise)',
      )
      ..writeln()
      ..writeln(
        '| Exercise | Fixtures | Rep MAE | Cues/rep | Precision | Recall | F1 |',
      )
      ..writeln('|---|---|---|---|---|---|---|');
    for (final e in exercises.values) {
      final o = e.overall;
      b.writeln(
        '| ${e.exerciseId} | ${e.fixtures} | ${e.repMae.toStringAsFixed(2)} | ${e.cuesPerRep.toStringAsFixed(2)} | '
        '${_pct(o.precision)} | ${_pct(o.recall)} | ${_pct(o.f1)} |',
      );
    }
    b
      ..writeln()
      ..writeln('## Per rule')
      ..writeln()
      ..writeln('| Exercise | Rule | TP | FP | FN | Precision | Recall | F1 |')
      ..writeln('|---|---|---|---|---|---|---|---|');
    for (final e in exercises.values) {
      for (final r in e.rules.entries) {
        final s = r.value;
        b.writeln(
          '| ${e.exerciseId} | ${r.key} | ${s.tp} | ${s.fp} | ${s.fn} | ${_pct(s.precision)} | ${_pct(s.recall)} | ${_pct(s.f1)} |',
        );
      }
    }
    if (warnings.isNotEmpty) {
      b
        ..writeln()
        ..writeln('## Warnings')
        ..writeln();
      for (final w in warnings) {
        b.writeln('- $w');
      }
    }
    return b.toString();
  }

  static String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
}

Future<EvalReport> runEvaluation({
  required List<Directory> fixtureDirs,
  required Directory contentRoot,
  bool smoothing = true,
}) async {
  final definitions = <String, ExerciseDefinition>{};
  final exDir = Directory('${contentRoot.path}/exercises');
  for (final f in exDir.listSync().whereType<File>().where(
    (f) => f.path.endsWith('.json'),
  )) {
    final def = ExerciseDefinition.parse(f.readAsStringSync());
    definitions[def.id] = def;
  }
  final cuesFile = File('${contentRoot.path}/cues/cues.json');
  final catalog = cuesFile.existsSync()
      ? CueCatalog.parse(cuesFile.readAsStringSync())
      : const CueCatalog({});

  final report = EvalReport(
    exercises: {},
    fixtureCount: 0,
    smoothing: smoothing,
    generatedAt: DateTime.now(),
  );
  var count = 0;
  for (final dir in fixtureDirs) {
    if (!dir.existsSync()) {
      report.warnings.add('fixture dir not found: ${dir.path}');
      continue;
    }
    final files =
        dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      LandmarkFixture fx;
      try {
        fx = LandmarkFixture.parse(file.readAsStringSync());
      } on Object catch (e) {
        report.warnings.add('${file.path}: $e');
        continue;
      }
      final def = definitions[fx.exerciseId];
      if (def == null) {
        report.warnings.add('${fx.id}: unknown exercise ${fx.exerciseId}');
        continue;
      }
      count++;
      final stats = report.exercises.putIfAbsent(
        def.id,
        () => ExerciseStats(def.id),
      );
      stats.fixtures++;
      _evaluateFixture(fx, def, catalog, stats, smoothing: smoothing);
    }
  }
  return EvalReport(
    exercises: report.exercises,
    fixtureCount: count,
    smoothing: smoothing,
    generatedAt: report.generatedAt,
  )..warnings.addAll(report.warnings);
}

void _evaluateFixture(
  LandmarkFixture fx,
  ExerciseDefinition def,
  CueCatalog catalog,
  ExerciseStats stats, {
  required bool smoothing,
}) {
  final session = ExerciseSession(
    definition: def,
    view: fx.view,
    config: SessionConfig(
      smoothing: smoothing ? const SmoothingConfig() : SmoothingConfig.none,
    ),
  );
  final scheduler = FeedbackScheduler(catalog: catalog);
  var cues = 0;
  for (final f in fx.frames) {
    final events = session.process(f);
    cues += scheduler
        .handle(events, nowMs: f.timestampMs)
        .where((c) => c.ruleId != null)
        .length;
  }
  final result = session.finish();
  stats
    ..cues += cues
    ..detectedReps += result.repCount;

  final expected = fx.expectedReps;
  if (expected != null) {
    stats
      ..repFixtures += 1
      ..repAbsError += (result.repCount - expected).abs()
      ..labeledReps += expected;
  }

  final ruleIds = {for (final r in def.rulesFor(fx.view)) r.id};
  final units = <(int, Set<String>)>[
    for (final r in result.reps) (r.index, r.failedRules.toSet()),
    for (final h in result.holds) (h.index, h.failedRules.toSet()),
  ];
  for (final (index, detected) in units) {
    final labeled = fx.labeledRulesForRep(index);
    for (final id in ruleIds) {
      final d = detected.contains(id);
      final l = labeled.contains(id);
      final s = stats.rule(id);
      if (d && l) {
        s.tp++;
      } else if (d && !l) {
        s.fp++;
      } else if (!d && l) {
        s.fn++;
      }
    }
  }
  // Labeled reps that were never detected count as misses for their rules.
  final detectedIndices = {for (final u in units) u.$1};
  for (final label in fx.errorLabels) {
    if (detectedIndices.contains(label.rep)) continue;
    for (final id in label.rules) {
      if (ruleIds.contains(id)) stats.rule(id).fn++;
    }
  }
}
