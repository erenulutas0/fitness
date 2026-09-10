import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/app/app.dart';
import 'package:forma_mobile/app/router.dart';
import 'package:forma_mobile/app/shell.dart';
import 'package:forma_mobile/core/content/content_repository.dart';
import 'package:forma_mobile/core/locale/locale_controller.dart';
import 'package:forma_mobile/core/profile/profile_controller.dart';
import 'package:forma_mobile/core/profile/profile_store.dart';
import 'package:forma_mobile/core/profile/user_profile.dart';
import 'package:forma_mobile/core/settings/settings_store.dart';
import 'package:forma_mobile/features/history/infrastructure/session_store.dart';
import 'package:forma_mobile/features/workout/infrastructure/pose_engine_provider.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';

class _TurkishLocale extends LocaleController {
  @override
  Locale build() => const Locale('tr');
}

final _profile = UserProfile(
  goal: TrainingGoal.form,
  level: TrainingLevel.occasional,
  equipment: Equipment.none,
  createdAt: DateTime(2026, 9, 10),
);

/// Leave a pushed screen through its app-bar back button. Not `pageBack`:
/// that looks for the English "Back" tooltip and the app is pinned to Turkish.
Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

/// A profile that is already there. Provided in memory rather than read from
/// disk: real file I/O never completes under the widget test's fake clock.
class _SeededProfile extends ProfileController {
  @override
  Future<UserProfile?> build() async => _profile;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempRoot;
  late ContentBundle content;

  setUp(() async {
    tempRoot = Directory.systemTemp.createTempSync('forma_shell');
    // The store would otherwise create this with real async I/O, which never
    // completes under the widget test's fake clock.
    Directory('${tempRoot.path}/sessions').createSync();
    content = await loadContentBundle(rootBundle);
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  Widget app({required bool withProfile}) => ProviderScope(
    overrides: [
      poseEngineProvider.overrideWithValue(
        FakeFormaPose.syntheticSquat(view: CameraView.side, noiseStd: 0),
      ),
      contentRepositoryProvider.overrideWith((ref) async => content),
      localeControllerProvider.overrideWith(_TurkishLocale.new),
      settingsStoreProvider.overrideWithValue(
        SettingsStore(rootOverride: tempRoot),
      ),
      sessionStoreProvider.overrideWithValue(
        SessionStore(rootOverride: tempRoot),
      ),
      profileStoreProvider.overrideWithValue(
        ProfileStore(rootOverride: tempRoot),
      ),
      if (withProfile) profileProvider.overrideWith(_SeededProfile.new),
    ],
    child: const FormaApp(),
  );

  testWidgets('the shell has four tabs and tapping one switches screens', (
    tester,
  ) async {
    await tester.pumpWidget(app(withProfile: true));
    await tester.pumpAndSettle();

    expect(find.byType(FormaShell), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    // Today is the first tab: the hero button and the empty last-session
    // line, and no exercise list any more.
    expect(find.byKey(const Key('today_quick_check')), findsOneWidget);
    expect(find.byKey(const Key('today_empty')), findsOneWidget);
    expect(find.byKey(const Key('exercise_bw_squat')), findsNothing);

    await tester.tap(find.byKey(const Key('tab_training')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exercise_bw_squat')), findsOneWidget);
    // The list is lazy and the draft sits at the bottom, below the fold.
    await tester.dragUntilVisible(
      find.byKey(const Key('exercise_reverse_lunge')),
      find.byType(ListView),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(find.text('Taslak'), findsOneWidget, reason: 'the draft badge');
    await tester.dragUntilVisible(
      find.byKey(const Key('exercise_bw_squat')),
      find.byType(ListView),
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();

    // Exercise detail is a full-screen route above the shell.
    await tester.tap(find.byKey(const Key('exercise_bw_squat')));
    await tester.pumpAndSettle();
    expect(find.byType(FormaShell), findsNothing);
    expect(find.byKey(const Key('detail_description')), findsOneWidget);
    expect(find.byKey(const Key('rule_front_knee_valgus')), findsOneWidget);
    expect(find.text('Dizlerini dışa aç'), findsOneWidget);
    expect(find.byKey(const Key('rule_side_heel_rise')), findsNothing);
    expect(find.byKey(const Key('detail_start')), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail_start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('view_front')), findsOneWidget);
    expect(find.byKey(const Key('view_side')), findsOneWidget);
    // Dismiss the sheet, leave the detail.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('view_front')), findsNothing);
    await _back(tester);
    await tester.pumpAndSettle();
    expect(find.byType(FormaShell), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab_progress')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('progress_empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab_profile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_goal')), findsOneWidget);
    expect(find.text('Form'), findsOneWidget);
    expect(find.text('Ara sıra'), findsOneWidget);
    expect(find.byKey(const Key('profile_version')), findsOneWidget);

    // Settings is pushed above the shell.
    await tester.tap(find.byKey(const Key('profile_settings')));
    await tester.pumpAndSettle();
    expect(find.byType(FormaShell), findsNothing);
    expect(find.byKey(const Key('settings_quiet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings_legal')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legal_privacy')), findsOneWidget);
    expect(find.text('MediaPipe'), findsOneWidget);
    await _back(tester);
    await tester.pumpAndSettle();
    await _back(tester);
    await tester.pumpAndSettle();
    expect(find.byType(FormaShell), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab_today')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today_quick_check')), findsOneWidget);
  });

  testWidgets('without a profile the router goes to onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(app(withProfile: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today_quick_check')), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FormaApp)),
    );
    final router = container.read(routerProvider);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      Routes.onboarding,
    );
  });

  test('the redirect rule', () {
    expect(
      profileRedirect(hasProfile: false, location: '/'),
      Routes.onboarding,
    );
    expect(
      profileRedirect(hasProfile: false, location: '/settings'),
      Routes.onboarding,
    );
    expect(profileRedirect(hasProfile: false, location: '/onboarding'), isNull);
    expect(
      profileRedirect(hasProfile: false, location: '/onboarding/goal'),
      isNull,
    );
    expect(profileRedirect(hasProfile: true, location: '/'), isNull);
    expect(profileRedirect(hasProfile: true, location: '/onboarding'), isNull);
  });

  test('Routes.hud carries the rep target as a query', () {
    expect(Routes.hud('bw_squat', CameraView.side), '/workout/bw_squat/side');
    expect(
      Routes.hud('bw_squat', CameraView.front, targetReps: 5),
      '/workout/bw_squat/front?reps=5',
    );
  });
}
