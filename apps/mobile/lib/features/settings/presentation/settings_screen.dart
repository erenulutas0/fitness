import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/widgets.dart';
import '../../../core/profile/profile_controller.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../history/infrastructure/session_store.dart';
import '../../profile/presentation/option_sheet.dart';

/// Ayarlar (docs/06 §9): sound, "az konuş", overlay, language, the legal
/// page, and "Verilerimi sil". Every toggle writes `settings.json` through
/// [settingsProvider]; the HUD reads the same provider, so a change here is
/// live in the next set.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider).orDefault;
    final controller = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(FormaSpacing.page),
        children: [
          FormaCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('settings_sound'),
                  secondary: const Icon(LucideIcons.volume2),
                  title: Text(l10n.settingSound),
                  subtitle: Text(l10n.settingSoundHint),
                  value: settings.soundOn,
                  onChanged: (v) => unawaited(
                    controller.update((s) => s.copyWith(soundOn: v)),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  key: const Key('settings_quiet'),
                  secondary: const Icon(LucideIcons.megaphoneOff),
                  title: Text(l10n.settingQuiet),
                  subtitle: Text(l10n.settingQuietHint),
                  value: settings.quietMode,
                  onChanged: (v) => unawaited(
                    controller.update((s) => s.copyWith(quietMode: v)),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  key: const Key('settings_overlay'),
                  secondary: const Icon(LucideIcons.personStanding),
                  title: Text(l10n.settingOverlay),
                  subtitle: Text(l10n.settingOverlayHint),
                  value: settings.overlayOn,
                  onChanged: (v) => unawaited(
                    controller.update((s) => s.copyWith(overlayOn: v)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: FormaSpacing.lg),
          FormaCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const Key('settings_language'),
              leading: const Icon(LucideIcons.languages),
              title: Text(l10n.settingLanguage),
              subtitle: Text(_languageLabel(l10n, settings.locale)),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => unawaited(_pickLanguage(context, ref, settings)),
            ),
          ),
          const SizedBox(height: FormaSpacing.lg),
          FormaCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  key: const Key('settings_legal'),
                  leading: const Icon(LucideIcons.shieldCheck),
                  title: Text(l10n.legalTitle),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => unawaited(context.push(Routes.legal)),
                ),
                const Divider(),
                ListTile(
                  key: const Key('settings_delete'),
                  leading: const Icon(
                    LucideIcons.trash2,
                    color: FormaColors.warning,
                  ),
                  title: Text(
                    l10n.deleteData,
                    style: text.bodyLarge?.copyWith(color: FormaColors.warning),
                  ),
                  onTap: () => unawaited(_deleteData(context, ref)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _languageLabel(AppLocalizations l10n, String? code) =>
      switch (code) {
        'tr' => l10n.languageTr,
        'en' => l10n.languageEn,
        _ => l10n.languageSystem,
      };

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final l10n = AppLocalizations.of(context);
    // The sheet returns '' for "follow the device", since null is "dismissed".
    final picked = await showOptionSheet<String>(
      context,
      title: l10n.settingLanguage,
      selected: settings.locale ?? '',
      options: [
        SheetOption(
          value: 'tr',
          label: l10n.languageTr,
          key: const Key('option_language_tr'),
        ),
        SheetOption(
          value: 'en',
          label: l10n.languageEn,
          key: const Key('option_language_en'),
        ),
        SheetOption(
          value: '',
          label: l10n.languageSystem,
          key: const Key('option_language_system'),
        ),
      ],
    );
    if (picked == null) return;
    await ref
        .read(settingsProvider.notifier)
        .update(
          (s) => picked.isEmpty
              // copyWith cannot clear the locale; rebuild without it.
              ? AppSettings(
                  soundOn: s.soundOn,
                  quietMode: s.quietMode,
                  overlayOn: s.overlayOn,
                )
              : s.copyWith(locale: picked),
        );
  }

  /// "Verilerimi sil": settings, profile and every stored session go, in that
  /// order of least to most consequential; clearing the profile last is what
  /// flips the router to onboarding.
  Future<void> _deleteData(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDataTitle),
        content: Text(l10n.deleteDataBody),
        actions: [
          TextButton(
            key: const Key('delete_cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('delete_confirm'),
            style: TextButton.styleFrom(foregroundColor: FormaColors.warning),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final sessions = await ref.read(sessionStoreProvider).directory();
    if (sessions.existsSync()) await sessions.delete(recursive: true);
    ref.invalidate(sessionHistoryProvider);
    await ref.read(settingsProvider.notifier).reset();
    await ref.read(profileProvider.notifier).clear();
    if (context.mounted) context.go(Routes.onboarding);
  }
}
