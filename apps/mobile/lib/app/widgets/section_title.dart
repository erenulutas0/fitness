import 'package:flutter/material.dart';

import '../theme.dart';

/// A section heading inside a scrolling screen, with the gap below it that
/// every screen was adding by hand.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {this.trailing, super.key});

  final String text;

  /// Optional right-aligned widget (a "see all" text button, a count).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final title = Text(text, style: Theme.of(context).textTheme.titleLarge);
    return Padding(
      padding: const EdgeInsets.only(bottom: FormaSpacing.sm),
      child: trailing == null
          ? title
          : Row(
              children: [
                Expanded(child: title),
                trailing!,
              ],
            ),
    );
  }
}
