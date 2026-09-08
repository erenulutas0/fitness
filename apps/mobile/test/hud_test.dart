import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/app/app.dart';
import 'package:forma_mobile/core/content/content_repository.dart';
import 'package:forma_mobile/core/locale/locale_controller.dart';
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

    // Let the fake engine stream ~9 s of frames (3 reps + pauses).
    for (var i = 0; i < 270; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(find.text('3'), findsWidgets);
    // The valgus cue cycles through its phrasing variants; any of them counts.
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('dışa'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('hud_finish')));
    await tester.pumpAndSettle();
    expect(find.text('Set özeti'), findsOneWidget);
    expect(find.textContaining('knee valgus'), findsOneWidget);
    await fake.dispose();
  });
}
