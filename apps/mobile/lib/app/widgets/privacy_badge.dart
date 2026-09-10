import 'package:flutter/material.dart';

import '../theme.dart';

/// The small persistent pill on every screen where the camera is on:
/// "Görüntü cihazda" (brief §1). The label is passed in through l10n.
///
/// Also used for the synthetic-engine badge in debug builds, which is why
/// the dot colour is a parameter: green means the promise holds, cyan means
/// "not a camera at all".
class PrivacyBadge extends StatelessWidget {
  const PrivacyBadge({
    required this.label,
    this.color = FormaColors.success,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FormaSpacing.md,
          vertical: FormaSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: FormaColors.surface.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.all(
            Radius.circular(FormaRadius.card),
          ),
          border: Border.all(color: FormaColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: FormaSpacing.sm,
              height: FormaSpacing.sm,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: FormaSpacing.sm),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
