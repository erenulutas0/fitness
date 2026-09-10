import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/app/router.dart';
import 'package:forma_mobile/app/theme.dart';
import 'package:forma_mobile/core/profile/profile_controller.dart';
import 'package:forma_mobile/core/profile/profile_store.dart';
import 'package:forma_mobile/core/profile/user_profile.dart';
import 'package:forma_mobile/features/onboarding/application/onboarding_controller.dart';
import 'package:forma_mobile/features/onboarding/onboarding_routes.dart';
import 'package:forma_mobile/features/onboarding/presentation/camera_permission_screen.dart';
import 'package:forma_mobile/features/workout/application/session_controller.dart';
import 'package:forma_mobile/features/workout/infrastructure/pose_engine_provider.dart';
import 'package:forma_mobile/l10n/app_localizations.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// An engine whose permission prompt the user turns down.
class _DeniedPose extends FakeFormaPose {
  _DeniedPose() : super(source: const <PoseFrame>[]);

  @override
  Future<bool> requestCameraPermission() async => false;
}

/// The real store on a temp dir, but with synchronous file calls: the async
/// ones complete on an I/O thread the widget test's fake clock never yields
/// to. The async round trip itself is covered by profile_store_test.dart.
class _SyncProfileStore extends ProfileStore {
  const _SyncProfileStore(Directory root) : super(rootOverride: root);

  @override
  Future<UserProfile?> load() async {
    final f = await file();
    if (!f.existsSync()) return null;
    return UserProfile.fromJson(
      json.decode(f.readAsStringSync()) as Map<String, dynamic>,
    );
  }

  @override
  Future<File> save(UserProfile profile) async {
    final f = await file();
    f.writeAsStringSync(json.encode(profile.toJson()));
    return f;
  }

  @override
  Future<void> delete() async {
    final f = await file();
    if (f.existsSync()) f.deleteSync();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late ProviderContainer container;
  late GoRouter router;

  setUp(() {
    root = Directory.systemTemp.createTempSync('forma_onboarding');
  });

  tearDown(() {
    container.dispose();
    router.dispose();
    root.deleteSync(recursive: true);
  });

  /// The onboarding routes plus stubs for where they lead, so the test can
  /// assert the destination without the real Today or HUD screens.
  Future<void> pumpOnboarding(
    WidgetTester tester, {
    FormaPosePlatform? engine,
  }) async {
    container = ProviderContainer(
      overrides: [
        profileStoreProvider.overrideWithValue(_SyncProfileStore(root)),
        poseEngineProvider.overrideWithValue(
          engine ?? FakeFormaPose.syntheticSquat(),
        ),
      ],
    );
    router = GoRouter(
      initialLocation: OnboardingRoutes.welcome,
      routes: [
        ...onboardingRoutes,
        GoRoute(
          path: Routes.today,
          builder: (_, _) => const Scaffold(key: Key('stub_today')),
        ),
        GoRoute(
          path: '/workout/:exerciseId/:view',
          builder: (_, _) => const Scaffold(key: Key('stub_hud')),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: FormaTheme.dark(),
          locale: const Locale('tr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> profileOnDisk() =>
      json.decode(
            File('${root.path}/${ProfileStore.fileName}').readAsStringSync(),
          )
          as Map<String, dynamic>;

  testWidgets('three taps answer the questions and reach the camera step', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    expect(find.byKey(const Key('onboarding_try_camera')), findsOneWidget);

    await tap(tester, 'onboarding_try_camera');
    expect(router.state.uri.path, OnboardingRoutes.goal);
    expect(find.text('Neden buradasın?'), findsOneWidget);

    await tap(tester, 'onboarding_option_muscle');
    expect(router.state.uri.path, OnboardingRoutes.level);
    await tap(tester, 'onboarding_option_regular');
    expect(router.state.uri.path, OnboardingRoutes.equipment);
    await tap(tester, 'onboarding_option_dumbbell');
    expect(router.state.uri.path, OnboardingRoutes.camera);

    expect(
      container.read(onboardingControllerProvider),
      const OnboardingAnswers(
        goal: TrainingGoal.muscle,
        level: TrainingLevel.regular,
        equipment: Equipment.dumbbell,
      ),
    );
    expect(
      container.read(profileProvider).value,
      isNull,
      reason: 'the profile is written on the camera step, not before',
    );
    expect(find.text('Görüntü cihazda'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_open_camera')), findsOneWidget);
  });

  testWidgets('going back keeps the answer selected', (tester) async {
    await pumpOnboarding(tester);
    await tap(tester, 'onboarding_try_camera');
    await tap(tester, 'onboarding_option_health');
    expect(router.state.uri.path, OnboardingRoutes.level);

    await tap(tester, 'onboarding_back');
    expect(router.state.uri.path, OnboardingRoutes.goal);

    final handle = tester.ensureSemantics();
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(const Key('onboarding_option_health'))),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('onboarding_option_muscle'))),
      isSemantics(isSelected: false),
    );
    handle.dispose();

    // Selection is never colour alone: the check icon shows on the chosen
    // card only. (The icon widget exists on every card to keep the layout
    // stable; visibility is what changes.)
    bool checkVisible(String key) => tester
        .widget<Visibility>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Visibility),
          ),
        )
        .visible;
    expect(checkVisible('onboarding_option_health'), isTrue);
    expect(checkVisible('onboarding_option_muscle'), isFalse);
    expect(
      find.descendant(
        of: find.byKey(const Key('onboarding_option_health')),
        matching: find.byIcon(LucideIcons.check),
      ),
      findsOneWidget,
    );
  });

  testWidgets('granting the camera writes the profile and starts the demo', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    await tap(tester, 'onboarding_try_camera');
    await tap(tester, 'onboarding_option_form');
    await tap(tester, 'onboarding_option_occasional');
    await tap(tester, 'onboarding_option_none');
    await tap(tester, 'onboarding_open_camera');

    final profile = container.read(profileProvider).value;
    expect(profile, isNotNull);
    expect(profile!.goal, TrainingGoal.form);
    expect(profile.level, TrainingLevel.occasional);
    expect(profile.equipment, Equipment.none);
    expect(await container.read(hasProfileProvider.future), isTrue);

    final raw = profileOnDisk();
    expect(raw['goal'], 'form');
    expect(raw['level'], 'occasional');
    expect(raw['equipment'], 'none');

    expect(router.state.uri.toString(), '/workout/bw_squat/side?reps=5');
    expect(router.state.uri.toString(), demoSessionLocation());
    expect(find.byKey(const Key('stub_hud')), findsOneWidget);

    final session = container.read(workoutSessionControllerProvider);
    expect(session.exerciseId, demoExerciseId);
    expect(session.view, CameraView.side);
    expect(session.setTotal, 1);
    expect(
      container.read(onboardingControllerProvider),
      const OnboardingAnswers(),
      reason: 'the draft is cleared once the profile is written',
    );
  });

  testWidgets('a denied camera offers retry and a way through without it', (
    tester,
  ) async {
    await pumpOnboarding(tester, engine: _DeniedPose());
    await tap(tester, 'onboarding_try_camera');
    await tap(tester, 'onboarding_option_muscle');
    await tap(tester, 'onboarding_option_new');
    await tap(tester, 'onboarding_option_dumbbell');
    await tap(tester, 'onboarding_open_camera');

    expect(router.state.uri.path, OnboardingRoutes.camera);
    expect(find.byKey(const Key('onboarding_camera_denied')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_retry')), findsOneWidget);
    expect(container.read(profileProvider).value, isNull);
    expect(
      find.byType(FilledButton),
      findsOneWidget,
      reason: 'still exactly one lime button',
    );

    await tap(tester, 'onboarding_without_camera');
    expect(router.state.uri.path, Routes.today);
    expect(find.byKey(const Key('stub_today')), findsOneWidget);
    final raw = profileOnDisk();
    expect(raw['goal'], 'muscle');
    expect(raw['level'], 'new');
    expect(raw['equipment'], 'dumbbell');
    expect(
      container.read(workoutSessionControllerProvider).isActive,
      isFalse,
      reason: 'no demo session without a camera',
    );
  });

  testWidgets('skip writes a default profile and goes to Today', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    await tap(tester, 'onboarding_skip');

    expect(router.state.uri.path, Routes.today);
    final raw = profileOnDisk();
    expect(raw['goal'], 'form');
    expect(raw['level'], 'new');
    expect(raw['equipment'], 'none');
    expect(await container.read(hasProfileProvider.future), isTrue);
  });
}
