import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma_mobile/app/theme.dart';

void main() {
  test('durations are the docs/06 §6 values', () {
    expect(FormaMotion.counterPulse, const Duration(milliseconds: 120));
    expect(FormaMotion.cueFade, const Duration(milliseconds: 200));
    expect(FormaMotion.scoreRing, const Duration(milliseconds: 400));
  });

  testWidgets('FormaMotion.of returns zero under reduce-motion', (
    tester,
  ) async {
    Duration? seen;
    Widget probe({required bool disableAnimations}) => MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Builder(
        builder: (context) {
          seen = FormaMotion.of(context, FormaMotion.scoreRing);
          return const SizedBox.shrink();
        },
      ),
    );

    await tester.pumpWidget(probe(disableAnimations: false));
    expect(seen, FormaMotion.scoreRing);

    await tester.pumpWidget(probe(disableAnimations: true));
    expect(seen, Duration.zero);
  });
}
