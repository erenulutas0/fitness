import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/features/workout/presentation/share_card.dart';
import 'package:forma_rules/forma_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pose = const SyntheticPose()
      .squat(view: CameraView.side, reps: 1, noiseStd: 0)
      .firstWhere((f) => f.hasPose);

  testWidgets('renders to a PNG at the declared size', (tester) async {
    // runAsync: toImage needs the real rasterizer, and the fake async clock a
    // widget test runs on never drives it.
    final png = await tester.runAsync(
      () => renderShareCard(
        ShareCard(
          exerciseName: 'Squat',
          score: 92,
          statsLine: '3 set · 24 tekrar',
          pose: pose,
        ),
      ),
    );
    expect(png, isNotNull);
    expect(png!.length, greaterThan(1000));
    // PNG magic number, so this is really an image and not an error page.
    expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);

    final image = await tester.runAsync(() => decodeImageFromList(png));
    expect(image!.width, ShareCard.size.width.toInt());
    expect(image.height, ShareCard.size.height.toInt());
  });

  testWidgets('a session with no usable pose still produces a card', (
    tester,
  ) async {
    final png = await tester.runAsync(
      () => renderShareCard(
        const ShareCard(
          exerciseName: 'Plank',
          score: null,
          statsLine: '1 set · 45 sn',
        ),
      ),
    );
    expect(png!.length, greaterThan(1000));
  });

  testWidgets('a long stats line does not overflow the card', (tester) async {
    // The line is localised and grows: "3 sets · 120 seconds" is far wider
    // than "3 set · 24 tekrar". A RenderFlex overflow here would ship a card
    // with a striped bar across it.
    final png = await tester.runAsync(
      () => renderShareCard(
        ShareCard(
          exerciseName: 'Squat (bodyweight), side view',
          score: 100,
          statsLine: '12 sets · 240 repetitions across the whole session',
          pose: pose,
        ),
      ),
    );
    expect(png!.length, greaterThan(1000));
  });

  testWidgets('the card shows the score and the set line, not a video', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FittedBox(
          child: ShareCard(
            exerciseName: 'Squat (vücut ağırlığı)',
            score: 92,
            statsLine: '3 set · 24 tekrar',
            pose: pose,
          ),
        ),
      ),
    );
    expect(find.text('FORMA'), findsOneWidget);
    expect(find.text('92'), findsOneWidget);
    expect(find.text('3 set · 24 tekrar'), findsOneWidget);
    expect(find.text('Squat (vücut ağırlığı)'), findsOneWidget);
    // The privacy promise is structural: the only visual is a CustomPaint over
    // joint positions. If an Image ever appears here, something started
    // carrying pixels off the phone.
    expect(find.byType(Image), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
