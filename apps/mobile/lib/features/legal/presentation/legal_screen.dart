import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/application/app_version.dart';

/// A component with its own licence line on the page (docs/08 §4). The
/// component and licence names are proper nouns and stay as they are; only
/// the description is translated.
class _Licence {
  const _Licence({
    required this.name,
    required this.licence,
    required this.description,
  });

  final String name;
  final String licence;
  final String description;
}

/// Gizlilik & Lisanslar (docs/06 §9, docs/08 §4): what stays on the phone,
/// then who the app is built on. Flutter's own licence page covers the pub
/// packages; the rows above it are the native and asset licences that
/// `LicenseRegistry` does not know about.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final licences = [
      _Licence(
        name: 'MediaPipe',
        licence: 'Apache 2.0',
        description: l10n.licenseMediaPipeDesc,
      ),
      _Licence(
        name: 'CameraX',
        licence: 'Apache 2.0',
        description: l10n.licenseCameraXDesc,
      ),
      _Licence(
        name: 'Manrope, Inter',
        licence: 'SIL OFL 1.1',
        description: l10n.licenseFontsDesc,
      ),
      _Licence(
        name: 'Lucide',
        licence: 'ISC · MIT',
        description: l10n.licenseLucideDesc,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.legalTitle)),
      body: ListView(
        padding: const EdgeInsets.all(FormaSpacing.page),
        children: [
          SectionTitle(l10n.privacyTitle),
          FormaCard(
            key: const Key('legal_privacy'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.shieldCheck,
                      color: FormaColors.success,
                    ),
                    const SizedBox(width: FormaSpacing.md),
                    Expanded(
                      child: Text(l10n.privacyCamera, style: text.bodyLarge),
                    ),
                  ],
                ),
                const SizedBox(height: FormaSpacing.lg),
                Text(l10n.privacyStoredTitle, style: text.titleSmall),
                const SizedBox(height: FormaSpacing.sm),
                _Bullet(l10n.privacyStoredSettings),
                _Bullet(l10n.privacyStoredProfile),
                _Bullet(l10n.privacyStoredSessions),
                const SizedBox(height: FormaSpacing.md),
                Text(l10n.privacyNotStored, style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: FormaSpacing.xl),
          SectionTitle(l10n.licensesTitle),
          for (final item in licences)
            Padding(
              padding: const EdgeInsets.only(bottom: FormaSpacing.md),
              child: FormaCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: text.titleSmall),
                          const SizedBox(height: FormaSpacing.xs),
                          Text(item.description, style: text.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: FormaSpacing.md),
                    Text(item.licence, style: text.labelMedium),
                  ],
                ),
              ),
            ),
          const SizedBox(height: FormaSpacing.md),
          FilledButton.icon(
            key: const Key('legal_all_licenses'),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: appVersion,
            ),
            icon: const Icon(LucideIcons.scrollText),
            label: Text(l10n.allLicenses),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FormaSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: FormaSpacing.xs),
            child: Icon(
              LucideIcons.check,
              size: FormaSpacing.lg,
              color: FormaColors.textMuted,
            ),
          ),
          const SizedBox(width: FormaSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
