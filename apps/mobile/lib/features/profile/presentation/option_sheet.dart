import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/widgets.dart';

/// One choice in an [showOptionSheet].
class SheetOption<T> {
  const SheetOption({required this.value, required this.label, this.key});

  final T value;
  final String label;

  /// Test hook for the row.
  final Key? key;
}

/// A bottom sheet of mutually exclusive options, the current one ticked.
/// Returns the tapped value, or null when dismissed.
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetOption<T>> options,
  required T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title),
          for (final o in options)
            ListTile(
              key: o.key,
              title: Text(o.label),
              trailing: o.value == selected
                  ? const Icon(LucideIcons.check, color: FormaColors.primary)
                  : null,
              selected: o.value == selected,
              selectedColor: FormaColors.text,
              onTap: () => Navigator.of(ctx).pop(o.value),
            ),
          const SizedBox(height: FormaSpacing.sm),
        ],
      ),
    ),
  );
}
