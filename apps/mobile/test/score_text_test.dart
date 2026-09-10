import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/app/theme.dart';
import 'package:forma_mobile/app/widgets/widgets.dart';

void main() {
  test('band colours: ≥85 green, ≥60 lime, below orange, null muted', () {
    expect(ScoreText.colorFor(100), FormaColors.success);
    expect(ScoreText.colorFor(85), FormaColors.success);
    expect(ScoreText.colorFor(84.9), FormaColors.primary);
    expect(ScoreText.colorFor(60), FormaColors.primary);
    expect(ScoreText.colorFor(59.9), FormaColors.warning);
    expect(ScoreText.colorFor(0), FormaColors.warning);
    expect(ScoreText.colorFor(null), FormaColors.textMuted);
    expect(FormaColors.forScore(72), ScoreText.colorFor(72));
  });

  test('formats as a rounded integer or an en dash', () {
    expect(ScoreText.format(72.4), '72');
    expect(ScoreText.format(72.5), '73');
    expect(ScoreText.format(null), '–');
  });

  testWidgets('the rendered text carries the band colour', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FormaTheme.dark(),
        home: const Scaffold(
          body: Column(
            children: [
              ScoreText(key: Key('high'), score: 91),
              ScoreText(key: Key('mid'), score: 70),
              ScoreText(key: Key('low'), score: 40),
              ScoreText(key: Key('none'), score: null),
            ],
          ),
        ),
      ),
    );
    Color? colorOf(String key) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Text),
          ),
        )
        .style
        ?.color;
    expect(colorOf('high'), FormaColors.success);
    expect(colorOf('mid'), FormaColors.primary);
    expect(colorOf('low'), FormaColors.warning);
    expect(colorOf('none'), FormaColors.textMuted);
    expect(find.text('91'), findsOneWidget);
    expect(find.text('–'), findsOneWidget);
    // Display style by default: the big score, tabular Manrope.
    final style = tester.widget<Text>(find.text('91')).style!;
    expect(style.fontFamily, FormaType.heading);
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
  });
}
