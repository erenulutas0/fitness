import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/app/theme.dart';
import 'package:forma_mobile/app/widgets/widgets.dart';

void main() {
  Widget app(double? score, {bool reduceMotion = false}) => MaterialApp(
    theme: FormaTheme.dark(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: ScoreRing(score: score, label: 'form'),
      ),
    ),
  );

  double sweep(WidgetTester tester) => tester
      .widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      )
      .value!;

  testWidgets('the sweep eases to the new score over 400 ms', (tester) async {
    await tester.pumpWidget(app(null));
    await tester.pump(FormaMotion.scoreRing);
    expect(sweep(tester), 0);
    expect(find.text('–'), findsOneWidget);
    expect(find.text('form'), findsOneWidget);

    await tester.pumpWidget(app(80));
    await tester.pump(const Duration(milliseconds: 200));
    final midway = sweep(tester);
    expect(midway, greaterThan(0));
    expect(midway, lessThan(0.8));

    await tester.pump(const Duration(milliseconds: 200));
    expect(sweep(tester), moreOrLessEquals(0.8, epsilon: 1e-6));
    expect(find.text('80'), findsOneWidget);
  });

  testWidgets('under reduce-motion the ring jumps straight there', (
    tester,
  ) async {
    await tester.pumpWidget(app(null, reduceMotion: true));
    await tester.pumpWidget(app(80, reduceMotion: true));
    await tester.pump();
    expect(sweep(tester), moreOrLessEquals(0.8, epsilon: 1e-6));
  });
}
