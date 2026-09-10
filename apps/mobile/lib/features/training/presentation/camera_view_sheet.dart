import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';

/// The label for a camera angle ("Ön" / "Yan").
String cameraViewLabel(AppLocalizations l10n, CameraView view) =>
    view == CameraView.front ? l10n.viewFront : l10n.viewSide;

/// The pictogram for a camera angle: facing the camera, or in profile.
IconData cameraViewIcon(CameraView view) => view == CameraView.front
    ? LucideIcons.scanFace
    : LucideIcons.personStanding;

/// Ask which angle to film [def] from. An exercise with a single angle needs
/// no question; otherwise the sheet returns the choice, or null on dismiss.
Future<CameraView?> chooseCameraView(
  BuildContext context,
  ExerciseDefinition def,
) async {
  if (def.cameraViews.length == 1) return def.cameraViews.single;
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<CameraView>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FormaSpacing.page,
              FormaSpacing.sm,
              FormaSpacing.page,
              FormaSpacing.md,
            ),
            child: Text(
              l10n.chooseView,
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
          ),
          for (final v in def.cameraViews)
            ListTile(
              key: Key('view_${v.name}'),
              leading: Icon(cameraViewIcon(v)),
              title: Text(cameraViewLabel(l10n, v)),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => Navigator.of(ctx).pop(v),
            ),
          const SizedBox(height: FormaSpacing.sm),
        ],
      ),
    ),
  );
}

/// Choose the angle, then open the HUD for [def]. Shared by Today's quick
/// check and the exercise detail's "Başla" so both start a set the same way.
Future<void> startExercise(BuildContext context, ExerciseDefinition def) async {
  final view = await chooseCameraView(context, def);
  if (view == null || !context.mounted) return;
  unawaited(context.push(Routes.hud(def.id, view)));
}
