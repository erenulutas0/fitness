import 'package:flutter/material.dart';
import 'package:forma_rules/forma_rules.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import 'camera_view_sheet.dart';

/// "Ön" / "Yan" with the angle pictogram, on the exercise list and detail.
class CameraViewChip extends StatelessWidget {
  const CameraViewChip({required this.view, super.key});

  final CameraView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Chip(
      avatar: Icon(cameraViewIcon(view), size: FormaSpacing.lg),
      label: Text(cameraViewLabel(l10n, view)),
    );
  }
}

/// Content still marked `draft`: listed so it can be tried, flagged so nobody
/// mistakes it for a finished exercise.
class DraftChip extends StatelessWidget {
  const DraftChip({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Chip(
      label: Text(l10n.draftBadge),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: FormaColors.warning),
      side: const BorderSide(color: FormaColors.warning),
    );
  }
}
