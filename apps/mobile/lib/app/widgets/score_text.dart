import 'package:flutter/material.dart';

import '../theme.dart';

/// A form score as text, coloured by band: ≥ 85 green, ≥ 60 lime, below
/// orange; `null` is an en dash in muted grey.
///
/// One place for the number formatting and the band colour, so a score never
/// reads "72.4" in one screen and "72" in the next.
class ScoreText extends StatelessWidget {
  const ScoreText({
    required this.score,
    this.style,
    this.semanticsLabel,
    super.key,
  });

  final double? score;

  /// Base style; the colour is always the band colour.
  final TextStyle? style;

  /// Read by TalkBack instead of the bare number ("Form skoru 72").
  final String? semanticsLabel;

  static Color colorFor(double? score) => FormaColors.forScore(score);

  static String format(double? score) =>
      score == null ? '–' : score.round().toString();

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.displayLarge;
    return Text(
      format(score),
      style: base?.copyWith(color: colorFor(score)),
      semanticsLabel: semanticsLabel,
    );
  }
}
