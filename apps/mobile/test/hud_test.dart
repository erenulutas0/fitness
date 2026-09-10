import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/app/app.dart';
import 'package:forma_mobile/core/content/content_repository.dart';
import 'package:forma_mobile/core/locale/locale_controller.dart';
import 'package:forma_mobile/core/profile/profile_controller.dart';
import 'package:forma_mobile/core/profile/profile_store.dart';
import 'package:forma_mobile/core/settings/settings_store.dart';
import 'package:forma_mobile/features/history/infrastructure/session_store.dart';
import 'package:forma_mobile/features/workout/infrastructure/pose_engine_provider.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';

/// Pin the app to Turkish so the assertions below are deterministic.
class _TurkishLocale extends LocaleController {
  @override
  Locale build() => const Locale('tr');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempRoot;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('forma_hud');
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  testWidgets('quick form check counts synthetic reps and shows a cue', (
    tester,
  ) async {
    final fake = FakeFormaPose.syntheticSquat(
      view: CameraView.front,
      valgus: 0.3,
      reps: 3,
      noiseStd: 0,
    );
    final content = await loadContentBundle(rootBundle);
    expect(content.exercises.keys, contains('bw_squat'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poseEngineProvider.overrideWithValue(fake),
          contentRepositoryProvider.overrideWith((ref) async => content),
          localeControllerProvider.overrideWith(_TurkishLocale.new),
          // The stores point at a scratch directory, and the profile is
          // "already there" so the router lands on Today, not onboarding.
          settingsStoreProvider.overrideWithValue(
            SettingsStore(rootOverride: tempRoot),
          ),
          profileStoreProvider.overrideWithValue(
            ProfileStore(rootOverride: tempRoot),
          ),
          sessionStoreProvider.overrideWithValue(
            SessionStore(rootOverride: tempRoot),
          ),
          hasProfileProvider.overrideWith((ref) async => true),
        ],
        child: const FormaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today_quick_check')), findsOneWidget);

    await tester.tap(find.byKey(const Key('today_quick_check')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('view_front')));
    await tester.pumpAndSettle();

    // The set now opens on the framing step: the camera is already streaming,
    // the coach waits until the shot is good and counts down.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(find.byKey(const Key('hud_framing_message')), findsOneWidget);

    // Skip the wait the way an impatient user would.
    await tester.tap(find.byKey(const Key('hud_start_now')));
    await tester.pump();

    // Let the fake engine stream ~9 s of frames (3 reps + pauses).
    for (var i = 0; i < 270; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(find.text('3'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('dışa'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('hud_finish')));
    await tester.pumpAndSettle();
    expect(find.text('Set özeti'), findsOneWidget);
    // The summary names the error the way the coach said it, not by the
    // engine's `knee_valgus` identifier.
    expect(find.textContaining('Dizlerini dışa aç'), findsOneWidget);

    // Set 1 of 3 is done, so the summary leads into the rest timer rather
    // than dumping the user back on Today (docs/06 §4.4).
    String restSeconds() =>
        tester.widget<Text>(find.byKey(const Key('rest_seconds'))).data!;
    expect(restSeconds(), '60');
    await tester.pump(const Duration(seconds: 1));
    expect(restSeconds(), '59', reason: 'the rest timer counts down');

    // Ending the session early goes to the session summary, which reports the
    // one set that was actually performed.
    // Not pumpAndSettle: the rest timer is periodic, so settling would run
    // the countdown to zero and start set 2 instead.
    await tester.ensureVisible(find.byKey(const Key('rest_end')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rest_end')));
    await tester.pumpAndSettle();
    expect(find.text('Seans özeti'), findsOneWidget);
    expect(find.byKey(const Key('session_mean_score')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.textContaining('tekrar'),
      ),
      findsWidgets,
      reason: 'the set row shows what was counted',
    );

    await tester.dragUntilVisible(
      find.byKey(const Key('session_done')),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session_done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today_quick_check')), findsOneWidget);
    await fake.dispose();
  });
}
