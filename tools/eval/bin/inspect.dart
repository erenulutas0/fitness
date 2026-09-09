// Inspect a single recorded fixture: what the engine sees, rep by rep.
//
//   dart run bin/inspect.dart ../../data/fixtures/take.json
//
// Answers the question a recording session actually asks — "the take felt
// clean / sloppy, did the engine agree?" — by printing per-rep timing, the
// depth reached, the score and which rules fired, next to the human labels.
import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:forma_rules/forma_rules.dart';

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('content', abbr: 'c', defaultsTo: '../../content')
    ..addFlag('smoothing', defaultsTo: true)
    ..addFlag('raw', help: 'Also dump the rep signal per frame.')
    ..addFlag(
      'rep-times',
      help:
          'Print one "rep,extremeMs,depth" line per rep and nothing else, so '
          'a script can cut a picture of each rep out of the video.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final args = parser.parse(argv);
  if (args['help'] as bool || args.rest.isEmpty) {
    stdout.writeln(
      'usage: dart run bin/inspect.dart <fixture.json> [options]\n${parser.usage}',
    );
    return;
  }

  final fixture = LandmarkFixture.parse(
    await File(args.rest.first).readAsString(),
  );
  final def = ExerciseDefinition.parse(
    await File(
      '${args['content']}/exercises/${fixture.exerciseId}.json',
    ).readAsString(),
  );
  final smoothing = args['smoothing'] as bool;

  final session = ExerciseSession(
    definition: def,
    view: fixture.view,
    config: SessionConfig(
      smoothing: smoothing ? const SmoothingConfig() : SmoothingConfig.none,
    ),
  );

  // Track the rep signal alongside the session so depth can be reported.
  final extractor = FeatureExtractor();
  final smoother = LandmarkSmoother(
    smoothing ? const SmoothingConfig() : SmoothingConfig.none,
  );
  final spec = def.repFor(fixture.view);
  final signalExpr = spec?.signalExpr;
  const evaluator = ExpressionEvaluator();
  final signal = <(int, double)>[];
  final liveCues = <String>[];
  var lostFrames = 0;

  for (final f in fixture.frames) {
    for (final e in session.process(f)) {
      if (e is SessionRuleTriggered &&
          e.rule.evaluateAt == EvaluateAt.instant) {
        liveCues.add(
          '${(e.tMs / 1000).toStringAsFixed(1)}s ${e.rule.ruleId}'
          ' (conf ${e.rule.confidence.toStringAsFixed(2)})',
        );
      }
    }
    final fs = extractor.extract(smoother.smooth(f));
    if ((fs.value('vis_core') ?? 0) < 0.5) lostFrames++;
    if (signalExpr != null) {
      try {
        final v = evaluator.eval(signalExpr, FrameScope(fs));
        if (v.confidence >= 0.4) signal.add((f.timestampMs, v.asDouble));
      } on ExpressionException {
        // signal unavailable on this frame
      }
    }
  }
  final result = session.finish();

  if (args['rep-times'] as bool) {
    for (final r in result.reps) {
      stdout.writeln(
        '${r.index},${r.summary.extremeMs},'
        '${r.summary.extremeValue.toStringAsFixed(1)}',
      );
    }
    return;
  }

  stdout
    ..writeln('# ${fixture.id}')
    ..writeln(
      '${def.name.tr} · ${fixture.view.name} · ${fixture.person} · '
      '${fixture.environment} · model ${fixture.modelVariant ?? '-'} · '
      '${fixture.device ?? 'unknown device'}',
    )
    ..writeln(
      '${fixture.frames.length} frames · ${(fixture.durationMs / 1000).toStringAsFixed(1)} s · '
      'smoothing ${smoothing ? 'on' : 'off'} · '
      'frames with weak tracking: $lostFrames',
    )
    ..writeln();

  if (spec != null) {
    stdout.writeln(
      'rep signal "${spec.signal}": rest ${spec.restThreshold.toStringAsFixed(0)}, '
      'peak ${spec.peakThreshold.toStringAsFixed(0)}, hysteresis ${spec.hysteresis.toStringAsFixed(0)}',
    );
    if (signal.isNotEmpty) {
      final values = [for (final s in signal) s.$2];
      stdout.writeln(
        '  observed: min ${values.reduce(math.min).toStringAsFixed(0)}, '
        'max ${values.reduce(math.max).toStringAsFixed(0)}, '
        'mean ${(values.reduce((a, b) => a + b) / values.length).toStringAsFixed(0)}'
        ' (${values.length} usable frames)',
      );
    }
    stdout.writeln();
  }

  stdout
    ..writeln(
      'reps detected: ${result.repCount}'
      '${fixture.expectedReps == null ? '' : ' · labelled: ${fixture.expectedReps}'}',
    )
    ..writeln();
  if (result.reps.isNotEmpty) {
    stdout
      ..writeln(
        '| rep | start | dur | down | up | depth | score | engine says | you labelled |',
      )
      ..writeln('|---|---|---|---|---|---|---|---|---|');
    for (final r in result.reps) {
      final labelled = fixture.labeledRulesForRep(r.index);
      stdout.writeln(
        '| ${r.index} '
        '| ${(r.summary.startMs / 1000).toStringAsFixed(1)}s '
        '| ${(r.summary.durationMs / 1000).toStringAsFixed(1)}s '
        '| ${(r.tempoDownMs / 1000).toStringAsFixed(1)}s '
        '| ${(r.tempoUpMs / 1000).toStringAsFixed(1)}s '
        '| ${r.summary.extremeValue.toStringAsFixed(0)}° '
        '| ${r.score.rounded} '
        '| ${r.failedRules.isEmpty ? '-' : r.failedRules.join(', ')} '
        '| ${labelled.isEmpty ? '-' : labelled.join(', ')} |',
      );
    }
    stdout.writeln();
  }
  for (final h in result.holds) {
    stdout.writeln(
      'hold ${h.index}: ${(h.heldMs / 1000).toStringAsFixed(1)}s · score ${h.score.rounded} · '
      '${h.failedRules.isEmpty ? 'clean' : h.failedRules.join(', ')}',
    );
  }

  final counts = result.errorCounts;
  stdout.writeln('rule totals: ${counts.isEmpty ? 'none fired' : counts}');
  if (fixture.errorLabels.isEmpty) {
    stdout.writeln(
      'labels: none recorded (treated as "every rep clean" by the eval harness)',
    );
  } else {
    stdout.writeln('labels: ${fixture.labeledRuleCounts}');
  }
  if (liveCues.isNotEmpty) {
    stdout
      ..writeln()
      ..writeln('live cues during the take:');
    for (final c in liveCues) {
      stdout.writeln('  $c');
    }
  }

  if (args['raw'] as bool) {
    stdout
      ..writeln()
      ..writeln('t_ms,signal');
    for (final s in signal) {
      stdout.writeln('${s.$1},${s.$2.toStringAsFixed(1)}');
    }
  }
}
