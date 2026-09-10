import 'package:flutter/material.dart';

import '../theme.dart';
import 'score_text.dart';

/// The score as a ring: the sweep animates to the new value in
/// [FormaMotion.scoreRing], ease-out, and to nothing under reduce-motion.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    required this.score,
    this.label,
    this.size = 72,
    this.strokeWidth = 7,
    this.semanticsLabel,
    super.key,
  });

  final double? score;

  /// Caption under the ring ("form"). Omitted when null.
  final String? label;
  final double size;
  final double strokeWidth;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ring = SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: (score ?? 0).clamp(0, 100) / 100),
            duration: FormaMotion.of(context, FormaMotion.scoreRing),
            curve: FormaMotion.curve,
            builder: (_, value, _) => CircularProgressIndicator(
              value: value,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              color: ScoreText.colorFor(score),
              backgroundColor: FormaColors.outline,
            ),
          ),
          Center(
            child: ScoreText(
              score: score,
              style: text.titleLarge,
              semanticsLabel: semanticsLabel,
            ),
          ),
        ],
      ),
    );
    if (label == null) return ring;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ring,
        const SizedBox(height: FormaSpacing.xs),
        Text(label!, style: text.labelMedium),
      ],
    );
  }
}
