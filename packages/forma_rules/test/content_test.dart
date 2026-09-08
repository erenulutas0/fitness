import 'dart:io';

import 'package:forma_rules/forma_rules.dart';
import 'package:test/test.dart';

/// Validates the real content bundle (`content/`) against the engine.
void main() {
  final root = Directory('../../content');
  final exerciseFiles =
      Directory('${root.path}/exercises')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final cues = CueCatalog.parse(
    File('${root.path}/cues/cues.json').readAsStringSync(),
  );

  test('content directory is found', () {
    expect(exerciseFiles, isNotEmpty);
  });

  test('cues.json has TR and EN for every cue', () {
    expect(cues.validate(), isEmpty);
    expect(cues.has('count_1'), isTrue);
    expect(cues.has('count_20'), isTrue);
    expect(cues.text('knees_out', locale: 'tr'), 'Dizlerini dışa aç');
    expect(
      cues.text('knees_out', locale: 'en', variant: 1),
      'Push your knees out',
    );
  });

  test('every correction cue is at most 4 words (docs/06 cue rules)', () {
    for (final c in cues.cues.values.where((c) => c.category == 'correction')) {
      for (final locale in ['tr', 'en']) {
        for (final t in c.textsFor(locale)) {
          expect(
            t.split(' ').length,
            lessThanOrEqualTo(4),
            reason: '${c.id} [$locale] "$t"',
          );
        }
      }
    }
  });

  for (final file in exerciseFiles) {
    final name = file.uri.pathSegments.last;
    test('$name parses and validates', () {
      final def = ExerciseDefinition.parse(file.readAsStringSync());
      expect(def.validate(), isEmpty);
      expect(def.id, name.replaceAll('.json', ''));
      expect(def.name.tr, isNotEmpty);
      expect(def.name.en, isNotEmpty);
      for (final r in def.rules) {
        final cue = r.cue;
        if (cue != null) {
          expect(
            cues.has(cue),
            isTrue,
            reason: '${def.id}.${r.id} → cue "$cue" missing',
          );
        }
        expect(
          r.explain,
          isNotNull,
          reason: '${def.id}.${r.id} has no explain card',
        );
        expect(r.explain!.text.tr, isNotEmpty);
        expect(r.explain!.text.en, isNotEmpty);
      }
      for (final v in def.cameraViews) {
        // every view must be able to build a session
        expect(
          () => ExerciseSession(definition: def, view: v),
          returnsNormally,
        );
      }
      // round-trips through JSON
      final again = ExerciseDefinition.fromJson(def.toJson());
      expect(again.validate(), isEmpty);
      expect(again.rules.length, def.rules.length);
    });
  }

  test('definition validation catches common mistakes', () {
    final bad = ExerciseDefinition.fromJson({
      'id': 'bad',
      'name': 'Bad',
      'cameraViews': ['side'],
      'rep': {
        'signal': 'knee_angel',
        'restThreshold': 150,
        'peakThreshold': 150,
      },
      'rules': [
        {
          'id': 'r1',
          'expr': 'foo(1)',
          'severity': 9,
          'views': ['front'],
        },
        {'id': 'r1', 'expr': '1 < 2'},
      ],
      'score': {
        'weights': {'unknown_rule': 0.5},
      },
    });
    final errors = bad.validate();
    expect(errors.any((e) => e.contains('knee_angel')), isTrue);
    expect(errors.any((e) => e.contains('equal')), isTrue);
    expect(errors.any((e) => e.contains('foo')), isTrue);
    expect(errors.any((e) => e.contains('severity')), isTrue);
    expect(errors.any((e) => e.contains('duplicate')), isTrue);
    expect(errors.any((e) => e.contains('not in cameraViews')), isTrue);
    expect(errors.any((e) => e.contains('unknown_rule')), isTrue);
  });

  test('phase aliases from docs/05 are accepted', () {
    final r = RuleSpec.fromJson({
      'id': 'x',
      'expr': '1 < 2',
      'phase': ['descending', 'bottom', 'ascending', 'top'],
    });
    expect(r.phases, {
      RepPhase.toPeak,
      RepPhase.peak,
      RepPhase.toRest,
      RepPhase.rest,
    });
    final rep = RepSpec.fromJson({
      'signal': 'knee_angle',
      'topThreshold': 160,
      'bottomThreshold': 100,
    });
    expect(rep.restThreshold, 160);
    expect(rep.peakThreshold, 100);
  });
}
