// Renders the app's screens to PNG with the real fonts, for a visual review
// without a phone. Skipped unless an output directory is given:
//
//   flutter test test/screenshots_test.dart --dart-define=SCREENSHOT_DIR=<dir>
//
// The ordinary test font draws every glyph as a box, which is why the first
// render of the new UI could not answer the typography question (brief §5).
// Here Manrope, Inter and the Lucide icon font are loaded for real.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:forma_mobile/core/settings/settings_store.dart';
import 'package:forma_mobile/features/history/domain/stored_session.dart';
import 'package:forma_mobile/features/history/infrastructure/session_store.dart';
import 'package:forma_mobile/features/workout/infrastructure/pose_engine_provider.dart';
import 'package:forma_mobile/features/workout/presentation/set_summary_screen.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';

const _outDir = String.fromEnvironment('SCREENSHOT_DIR');

/// Galaxy S23: 1080x2340 at 480 dpi, so 360 dp wide — the narrowest common
/// Android width, where overflows show first.
const _portrait = Size(1080, 2340);
const _landscape = Size(2340, 1080);
const _dpr = 3.0;

final GlobalKey _boundary = GlobalKey();

class _FixedLocale extends LocaleController {
  _FixedLocale(this.locale);

  final Locale locale;

  @override
  Locale build() => locale;
}

/// The stores in memory: real async file I/O never completes under the
/// widget test's fake clock.
class _MemorySettings extends SettingsStore {
  AppSettings settings = AppSettings.defaults;

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

class _MemorySessions extends SessionStore {
  _MemorySessions(this.sessions);

  /// Newest first, like the real store.
  final List<StoredSession> sessions;

  @override
  Future<File> save(StoredSession session) async {
    sessions.insert(0, session);
    return File('sessions/${session.id}.json');
  }

  @override
  Future<List<StoredSession>> list({int? limit}) async =>
      limit == null ? List.of(sessions) : sessions.take(limit).toList();

  @override
  Future<StoredSession?> latest({String? exceptId}) async {
    for (final s in sessions) {
      if (s.id != exceptId) return s;
    }
    return null;
  }

  @override
  Future<void> delete(StoredSession session) async => sessions.remove(session);
}

/// Refuses the camera, for the error state.
class _DenyingPose extends FakeFormaPose {
  _DenyingPose() : super(source: const []);

  @override
  Future<PoseEngineInfo> start([
    PoseStartOptions options = const PoseStartOptions(),
  ]) => throw const PoseEngineException(
    PoseErrorCode.permissionDenied,
    'camera permission not granted',
  );

  @override
  Future<bool> hasCameraPermission() async => false;

  @override
  Future<bool> requestCameraPermission() async => false;
}

/// Two weeks of squats, improving: enough for the trend line to mean
/// something and for Today's last-session card to have a comparison.
List<StoredSession> _history() {
  final now = DateTime(2026, 9, 10, 19);
  const scores = [88.0, 84.0, 79.0, 81.0, 72.0, 66.0];
  return [
    for (var i = 0; i < scores.length; i++)
      StoredSession(
        id: 'seed$i',
        startedAt: now.subtract(Duration(days: i * 2, minutes: 14)),
        endedAt: now.subtract(Duration(days: i * 2)),
        sets: [
          for (var k = 0; k < 3; k++)
            StoredSet(
              exerciseId: 'bw_squat',
              view: CameraView.side,
              durationMs: 42000,
              repCount: 10 - k,
              holdMs: 0,
              errorCounts: {'shallow_depth': i < 2 ? 1 : 3 - k},
              formScore: scores[i] + (1 - k) * 2,
            ),
        ],
      ),
  ];
}

Future<void> _loadFont(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}

Future<void> _frames(WidgetTester tester, int n, {int ms = 33}) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  File('$_outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

/// The first screenful, then one more below it for screens that scroll.
Future<void> _shotScrolled(WidgetTester tester, String name) async {
  await _shot(tester, name);
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) return;
  await tester.drag(scrollable.first, const Offset(0, -560));
  await _frames(tester, 12, ms: 50);
  await _shot(tester, '${name}_2');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (_outDir.isEmpty) {
    test(
      'screenshots',
      () {},
      skip: 'pass --dart-define=SCREENSHOT_DIR=<dir> to render them',
    );
    return;
  }

  late ContentBundle content;
  final profile = UserProfile(
    goal: TrainingGoal.form,
    level: TrainingLevel.occasional,
    equipment: Equipment.none,
    createdAt: DateTime(2026, 9, 1),
  );

  setUpAll(() async {
    // The camera preview asks the global platform instance, not the provider,
    // whether it can embed a native view; the method-channel default says yes
    // on the test's Android target and the platform view has no plugin here.
    FormaPosePlatform.instance = FakeFormaPose(source: const []);
    await _loadFont('Manrope', 'assets/fonts/Manrope-Variable.ttf');
    await _loadFont('Inter', 'assets/fonts/Inter-Variable.ttf');
    await _loadFont(
      'packages/lucide_icons_flutter/Lucide',
      'packages/lucide_icons_flutter/assets/lucide.ttf',
    );
    content = await loadContentBundle(rootBundle);
  });

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    required String locale,
    required FakeFormaPose engine,
    Size size = _portrait,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        poseEngineProvider.overrideWithValue(engine),
        contentRepositoryProvider.overrideWith((ref) async => content),
        localeControllerProvider.overrideWith(
          () => _FixedLocale(Locale(locale)),
        ),
        settingsStoreProvider.overrideWithValue(_MemorySettings()),
        profileStoreProvider.overrideWithValue(_MemoryProfile(profile)),
        sessionStoreProvider.overrideWithValue(_MemorySessions(_history())),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: UncontrolledProviderScope(
          container: container,
          child: const FormaApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tearDownApp(WidgetTester tester, FakeFormaPose engine) async {
    await tester.pumpWidget(const SizedBox());
    // Let the short one-shot timers of the last frame (a cue fade, a pulse)
    // run out, or the binding reports them as pending after the tree is gone.
    await tester.pump(const Duration(seconds: 1));
    await engine.dispose();
  }

  FakeFormaPose squat({int reps = 6}) => FakeFormaPose.syntheticSquat(
    view: CameraView.side,
    reps: reps,
    noiseStd: 0,
  );

  for (final locale in const ['tr', 'en']) {
    testWidgets('$locale: static screens', (tester) async {
      final engine = squat();
      final c = await pumpApp(tester, locale: locale, engine: engine);
      final router = c.read(routerProvider);
      for (final (name, path) in [
        ('today', Routes.today),
        ('training', Routes.training),
        ('progress', Routes.progress),
        ('profile', Routes.profile),
        ('settings', Routes.settings),
        ('legal', Routes.legal),
        ('exercise', Routes.exercise('bw_squat')),
      ]) {
        router.go(path);
        await _frames(tester, 20, ms: 50);
        await _shotScrolled(tester, '${locale}_$name');
      }
      await tearDownApp(tester, engine);
    });

    testWidgets('$locale: HUD portrait and landscape', (tester) async {
      for (final (name, size) in [
        ('hud', _portrait),
        ('hud_landscape', _landscape),
      ]) {
        final engine = FakeFormaPose.syntheticSquat(
          view: CameraView.front,
          valgus: 0.3,
          reps: 6,
          noiseStd: 0,
        );
        final c = await pumpApp(
          tester,
          locale: locale,
          engine: engine,
          size: size,
        );
        c.read(routerProvider).go(Routes.hud('bw_squat', CameraView.front));
        await _frames(tester, 40);
        await _shot(tester, '${locale}_${name}_setup');
        await tester.tap(find.byKey(const Key('hud_start_now')));
        await _frames(tester, 110);
        await _shot(tester, '${locale}_$name');
        await tearDownApp(tester, engine);
      }
    });

    testWidgets('$locale: HUD camera error', (tester) async {
      final engine = _DenyingPose();
      final c = await pumpApp(tester, locale: locale, engine: engine);
      c.read(routerProvider).go(Routes.hud('bw_squat', CameraView.side));
      await _frames(tester, 30);
      await _shot(tester, '${locale}_hud_error');
      await tearDownApp(tester, engine);
    });

    testWidgets('$locale: set summary, rest timer, session summary', (
      tester,
    ) async {
      final engine = squat();
      final c = await pumpApp(tester, locale: locale, engine: engine);
      c
          .read(routerProvider)
          .go(Routes.hud('bw_squat', CameraView.side, targetReps: 2));
      await _frames(tester, 40);
      await tester.tap(find.byKey(const Key('hud_start_now')));
      // By type, not by the end-session key: that button sits below the fold
      // of a lazy list and is not built until it is scrolled to.
      final summary = find.byType(SetSummaryScreen);
      for (var i = 0; i < 500 && summary.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      expect(summary, findsOneWidget, reason: 'the set ends on its own');
      await _frames(tester, 10, ms: 50);
      await _shotScrolled(tester, '${locale}_set_summary');

      // Not the last set, so the summary offers the rest timer; its second
      // button ends the session early.
      final end = find.byKey(const Key('rest_end'));
      await tester.dragUntilVisible(
        end,
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      await tester.pump();
      await tester.tap(end);
      await _frames(tester, 20, ms: 50);
      await _shotScrolled(tester, '${locale}_session_summary');
      await tearDownApp(tester, engine);
    });
  }
}
