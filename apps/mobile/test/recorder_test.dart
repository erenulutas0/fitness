import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/app/app.dart';
import 'package:forma_mobile/core/content/content_repository.dart';
import 'package:forma_mobile/core/locale/locale_controller.dart';
import 'package:forma_mobile/features/recorder/application/recorder_controller.dart';
import 'package:forma_mobile/features/recorder/infrastructure/fixture_store.dart';
import 'package:forma_mobile/features/workout/infrastructure/pose_engine_provider.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';

class _TurkishLocale extends LocaleController {
  @override
  Locale build() => const Locale('tr');
}

/// Scroll the screen's single ListView until [key] is on screen.
Future<void> _scrollTo(WidgetTester tester, Key key) => tester.dragUntilVisible(
  find.byKey(key),
  find.byType(ListView),
  const Offset(0, -120),
);

/// The recorder screens always have something animating (a spinner while the
/// fixture list loads, the live camera stream), so `pumpAndSettle` never
/// returns; drive a fixed number of frames instead.
Future<void> _advance(
  WidgetTester tester, {
  int frames = 20,
  int ms = 50,
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempRoot;
  late FixtureStore store;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('forma_fixtures');
    store = FixtureStore(rootOverride: tempRoot);
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  test(
    'a recording is saved as a fixture the eval pipeline can read',
    () async {
      final frames = const SyntheticPose().squat(
        view: CameraView.front,
        reps: 3,
        valgus: 0.3,
      );
      final def = ExerciseDefinition.parse(
        await File('../../content/exercises/bw_squat.json').readAsString(),
      );
      // Replay the recording through the engine the way the recorder does.
      final session = ExerciseSession(
        definition: def,
        view: CameraView.front,
        config: const SessionConfig(smoothing: SmoothingConfig.none),
      );
      frames.forEach(session.process);
      final draft = RecordingDraft(
        config: const RecordingConfig(
          exerciseId: 'bw_squat',
          view: CameraView.front,
          person: 'p07',
          environment: 'gym',
        ),
        frames: frames,
        engineResult: session.finish(),
        device: 'Test Device',
      );
      expect(draft.engineReps, 3);
      expect(draft.engineRulesFor(1), contains('knee_valgus'));
      expect(draft.meanVisibility, greaterThan(0.9));
      expect(draft.lostRatio, 0);

      final fixture = draft.toFixture(
        labels: const [
          FixtureLabel(rep: 1, rules: ['knee_valgus']),
          FixtureLabel(rep: 2, rules: ['knee_valgus']),
          FixtureLabel(rep: 3, rules: ['knee_valgus']),
        ],
        expectedReps: 3,
        notes: 'test',
      );
      expect(fixture.frames.first.timestampMs, 0, reason: 'rebased to zero');
      expect(fixture.person, 'p07');
      expect(fixture.modelVariant, 'lite');
      expect(fixture.device, 'Test Device');

      final file = await store.save(fixture);
      expect(file.existsSync(), isTrue);
      expect(file.uri.pathSegments.last, startsWith('bw_squat_front_p07_gym_'));

      // Read it back exactly as tools/eval would.
      final reloaded = LandmarkFixture.parse(await file.readAsString());
      expect(reloaded.frames.length, frames.length);
      expect(reloaded.expectedReps, 3);
      expect(reloaded.labeledRuleCounts, {'knee_valgus': 3});
      final replay = ExerciseSession(
        definition: def,
        view: reloaded.view,
        config: const SessionConfig(smoothing: SmoothingConfig.none),
      );
      reloaded.frames.forEach(replay.process);
      final result = replay.finish();
      expect(result.repCount, 3);
      expect(result.errorCounts['knee_valgus'], 3);

      final listed = await store.list();
      expect(listed, hasLength(1));
      expect(listed.single.sizeBytes, greaterThan(1000));
      await store.delete(listed.single);
      expect(await store.list(), isEmpty);
    },
  );

  testWidgets('recorder captures frames and hands a draft to labelling', (
    tester,
  ) async {
    // Side view is the recorder's default; feed it shallow squats so the
    // engine has both reps to count and a rule to hint at.
    final fake = FakeFormaPose.syntheticSquat(
      view: CameraView.side,
      peakAngle: 118,
      reps: 4,
      noiseStd: 0,
    );
    final content = await loadContentBundle(rootBundle);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poseEngineProvider.overrideWithValue(fake),
          contentRepositoryProvider.overrideWith((ref) async => content),
          localeControllerProvider.overrideWith(_TurkishLocale.new),
          fixtureStoreProvider.overrideWithValue(store),
        ],
        child: const FormaApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('today_recorder')));
    await _advance(tester);
    expect(find.text('Kayıt (fixture)'), findsOneWidget);
    // The setup form is a long ListView; the button sits below the fold.
    await _scrollTo(tester, const Key('recorder_start'));
    await tester.tap(find.byKey(const Key('recorder_start')));
    // The capture screen streams frames forever, so pumpAndSettle would hang:
    // drive it a fixed number of frames instead (5 s countdown + ~8 s take).
    await _advance(tester, frames: 400, ms: 33);
    expect(find.textContaining('frame'), findsOneWidget);

    await tester.tap(find.byKey(const Key('recorder_stop')));
    await _advance(tester, frames: 10);
    expect(find.text('Etiketle'), findsOneWidget);
    expect(find.byType(FilterChip), findsWidgets, reason: 'reps were detected');

    // The engine hints at the shallow depth it saw, but the chip starts
    // unselected: the label has to be the founder's own call.
    final chip = find.byKey(const Key('label_1_shallow_depth'));
    await _scrollTo(tester, const Key('label_1_shallow_depth'));
    expect(chip, findsOneWidget);
    expect(tester.widget<FilterChip>(chip).selected, isFalse);
    await tester.tap(chip);
    await _advance(tester, frames: 5);
    expect(tester.widget<FilterChip>(chip).selected, isTrue);

    // Writing the file is covered by the test above; a widget test runs under
    // fake async, where real file I/O never completes.
    await _scrollTo(tester, const Key('recorder_save'));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('recorder_save')))
          .enabled,
      isTrue,
    );
    await fake.dispose();
  });
}
