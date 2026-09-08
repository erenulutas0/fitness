// FORMA threshold sweep (docs/10 Prompt 9).
//
//   dart run bin/sweep.dart --exercise bw_squat --fixtures ../../data/fixtures
//       --sweep rules.shallow_depth.threshold=95:120:5
//
// Replays the labelled corpus once per grid point and prints which value wins.
// It never edits content/: CLAUDE.md says thresholds are tuned with the
// harness, and the harness output is an argument, not a commit.
import 'dart:io';

import 'package:args/args.dart';
import 'package:forma_eval/forma_eval.dart';
import 'package:forma_eval/sweep.dart';

const _examples = '''
Examples (one line each):
  # is 105 degrees the right line between a deep and a shallow squat?
  dart run bin/sweep.dart -e bw_squat -s rules.shallow_depth.threshold=95:120:2.5

  # rep counting: both FSM thresholds together, scored on rep MAE
  dart run bin/sweep.dart -e bw_squat -s rep.side.restThreshold=145:165:5 -s rep.side.peakThreshold=115:135:5

  # how much smoothing does the signal actually need?
  dart run bin/sweep.dart -e bw_squat -s smoothing.minCutoff=0.5:3:0.5 -s smoothing.beta=0:0.3:0.1

Paths:
  rep.<view>.<field>          restThreshold, peakThreshold, hysteresis,
                              minDurationMs, maxDurationMs
  rules.<id>.threshold        the number inside the rule expression
  rules.<id>.threshold@<v>    ... when the expression holds several numbers
  rules.<id>.<field>          minConfidence, minFraction, minConsecutiveFrames,
                              minGatedFrames, refireMs, severity
  hold.<field>                minHoldMs, exitGraceMs
  score.<field>               cleanThreshold, defaultWeight, weights.<ruleId>
  smoothing.<field>           minCutoff, beta, dCutoff
  session.<field>             minTrackingConfidence, minSignalConfidence,
                              extractorMinVisibility, maxShinThighRatio,
                              maxBodyHeightFraction

A range is start:end:step or a comma-separated list. Prefix a path with
"<exerciseId>/" to tune an exercise other than the one being scored.
''';

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addMultiOption(
      'sweep',
      abbr: 's',
      help: 'Parameter to try, as <path>=<range>. Repeat for a grid.',
    )
    ..addOption(
      'exercise',
      abbr: 'e',
      help: 'Exercise the sweep is scored on.',
      defaultsTo: 'bw_squat',
    )
    ..addMultiOption(
      'fixtures',
      abbr: 'f',
      help: 'Fixture directories (JSON files, recursive).',
      defaultsTo: ['../../packages/forma_rules/test/fixtures'],
    )
    ..addOption(
      'content',
      abbr: 'c',
      help: 'Content bundle root (contains exercises/).',
      defaultsTo: '../../content',
    )
    ..addOption(
      'objective',
      abbr: 'O',
      help:
          'f1 | precision | recall | rep-mae | rule-f1:<ruleId>. '
          'Default: chosen from what is being swept.',
    )
    ..addOption('out', abbr: 'o', help: 'Write the markdown report here too.')
    ..addOption(
      'max-points',
      help: 'Refuse a grid larger than this.',
      defaultsTo: '512',
    )
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults args;
  try {
    args = parser.parse(argv);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exitCode = 64;
    return;
  }
  final specs = args['sweep'] as List<String>;
  final wantsHelp = args['help'] as bool;
  if (wantsHelp || specs.isEmpty) {
    stdout
      ..writeln(parser.usage)
      ..writeln()
      ..writeln(_examples);
    if (!wantsHelp) exitCode = 64;
    return;
  }

  final exercise = args['exercise'] as String;
  try {
    final axes = [
      for (final s in specs) SweepAxis.parse(s, defaultExercise: exercise),
    ];
    final corpus = EvalCorpus.load(
      fixtureDirs: (args['fixtures'] as List<String>)
          .map(Directory.new)
          .toList(),
      contentRoot: Directory(args['content'] as String),
    );
    if (corpus.fixtures.isEmpty) {
      stderr.writeln('no fixtures found; nothing to sweep');
      for (final w in corpus.warnings) {
        stderr.writeln('  $w');
      }
      exitCode = 66;
      return;
    }
    final objectiveSpec = args['objective'] as String?;
    final result = runSweep(
      corpus: corpus,
      axes: axes,
      exerciseId: exercise,
      objective: objectiveSpec == null
          ? null
          : SweepObjective.parse(objectiveSpec),
      maxPoints: int.parse(args['max-points'] as String),
    );
    final md = result.toMarkdown();
    stdout.write(md);
    final out = args['out'] as String?;
    if (out != null) {
      File(out)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(md);
      stdout.writeln('\nwrote $out');
    }
  } on SweepException catch (e) {
    stderr.writeln(e.message);
    exitCode = 64;
  }
}
