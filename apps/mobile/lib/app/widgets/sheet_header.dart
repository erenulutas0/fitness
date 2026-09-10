import 'package:flutter/material.dart';

import '../theme.dart';

/// The title line at the top of a modal bottom sheet.
///
/// Two sheets were building this by hand with the same four numbers — the
/// camera-angle picker and the settings/profile option picker — and a third
/// would have made it three. The drag handle above it comes from the theme.
class SheetHeader extends StatelessWidget {
  const SheetHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FormaSpacing.page,
        FormaSpacing.sm,
        FormaSpacing.page,
        FormaSpacing.md,
      ),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
