import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/profile/profile_controller.dart';
import '../../../core/profile/user_profile.dart';
import '../../../l10n/app_localizations.dart';
import '../application/app_version.dart';
import 'option_sheet.dart';
import 'profile_labels.dart';

/// Profil (docs/06 §3): the three onboarding answers, each editable in
/// place, the way to Settings, and the version. Subscription arrives with the
/// paywall; there is nothing to show for it yet.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(profileProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(FormaSpacing.page),
        children: [
          if (profile == null)
            EmptyState(
              key: const Key('profile_empty'),
              icon: LucideIcons.userRound,
              message: l10n.profileEmpty,
            )
          else
            FormaCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _Row(
                    key: const Key('profile_goal'),
                    icon: LucideIcons.target,
                    label: l10n.profileGoal,
                    value: goalLabel(l10n, profile.goal),
                    onTap: () => unawaited(_editGoal(context, ref, profile)),
                  ),
                  const Divider(),
                  _Row(
                    key: const Key('profile_level'),
                    icon: LucideIcons.gauge,
                    label: l10n.profileLevel,
                    value: levelLabel(l10n, profile.level),
                    onTap: () => unawaited(_editLevel(context, ref, profile)),
                  ),
                  const Divider(),
                  _Row(
                    key: const Key('profile_equipment'),
                    icon: LucideIcons.dumbbell,
                    label: l10n.profileEquipment,
                    value: equipmentLabel(l10n, profile.equipment),
                    onTap: () =>
                        unawaited(_editEquipment(context, ref, profile)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: FormaSpacing.lg),
          FormaCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const Key('profile_settings'),
              leading: const Icon(LucideIcons.settings),
              title: Text(l10n.settingsTitle),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => unawaited(context.push(Routes.settings)),
            ),
          ),
          const SizedBox(height: FormaSpacing.xl),
          Text(
            l10n.appVersion(appVersion),
            key: const Key('profile_version'),
            textAlign: TextAlign.center,
            style: text.labelSmall,
          ),
        ],
      ),
    );
  }

  Future<void> _editGoal(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showOptionSheet<TrainingGoal>(
      context,
      title: l10n.profileGoal,
      selected: profile.goal,
      options: [
        for (final g in TrainingGoal.values)
          SheetOption(
            value: g,
            label: goalLabel(l10n, g),
            key: Key('option_goal_${g.name}'),
          ),
      ],
    );
    if (picked == null) return;
    await ref
        .read(profileProvider.notifier)
        .save(profile.copyWith(goal: picked));
  }

  Future<void> _editLevel(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showOptionSheet<TrainingLevel>(
      context,
      title: l10n.profileLevel,
      selected: profile.level,
      options: [
        for (final v in TrainingLevel.values)
          SheetOption(
            value: v,
            label: levelLabel(l10n, v),
            key: Key('option_level_${v.wire}'),
          ),
      ],
    );
    if (picked == null) return;
    await ref
        .read(profileProvider.notifier)
        .save(profile.copyWith(level: picked));
  }

  Future<void> _editEquipment(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showOptionSheet<Equipment>(
      context,
      title: l10n.profileEquipment,
      selected: profile.equipment,
      options: [
        for (final e in Equipment.values)
          SheetOption(
            value: e,
            label: equipmentLabel(l10n, e),
            key: Key('option_equipment_${e.name}'),
          ),
      ],
    );
    if (picked == null) return;
    await ref
        .read(profileProvider.notifier)
        .save(profile.copyWith(equipment: picked));
  }
}

/// "Hedef · Form ›": a label, its current value, and the tap that changes it.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(LucideIcons.chevronRight),
      onTap: onTap,
    );
  }
}
