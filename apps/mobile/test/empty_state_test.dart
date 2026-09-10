import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/app/app.dart';
import 'package:forma_mobile/app/widgets/widgets.dart';
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

/// docs/06 §7 and the brief §1: an empty screen says one sentence and offers
/// the action that fills it. Progress with no sessions is the case the design
/// plan calls out by name.
class _TurkishLocale extends LocaleController {
  @override
  Locale build() => const Locale('tr');
}

class _SeededProfile extends ProfileController {
  @override
  Future<UserProfile?> build() async => UserProfile(
    goal: TrainingGoal.form,
    level: TrainingLevel.occasional,
    equipment: Equipment.none,
    createdAt: DateTime(2026, 9, 10),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempRoot;
  late ContentBundle content;

  setUp(() async {
    tempRoot = Directory.systemTemp.createTempSync('forma_empty');
    Directory('${tempRoot.path}/sessions').createSync();
    content = await loadContentBundle(rootBundle);
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  testWidgets('progress with no sessions offers the quick form check', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
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
          profileProvider.overrideWith(_SeededProfile.new),
        ],
        child: const FormaApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab_progress')));
    await tester.pumpAndSettle();

    final empty = find.byKey(const Key('progress_empty'));
    expect(empty, findsOneWidget);
    expect(
      tester.widget<EmptyState>(empty).onAction,
      isNotNull,
      reason: 'the empty state offers the action that fills it',
    );

    // One lime button on the screen, and it is that action.
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    // bw_squat films from either angle, so the camera-angle sheet opens.
    expect(find.byKey(const Key('view_side')), findsOneWidget);
  });
}
