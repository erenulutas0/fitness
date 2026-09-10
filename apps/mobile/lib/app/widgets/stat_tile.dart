import 'package:flutter/material.dart';

import '../theme.dart';
import 'forma_card.dart';

/// One number with a caption: "12 / Tekrar", "3 / Bu hafta".
///
/// Used in a row of two or three, each `Expanded`. The number is Manrope
/// tabular so a row of tiles lines up whatever the digits are.
class StatTile extends StatelessWidget {
  const StatTile({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: FormaCard(
        child: Column(
          children: [
            Text(value, style: text.headlineLarge, textAlign: TextAlign.center),
            const SizedBox(height: FormaSpacing.xs),
            Text(label, style: text.labelMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
