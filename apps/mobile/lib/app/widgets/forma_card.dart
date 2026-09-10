import 'package:flutter/material.dart';

import '../theme.dart';

/// The one card: surface colour, 1 px outline, radius 16, no shadow.
///
/// [Card] is themed the same way; this exists so a card with padding or a tap
/// target is one widget instead of a Card-Padding-InkWell stack in every
/// screen.
class FormaCard extends StatelessWidget {
  const FormaCard({
    required this.child,
    this.padding = const EdgeInsets.all(FormaSpacing.lg),
    this.raised = false,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Elevation is colour in the dark theme: a raised card is simply lighter.
  final bool raised;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(FormaRadius.card));
    final body = Padding(padding: padding, child: child);
    return Material(
      color: raised ? FormaColors.surfaceRaised : FormaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: FormaColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : InkWell(onTap: onTap, borderRadius: radius, child: body),
    );
  }
}
