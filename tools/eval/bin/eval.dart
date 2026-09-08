// FORMA evaluation harness (docs/10 Prompt 9).
//
//   dart run bin/eval.dart --fixtures ../../packages/forma_rules/test/fixtures \
//       --content ../../content/lib --out ../../docs/eval/latest.md
//
// Runs every labelled landmark fixture through the forma_rules pipeline and
// reports, per exercise and per rule: precision / recall / F1, rep-count MAE
// and cues per rep. Thresholds are never written back — the report is the
// input to a human decision (CLAUDE.md: "eşikleri elle ayarlama").
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:forma_eval/forma_eval.dart';

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
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
      'out',
      abbr: 'o',
      help: 'Markdown report path.',
      defaultsTo: '../../docs/eval/latest.md',
    )
    ..addOption(
      'json',
      help: 'JSON report path.',
      defaultsTo: '../../docs/eval/latest.json',
    )
    ..addFlag(
      'smoothing',
      help: 'Apply the production One Euro smoother.',
      defaultsTo: true,
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final args = parser.parse(argv);
  if (args['help'] as bool) {
    stdout.writeln(parser.usage);
    return;
  }

  final report = await runEvaluation(
    fixtureDirs: (args['fixtures'] as List<String>).map(Directory.new).toList(),
    contentRoot: Directory(args['content'] as String),
    smoothing: args['smoothing'] as bool,
  );

  final md = report.toMarkdown();
  final outPath = args['out'] as String;
  File(outPath)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(md);
  File(args['json'] as String).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report.toJson()),
  );
  stdout
    ..writeln(md)
    ..writeln('\nwrote $outPath');
  if (!report.meetsGate2) {
    stderr.writeln(
      'Gate 2 not met (precision ≥ 0.80 and recall ≥ 0.70 per exercise).',
    );
    exitCode = 1;
  }
}
