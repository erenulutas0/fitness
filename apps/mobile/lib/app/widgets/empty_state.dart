import 'package:flutter/material.dart';

import '../theme.dart';

/// An empty screen says one sentence and offers the action that fills it
/// (brief §1). Copy comes from the caller, always through l10n.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction come together',
       );

  final String message;
  final IconData? icon;

  /// The single filled (lime) button on the screen, if there is one.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FormaSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 32, color: FormaColors.textMuted),
              const SizedBox(height: FormaSpacing.lg),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: FormaColors.textMuted),
            ),
            if (onAction != null) ...[
              const SizedBox(height: FormaSpacing.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
