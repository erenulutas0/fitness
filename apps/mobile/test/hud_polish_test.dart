import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/app/app.dart';
import 'package:forma_mobile/app/router.dart';
import 'package:forma_mobile/core/content/content_repository.dart';
import 'package:forma_mobile/core/locale/locale_controller.dart';
import 'package:forma_mobile/core/profile/profile_store.dart';
import 'package:forma_mobile/core/profile/user_profile.dart';
import 'package:forma_mobile/core/settings/app_settings.dart';
import 'package:forma_mobile/core/settings/settings_controller.dart';
import 'package:forma_mobile/core/settings/settings_store.dart';
import 'package:forma_mobile/features/workout/application/session_controller.dart';
import 'package:forma_mobile/features/workout/infrastructure/pose_engine_provider.dart';
import 'package:forma_mobile/features/workout/presentation/skeleton_painter.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';

/// Pin the app to Turkish so the assertions below are deterministic.
class _TurkishLocale extends LocaleController {
  @override
  Locale build() => const Locale('tr');
}

/// The stores in memory. `testWidgets` runs under FakeAsync, where a real
/// file read never completes, so the disk-backed stores would leave the
/// providers loading forever (and the defaults in force) whatever the file
/// says.
class _MemorySettings extends SettingsStore {
  _MemorySettings(this.settings);

  AppSettings settings;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<File> save(AppSettings settings) async {
    this.settings = settings;
    return File(SettingsStore.fileName);
  }

  @override
  Future<void> delete() async => settings = AppSettings.defaults;
}

class _MemoryProfile extends ProfileStore {
  _MemoryProfile(this.profile);

  UserProfile? profile;

  @override
  Future<UserProfile?> load() async => profile;

  @override
  Future<File> save(UserProfile profile) async {
    this.profile = profile;
    return File(ProfileStore.fileName);
  }

  @override
  Future<void> delete() async => profile = null;
}

/// An engine that refuses the camera, the way Android does after the user
/// taps "Don't allow". [allow] flips when the user comes back from the OS
/// settings page having granted it.
class _DenyingPose extends FakeFormaPose {
  _DenyingPose(FakeFormaPose real) : super(source: real.source);

  bool allow = false;
  int settingsOpened = 0;

  @override
  Future<PoseEngineInfo> start([
    PoseStartOptions options = const PoseStartOptions(),
  ]) {
    if (allow) return super.start(options);
    throw const PoseEngineException(
      PoseErrorCode.permissionDenied,
      'camera permission not granted',
    );
  }

  @override
  Future<bool> hasCameraPermission() async => allow;

  @override
  Future<bool> requestCameraPermission() async => allow;

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    // The user allows the camera on the settings page and comes back.
    allow = true;
    return true;
  }
}

const _hud = '/workout/bw_squat/front';

final Finder _skeleton = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is SkeletonPainter,
);

/// The fake engine streams at 30 fps; the HUD is driven frame by frame
/// because the rest timer and the countdown are periodic and would keep
/// `pumpAndSettle` busy for a minute.
Future<void> _stream(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 33));
  }
}

Future<void> _openHud(
  WidgetTester tester,
  ProviderContainer c,
  String path,
) async {
  c.read(routerProvider).go(path);
  await _stream(tester, 40);
  expect(find.byKey(const Key('hud_framing_message')), findsOneWidget);
}

Future<void> _startSet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('hud_start_now')));
  await tester.pump();
}

/// Leaves the screen and the container behind without settling: a live rest
/// timer or engine would otherwise be reported as a pending timer.
Future<void> _tearDownApp(WidgetTester tester, FakeFormaPose fake) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await fake.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentBundle content;

  setUpAll(() async {
    content = await loadContentBundle(rootBundle);
    expect(content.exercises.keys, contains('bw_squat'));
  });

  FakeFormaPose squat({int reps = 4}) => FakeFormaPose.syntheticSquat(
    view: CameraView.front,
    valgus: 0.3,
    reps: reps,
    noiseStd: 0,
  );

  Future<ProviderContainer> pumpApp(
    WidgetTester tester,
    FakeFormaPose fake, {
    AppSettings settings = AppSettings.defaults,
  }) async {
    final container = ProviderContainer(
      overrides: [
        poseEngineProvider.overrideWithValue(fake),
        contentRepositoryProvider.overrideWith((ref) async => content),
        localeControllerProvider.overrideWith(_TurkishLocale.new),
        settingsStoreProvider.overrideWithValue(_MemorySettings(settings)),
        // A profile, so a router that sends new users through onboarding
        // leaves these tests on the HUD.
        profileStoreProvider.overrideWithValue(
          _MemoryProfile(
            UserProfile(
              goal: TrainingGoal.form,
              level: TrainingLevel.newcomer,
              equipment: Equipment.none,
              createdAt: DateTime(2026, 9, 10),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const FormaApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('?reps=2 finishes the set by itself and lands on the summary', (
    tester,
  ) async {
    final fake = squat();
    final c = await pumpApp(tester, fake);
    await _openHud(tester, c, '$_hud?reps=2');
    await _startSet(tester);
    expect(
      find.text('/ 2'),
      findsOneWidget,
      reason: 'the target is shown next to the counter',
    );

    var landed = false;
    for (var i = 0; i < 400 && !landed; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      landed = find.text('Set özeti').evaluate().isNotEmpty;
    }
    expect(landed, isTrue, reason: 'the HUD leaves for the set summary');
    expect(fake.isRunning, isFalse, reason: 'the camera is closed');

    final session = c.read(workoutSessionControllerProvider);
    expect(session.sets, hasLength(1));
    expect(session.sets.single.result.repCount, 2);
    await _tearDownApp(tester, fake);
  });

  testWidgets('back from a HUD nothing pushed goes to Today, not out', (
    tester,
  ) async {
    // Onboarding opens the demo with `go`, leaving nothing to pop; before the
    // PopScope, back closed the app on a first-run user's first screen after
    // granting the camera.
    final fake = squat();
    final c = await pumpApp(tester, fake);
    await _openHud(tester, c, _hud);
    await _startSet(tester);
    await _stream(tester, 5);
    expect(find.byKey(const Key('hud_counter')), findsOneWidget);

    await tester.binding.handlePopRoute();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      find.byKey(const Key('today_quick_check')),
      findsOneWidget,
      reason: 'back lands on Today instead of leaving the app',
    );
    await _tearDownApp(tester, fake);
  });

  testWidgets('overlay off draws no skeleton, overlay on draws one', (
    tester,
  ) async {
    final fake = squat();
    final c = await pumpApp(
      tester,
      fake,
      settings: const AppSettings(overlayOn: false),
    );
    await _openHud(tester, c, _hud);
    // Start the set: it is the state the overlay setting is really about, and
    // it cancels the framing countdown so no timer outlives the tree.
    await _startSet(tester);
    await _stream(tester, 5);
    expect(_skeleton, findsNothing);

    // The control: the same frames with the overlay back on.
    await c
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(overlayOn: true));
    await _stream(tester, 5);
    expect(_skeleton, findsOneWidget);
    await _tearDownApp(tester, fake);
  });

  testWidgets('landscape puts the counter and the buttons on the right', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fake = squat();
    final c = await pumpApp(tester, fake);
    await _openHud(tester, c, _hud);
    await _startSet(tester);
    await _stream(tester, 30);

    final counter = find.byKey(const Key('hud_counter'));
    final finish = find.byKey(const Key('hud_finish'));
    expect(counter, findsOneWidget);
    expect(finish, findsOneWidget);
    expect(tester.getRect(counter).left, greaterThan(800));
    expect(tester.getRect(finish).left, greaterThan(800));
    expect(
      tester.getRect(finish).bottom,
      greaterThan(tester.getRect(counter).bottom),
      reason: 'buttons sit below the readout, bottom-right',
    );
    await _tearDownApp(tester, fake);
  });

  testWidgets('going to the background closes the camera and keeps the set', (
    tester,
  ) async {
    final fake = squat();
    final c = await pumpApp(tester, fake);
    await _openHud(tester, c, _hud);
    await _startSet(tester);
    // Roughly one and a half reps of the synthetic squat.
    await _stream(tester, 150);
    expect(find.text('Set özeti'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();
    expect(fake.isRunning, isFalse, reason: 'no camera in the background');
    final session = c.read(workoutSessionControllerProvider);
    expect(session.sets, hasLength(1), reason: 'what was counted is kept');
    expect(session.sets.single.result.repCount, greaterThan(0));
    expect(
      find.text('Set özeti'),
      findsNothing,
      reason: 'nothing to navigate to until the user is back',
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Set özeti'), findsOneWidget);
    await _tearDownApp(tester, fake);
  });

  testWidgets('a refused camera is explained in Turkish, not in engine words', (
    tester,
  ) async {
    // The device showed "Kamera başlatılamadı: camera permission not granted":
    // half the sentence was the plugin's English log line.
    final fake = _DenyingPose(squat());
    final c = await pumpApp(tester, fake);
    c.read(routerProvider).go(_hud);
    await _stream(tester, 40);

    final error = find.byKey(const Key('hud_error'));
    expect(error, findsOneWidget);
    expect(
      tester.widget<Text>(error).data,
      'Kamera izni verilmedi. Formunu görebilmem için kameraya izin vermen '
      'gerekiyor.',
    );
    expect(
      find.textContaining('permission'),
      findsNothing,
      reason: 'the engine message never reaches the screen',
    );

    // Settings, not a retry: Android stops showing the dialog after two
    // denials, so a retry button alone would be a dead end.
    expect(find.byKey(const Key('hud_error_retry')), findsNothing);
    await tester.tap(find.byKey(const Key('hud_error_settings')));
    await _stream(tester, 5);
    expect(fake.settingsOpened, 1);

    // Coming back with the permission granted starts the camera by itself.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _stream(tester, 40);
    expect(error, findsNothing);
    expect(find.byKey(const Key('hud_framing_message')), findsOneWidget);
    await _startSet(tester);
    await _tearDownApp(tester, fake);
  });
}
